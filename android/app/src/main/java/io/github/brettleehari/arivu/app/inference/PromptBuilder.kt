package io.github.brettleehari.arivu.app.inference

/** A turn as the prompt sees it. */
data class Turn(val id: String, val fromUser: Boolean, val text: String)

sealed interface BuiltPrompt {
    /**
     * [firstIncluded] is the index into the turn list of the oldest turn the model sees.
     * Anything before it was dropped and must be shown as such (spine: C7).
     */
    data class Ok(val text: String, val promptTokens: Int, val firstIncluded: Int) : BuiltPrompt

    /** The newest user message alone does not fit. Nothing is truncated silently. */
    data class TooLong(val messageTokens: Int, val limitTokens: Int) : BuiltPrompt
}

/**
 * Qwen3 ChatML in non-thinking mode (D-007). History is dropped oldest-first, whole turns only,
 * until system + turns + reply reserve fit in the context.
 */
class PromptBuilder(
    private val systemPrompt: String,
    private val nCtx: Int,
    private val replyReserve: Int,
    private val countTokens: suspend (String) -> Int,
) {
    private val cache = HashMap<String, Int>()

    suspend fun build(turns: List<Turn>): BuiltPrompt {
        require(turns.isNotEmpty() && turns.last().fromUser) { "last turn must be the user's" }
        val header = system(systemPrompt)
        val footer = ASSISTANT_OPEN
        val fixed = countTokens(header) + countTokens(footer)
        val budget = nCtx - replyReserve - fixed

        val newest = tokensOf(turns.last())
        if (newest > budget) return BuiltPrompt.TooLong(newest, budget)

        var used = 0
        var first = turns.size
        for (i in turns.indices.reversed()) {
            val t = tokensOf(turns[i])
            if (used + t > budget) break
            used += t
            first = i
        }
        // Never start the visible window on an assistant reply without the question before it.
        while (first < turns.size - 1 && !turns[first].fromUser) {
            used -= tokensOf(turns[first])
            first++
        }
        val text = buildString {
            append(header)
            for (i in first until turns.size) append(render(turns[i]))
            append(footer)
        }
        return BuiltPrompt.Ok(text, fixed + used, first)
    }

    private suspend fun tokensOf(turn: Turn): Int =
        cache[turn.id + ":" + turn.text.length] ?: countTokens(render(turn)).also { cache[turn.id + ":" + turn.text.length] = it }

    companion object {
        const val ASSISTANT_OPEN = "<|im_start|>assistant\n<think>\n\n</think>\n\n"

        fun system(text: String) = "<|im_start|>system\n$text<|im_end|>\n"

        fun render(turn: Turn): String {
            val role = if (turn.fromUser) "user" else "assistant"
            // Previous assistant turns are rendered without a think block, matching Qwen3's template.
            return "<|im_start|>$role\n${turn.text}<|im_end|>\n"
        }
    }
}
