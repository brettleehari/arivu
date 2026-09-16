package io.github.brettleehari.arivu.app

/**
 * Every value that could have been a setting, and is not. spine: C8 — there is no settings screen.
 *
 * The values are in two places on purpose:
 *  - **here**: decisions no device gets a say in — the same on a 4GB phone, an 8GB phone and,
 *    later, an iPhone.
 *  - **[io.github.brettleehari.arivu.app.profile.Profile]**: decisions the *device* makes, chosen
 *    by a probe of its RAM and cores (spine: C11). Context size, batch, threads, the model itself
 *    and its sampling live there.
 *
 * Each constant names the decision that fixed it (leaves/decisions.yml).
 */
object Policy {
    /** leaves/BRIEF.md "Lifecycle": free the context after ~30s idle. */
    const val CONTEXT_IDLE_MILLIS = 30_000L

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
}
