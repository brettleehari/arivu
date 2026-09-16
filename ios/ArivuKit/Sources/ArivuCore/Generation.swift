// What a generation produces, and why it ended.
//
// These types carry no C and no llama.cpp, so the chat state machine and its tests never need the
// native library. `StopReason` is the engine's answer; `Stop` is what the conversation file records
// and what the user is shown. The mapping between them is the one place a stop reason can be
// *reinterpreted* (a cancel that was really the OS taking memory, or the background allowance
// running out), so it is written once, here, and tested.
//
// spine: C7, C10

import Foundation

/// Raw values match `arivu_stop_reason` in core/include/arivu/arivu.h. A mismatch here would be a
/// silent misreport, so CoreParityTests checks them against the C enum when a real core is linked.
public enum StopReason: Int32, Sendable, CaseIterable {
    case endOfTurn = 0
    case cancelled = 1
    case contextFull = 2
    case maxTokens = 3
    case error = 4

    public var stop: Stop {
        switch self {
        case .endOfTurn: return .endOfTurn
        case .cancelled: return .cancelled
        case .contextFull: return .contextFull
        case .maxTokens: return .maxTokens
        case .error: return .error
        }
    }
}

/// Why the app asked the engine to stop, when it was the app and not the user.
/// The engine only ever reports `cancelled`; it cannot know the reason, so the app supplies it.
public enum CancelCause: Sendable, Equatable {
    /// The user tapped Stop. Never relabelled: their action keeps their label.
    case user
    /// The OS signalled memory pressure mid-reply (leaves/design.md §7).
    case memoryPressure
    /// The background allowance ran out (leaves/design.md §5.1).
    case backgroundExpiring
}

public struct GenerationStats: Equatable, Sendable {
    public var stop: StopReason
    public var promptTokens: Int32
    public var reusedTokens: Int32
    public var generated: Int32
    public var prefillMs: Double
    public var decodeMs: Double
    /// `generate()` to first visible text. Add model load time for a cold-start figure (M1).
    public var firstTokenMs: Double
    public var error: String?

    public init(stop: StopReason, promptTokens: Int32 = 0, reusedTokens: Int32 = 0, generated: Int32 = 0,
                prefillMs: Double = 0, decodeMs: Double = 0, firstTokenMs: Double = 0, error: String? = nil) {
        self.stop = stop
        self.promptTokens = promptTokens
        self.reusedTokens = reusedTokens
        self.generated = generated
        self.prefillMs = prefillMs
        self.decodeMs = decodeMs
        self.firstTokenMs = firstTokenMs
        self.error = error
    }

    public var prefillTokensPerSecond: Double {
        prefillMs > 0 ? Double(promptTokens - reusedTokens) * 1000 / prefillMs : 0
    }
    public var decodeTokensPerSecond: Double {
        decodeMs > 0 ? Double(generated) * 1000 / decodeMs : 0
    }

    /// The one line per reply that is the on-device evidence for M1/M2. No text content is logged.
    public func summary(threads: Int32) -> String {
        String(format: "generation done: stop=%@ prompt=%d reused=%d generated=%d ttft=%.0f ms prefill=%.1f tok/s decode=%.1f tok/s threads=%d",
               String(describing: stop), promptTokens, reusedTokens, generated,
               firstTokenMs, prefillTokensPerSecond, decodeTokensPerSecond, threads)
    }
}

public enum GenerationEvent: Equatable, Sendable {
    case text(String)
    case done(GenerationStats)
}

/// The label a finished reply carries, given what the engine said and what the app knows.
/// The user's own Stop is never relabelled (leaves/design.md §7).
public func resolveStop(_ reason: StopReason, cancelCause: CancelCause?) -> Stop {
    guard reason == .cancelled, let cause = cancelCause else { return reason.stop }
    switch cause {
    case .user: return .cancelled
    case .memoryPressure: return .lowMemory
    case .backgroundExpiring: return .backgrounded
    }
}

/// The label on a reply the app finds unfinished at launch. The app cannot know why the process
/// died, so it does not guess: "Stopped", never "Cut off", never "your phone ran low on memory"
/// (leaves/design.md §3, "Process death mid-reply").
public let stopAfterProcessDeath: Stop = .cancelled

/// How many bytes at the front of `bytes` form complete UTF-8 sequences.
///
/// The core promises it never hands over a partial character, and the app therefore never buffers.
/// This exists so that promise is *checked* rather than trusted: `arivu_utf8_complete_prefix` is the
/// core's own rule, and CoreParityTests runs both over the same inputs. A platform that ever has to
/// do its own streaming buffer must use this, not invent a second rule.
public func utf8CompletePrefix(_ bytes: [UInt8]) -> Int {
    guard !bytes.isEmpty else { return 0 }

    // Walk back at most four bytes to the lead byte of the last sequence.
    var start = bytes.count
    var stepped = 0
    while start > 0 && stepped < 4 {
        start -= 1
        stepped += 1
        if bytes[start] & 0xC0 != 0x80 { break }  // not a continuation byte: this is the lead
    }

    let lead = bytes[start]
    let needed: Int
    switch lead {
    case 0x00...0x7F: needed = 1
    case 0xC0...0xDF: needed = 2
    case 0xE0...0xEF: needed = 3
    case 0xF0...0xF7: needed = 4
    default: return bytes.count  // a stray continuation byte; nothing sensible to hold back
    }
    return start + needed <= bytes.count ? bytes.count : start
}
