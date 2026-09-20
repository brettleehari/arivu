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
        "You are Arivu, an offline writing assistant running on the user's phone. " +
            // D-063. This used to read "Help with text the user provides: rewrite, shorten, …", and
            // the sweep across 0.6B, 1.7B and 4B showed what that cost: a declarative sentence
            // became text to operate on rather than a claim to assess, so the model restated it —
            // which a user reads as confirmation. The two sentences after the hedge are the fix,
            // and on-task replies came back byte-identical.
            "You are good at working with text the user gives you: rewriting, shortening, explaining, " +
            "summarising, translating and drafting. Do that when they ask for it. " +
            "You have no internet access and your memory of facts is unreliable. When asked about facts, " +
            "news, figures, products or events, say plainly that you may be wrong and suggest checking a " +
            "trusted source. Never repeat a claim back as though confirming it, and if something the user " +
            "says sounds wrong, say so. " +
            "Reply in the language the user writes in. Be brief and plain. " +
            // spine: C9 — short safeguards; every token here is context the user's text cannot use.
            "Refuse sexual content involving minors, instructions for weapons or serious harm, and forging official " +
            "documents or IDs. If someone mentions self-harm, reply kindly and briefly and suggest talking to someone they trust or local emergency help."
}
