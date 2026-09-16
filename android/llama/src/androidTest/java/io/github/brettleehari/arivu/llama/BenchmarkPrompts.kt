package io.github.brettleehari.arivu.llama

/**
 * Fixed prompt set for W01. Chosen to match the product's positioning (spine: C5):
 * operating on text the user provides. Changing these invalidates comparisons with
 * earlier rows in NOTES.md — add new prompts instead of editing old ones.
 */
internal object BenchmarkPrompts {
    const val SYSTEM = "You are Arivu, an offline writing and comprehension assistant. " +
        "Work only with the text the user gives you. Be brief and plain."

    private val passage = """
        The school board has reviewed the proposal to change the start of the school day from
        7:30 to 8:15 in the morning. Parents raised concerns about transport, because many
        children travel with older siblings who start work early. Teachers noted that the first
        lesson is often lost to late arrivals during the rainy season. The board agreed to run a
        trial for one term in two schools, collect attendance figures each week, and ask parents
        to complete a short form at the end of the term. Schools taking part will receive extra
        support for a breakfast programme. A final decision will be made at the board meeting in
        March, after the figures have been shared with the parents' association.
    """.trimIndent()

    data class Case(val id: String, val user: String, val maxNew: Int)

    val cases = listOf(
        Case("rewrite-short", "Rewrite this to be polite: send me the report today.", 64),
        Case("explain", "Explain in simple words what this means: \"The tenant shall indemnify the landlord.\"", 128),
        Case("draft-letter", "Write a short letter to parents saying the school trip is moved to Friday.", 192),
        Case("summarise-long", "Summarise this in three bullet points:\n\n" + List(3) { passage }.joinToString("\n\n"), 160),
    )

    fun chatml(user: String): String =
        "<|im_start|>system\n$SYSTEM<|im_end|>\n" +
            "<|im_start|>user\n$user<|im_end|>\n" +
            "<|im_start|>assistant\n<think>\n\n</think>\n\n"
}
