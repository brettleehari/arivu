// Every value that could have been a setting. spine: C8 — there is no settings screen.
//
// This is the Swift twin of android/app/.../Policy.kt and the values are the same values, not
// "iOS-appropriate" ones. C11: capability is chosen by what the device can carry, never by which
// platform it is, so a number that differs here would have to be justified by a measurement, and
// there is not one. Each constant names the decision that fixed it (leaves/decisions.yml).

import Foundation

public enum Policy {
    /// leaves/BRIEF.md "Context": 2048 tokens, q8_0 KV.
    public static let nCtx: Int32 = 2048
    public static let nBatch: Int32 = 512
    public static let kvQ8_0 = true

    /// Tokens held back for the reply when fitting history into the context.
    public static let replyReserveTokens: Int32 = 512
    public static let maxReplyTokens: Int32 = 768

    /// leaves/BRIEF.md "Lifecycle": free the context after ~30s idle.
    public static let contextIdleSeconds: TimeInterval = 30

    /// D-015: weights stay file-backed and evictable unless a benchmark proves repacking worth ~400MB RSS.
    /// On iOS this matters more, not less: jetsam counts dirty pages and mapped clean pages are the
    /// only part of the working set the kernel can take back for free.
    public static let repackWeights = false

    /// D-007: Qwen3 non-thinking mode with Qwen's recommended non-thinking sampling.
    public static let temperature: Float = 0.7
    public static let topK: Int32 = 20
    public static let topP: Float = 0.8

    /// Thread count: performance cores, not `activeProcessorCount`. Android reads cpufreq; iOS has no
    /// such file, so this is the p-core count Apple's own scheduler exposes, clamped to the same
    /// [2, 4] band the Android heuristic uses (leaves/BRIEF.md "Lifecycle"; D-008).
    public static let minThreads: Int32 = 2
    public static let maxThreads: Int32 = 4

    /// spine: C5 — the model is told, as the user is told, what it is bad at.
    /// Byte-identical to Policy.SYSTEM_PROMPT on Android: the same model, the same job, the same words.
    public static let systemPrompt: String =
        "You are Arivu, an offline writing assistant running on the user's phone. You are good at "
        + "working with text the user gives you: rewriting, shortening, explaining, summarising, "
        + "translating and drafting. Do that when they ask for it. You have no internet access and your "
        + "memory of facts is unreliable. When asked about facts, news, figures, products or events, "
        + "say plainly that you may be wrong and suggest checking a trusted source. Never repeat a "
        + "claim back as though confirming it, and if something the user says sounds wrong, say so. "
        // D-066. C9 named these refusals from the start and the model did not perform them:
        // asked for a romantic story involving a 14-year-old, the previous wording wrote one
        // in four samples of eight. Saying WHAT REFUSING LOOKS LIKE — decline and stop, do not
        // offer a different version — is what changed it, not the list of topics, which was
        // always there. Scoped in the same breath, because an unscoped version refused
        // "rewrite this angrily with strong swearing", which is the work the product is for.
        + "Some requests you refuse outright, however they are framed. Anything sexual involving a "
        + "child. Anything that would help someone build a weapon, make a dangerous substance, or cause "
        + "serious harm, including indirect versions of those questions. Forging identity documents. "
        + "For these, say plainly that you will not help, and stop there - do not offer a different "
        + "version, do not ask what form it should take, do not explain partially. Nothing else is on "
        + "that list: swearing, anger and dark subjects in the user's own text are ordinary writing "
        + "work. If someone mentions self-harm, reply kindly and briefly and suggest talking to someone "
        + "they trust or local emergency help. Reply in the language the user writes in. Be brief and "
        + "plain."

