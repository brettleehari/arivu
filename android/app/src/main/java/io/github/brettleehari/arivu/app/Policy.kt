package io.github.brettleehari.arivu.app

/**
 * Every value that could have been a setting. spine: C8 — there is no settings screen.
 * Each constant names the decision that fixed it (leaves/decisions.yml).
 */
object Policy {
    /** CLAUDE.md "Context": 2048 tokens, q8_0 KV. */
    const val N_CTX = 2048
    const val N_BATCH = 512
    const val KV_Q8_0 = true

    /** Tokens held back for the reply when fitting history into the context. */
    const val REPLY_RESERVE_TOKENS = 512
    const val MAX_REPLY_TOKENS = 768

    /** CLAUDE.md "Lifecycle": free the context after ~30s idle. */
    const val CONTEXT_IDLE_MILLIS = 30_000L

    /** D-015: weights stay file-backed and evictable unless the benchmark proves repacking worth ~400MB RSS. */
    const val REPACK_WEIGHTS = false

    /** D-007: Qwen3 non-thinking mode with Qwen's recommended non-thinking sampling. */
    const val TEMPERATURE = 0.7f
    const val TOP_K = 20
    const val TOP_P = 0.8f

    /** spine: C5 — the model is told, as the user is told, what it is bad at. */
    const val SYSTEM_PROMPT =
        "You are Arivu, an offline writing and comprehension assistant running on the user's phone. " +
            "Help with text the user provides: rewrite, shorten, explain, summarise, translate, draft. " +
            "You have no internet access and your memory of facts is unreliable. If asked for facts, news, " +
            "figures or advice, say you may be wrong and suggest checking a trusted source. " +
            "Reply in the language the user writes in. Be brief and plain. " +
            // spine: C9 — short safeguards; every token here is context the user's text cannot use.
            "Refuse sexual content involving minors, instructions for weapons or serious harm, and forging official " +
            "documents or IDs. If someone mentions self-harm, reply kindly and briefly and suggest talking to someone they trust or local emergency help."

    /**
     * The ".so" suffix is deliberate (D-013). bundletool page-aligns any stored entry ending in ".so";
     * everything else gets 4-byte alignment, and a GGUF can only be mmap'd in place at an offset that
     * is a multiple of 32. Verified with tools/zip_entry_offset.py on bundletool output.
     */
    const val MODEL_ASSET = "model/qwen3-0.6b-q4_k_m.gguf.so"
}
