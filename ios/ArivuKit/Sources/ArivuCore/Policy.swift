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
        "You are Arivu, an offline writing and comprehension assistant running on the user's phone. "
        + "Help with text the user provides: rewrite, shorten, explain, summarise, translate, draft. "
        + "You have no internet access and your memory of facts is unreliable. If asked for facts, news, "
        + "figures or advice, say you may be wrong and suggest checking a trusted source. "
        + "Reply in the language the user writes in. Be brief and plain. "
        // spine: C9 — short safeguards; every token here is context the user's text cannot use.
        + "Refuse sexual content involving minors, instructions for weapons or serious harm, and forging official "
        + "documents or IDs. If someone mentions self-harm, reply kindly and briefly and suggest talking to someone they trust or local emergency help."

    /// The model in the app bundle. No `.so` suffix and no alignment dance: D-013 is Android-only
    /// complexity that disappears because an iOS app bundle is a directory, not a zip
    /// (leaves/architecture/ios-port.md). Offset 0, whole file.
    public static let modelResourceName = "qwen3-0.6b-q4_k_m"
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

    /// What one context needs before the engine will try to create it. `os_proc_available_memory()`
    /// is a reading of this second, so it gates a *load attempt* and never the device
    /// (leaves/design.md §5.4). KV @2048 q8_0 ≈ 115 MB + compute buffer ≈ 28 MiB + headroom.
    public static let minAvailableMemoryForContextBytes: UInt64 = 350_000_000
}