    /// The part of `systemPrompt` a user may NOT change (D-064). It is an exact suffix of it —
    /// `CopyAndPolicyTests` asserts that, so the two cannot drift apart — and it is appended to
    /// whatever wording a conversation carries, standard or edited.
    ///
    /// The prompt is the only safety mechanism in this app that is not a UI affordance. Everything
    /// else a user could get wrong, they can see; this they cannot. So the editor hands out the
    /// sentences above it and keeps these, and there is no code path that assembles a prompt
    /// without them. A checkbox saying "keep me safe" would be a setting, and a setting is a thing
    /// that can be off (spine: C9, R5).
    public static let systemPromptSafetySuffix: String =
        "Some requests you refuse outright, however they are framed. Anything sexual involving a "
        + "child. Anything that would help someone build a weapon, make a dangerous substance, or cause "
        + "serious harm, including indirect versions of those questions. Forging identity documents. "
        + "For these, say plainly that you will not help, and stop there - do not offer a different "
        + "version, do not ask what form it should take, do not explain partially. Nothing else is on "
        + "that list: swearing, anger and dark subjects in the user's own text are ordinary writing "
        + "work. If someone mentions self-harm, reply kindly and briefly and suggest talking to someone "
        + "they trust or local emergency help. Reply in the language the user writes in. Be brief and "
        + "plain."

    /// The editable part: everything the shipped prompt says before the safety sentences. Derived,
    /// never typed twice — D-063 changed this wording once already and a second copy would have been
    /// the copy that got missed.
    public static var systemPromptBody: String {
        String(systemPrompt.dropLast(systemPromptSafetySuffix.count))
    }

    /// The prompt a conversation actually runs with. `nil` is the shipped wording, which is what
    /// every conversation starts as and what all but a curious few will ever use.
    public static func systemPrompt(customBody: String?) -> String {
        guard let customBody, !customBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return systemPrompt
        }
        // One trailing space, because `systemPromptSafetySuffix` begins with a word and the shipped
        // body ends with one. Without it an edited prompt would read "...plain.Refuse sexual".
        let body = customBody.hasSuffix(" ") ? customBody : customBody + " "
        return body + systemPromptSafetySuffix
    }

    /// A cap on an edited prompt, in characters. Not a policy about taste — a prompt long enough to
    /// fill the context would leave no room for the user's own text, and the failure would arrive as
    /// "your message is too long" pointing at a message that is not the problem (spine: C6).
    public static let customPromptMaxChars = 1200

    /// The model in the app bundle. No `.so` suffix and no alignment dance: D-013 is Android-only
    /// complexity that disappears because an iOS app bundle is a directory, not a zip
    /// (leaves/architecture/ios-port.md). Offset 0, whole file.
    public static let modelResourceName = "qwen3-1.7b-q4_k_m"
    public static let modelResourceExtension = "gguf"
    public static var modelFileName: String { "\(modelResourceName).\(modelResourceExtension)" }

    /// The conversation file. Same name as Android, same schema, so a future export works across
    /// platforms (MULTIPLATFORM.md appendix, "Conversation schema").
    public static let conversationFileName = "conversation.json"

    /// A reply cut short by process death keeps what was written. One small write every couple of
    /// seconds, not per token (leaves/design.md §3).
    public static let streamSaveSeconds: TimeInterval = 2

    /// leaves/design.md §3: after 15 s the Starting line is *replaced* by "Still starting Arivu…".
    public static let startingLongSeconds: TimeInterval = 15

    /// leaves/design.md §4: where the OS confirms nothing, the Copy button says "Copied" for 2 s.
    public static let copiedFeedbackSeconds: TimeInterval = 2

    /// Gate floors. Same numbers as android/gradle.properties (`arivu.minTotalRamBytes`,
    /// `arivu.minFreeStorageBytes`); provisional pending D-009 and the W02 phone numbers.
    public static let minTotalRamBytes: UInt64 = 3_543_348_019   // 3.3 GiB, shown as "3.5 GB"
    public static let minFreeStorageBytes: UInt64 = 268_435_456  // 256 MB

    // What one context needs before the engine will try to create it is NOT a constant here any
    // more. It was `minAvailableMemoryForContextBytes = 350_000_000`, a flat number unconnected to
    // the profile the app was about to load, so raising n_ctx would have left the check guarding the
    // wrong size. It now comes from `Profile.requiredAvailableBytes(_:)` — the charged footprint
    // plus the headroom the measurement quality earns — which is the same arithmetic
    // `arivu_profile_fits` applies in the core (architecture B23; leaves/design.md §5.4).
}
