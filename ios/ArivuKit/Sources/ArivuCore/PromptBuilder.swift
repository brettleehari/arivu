// Qwen3 ChatML in non-thinking mode (D-007), and the truncation policy.
//
// A line-for-line port of android/app/.../inference/PromptBuilder.kt. "Keep whole turns" is a
// product decision, not a platform one (MULTIPLATFORM.md appendix), so the arithmetic here is
// checked against the same cases as PromptBuilderTest.kt — see PromptBuilderTests.swift.
//
// History is dropped oldest-first, whole turns only, until system + turns + reply reserve fit in the
// context. The caller is told which turn is the oldest one the model can see, so what was dropped is
// shown on screen and never silently lost.
//
// spine: C7

import Foundation

/// A turn as the prompt sees it.
public struct Turn: Equatable, Sendable {
    public let id: String
    public let fromUser: Bool
    public let text: String

    public init(id: String, fromUser: Bool, text: String) {
        self.id = id
        self.fromUser = fromUser
        self.text = text
    }
}

public enum BuiltPrompt: Equatable, Sendable {
    /// `firstIncluded` is the index into the turn list of the oldest turn the model sees.
    /// Anything before it was dropped and must be shown as such (spine: C7).
    case ok(text: String, promptTokens: Int32, firstIncluded: Int)
    /// The newest user message alone does not fit. Nothing is truncated silently.
    case tooLong(messageTokens: Int32, limitTokens: Int32)
}

public enum PromptError: Error, Equatable {
    /// Empty history, or the newest turn is not the user's. A programming error, not a user state.
    case invalidHistory
    /// The tokenizer could not count this text.
    case countFailed
}

public actor PromptBuilder {
    public typealias CountTokens = @Sendable (String) async throws -> Int32

    private let systemPrompt: String
    private let nCtx: Int32
    private let replyReserve: Int32
    private let countTokens: CountTokens
    private var cache: [String: Int32] = [:]

    public init(systemPrompt: String, nCtx: Int32, replyReserve: Int32, countTokens: @escaping CountTokens) {
        self.systemPrompt = systemPrompt
        self.nCtx = nCtx
        self.replyReserve = replyReserve
        self.countTokens = countTokens
    }

    public func build(turns: [Turn]) async throws -> BuiltPrompt {
        guard let last = turns.last, last.fromUser else { throw PromptError.invalidHistory }

        let header = Self.system(systemPrompt)
        let footer = Self.assistantOpen
        let fixed = try await count(header) + count(footer)
        let budget = nCtx - replyReserve - fixed

        let newest = try await tokens(of: last)
        if newest > budget { return .tooLong(messageTokens: newest, limitTokens: budget) }

        var used: Int32 = 0
        var first = turns.count
        for i in stride(from: turns.count - 1, through: 0, by: -1) {
            let t = try await tokens(of: turns[i])
            if used + t > budget { break }
            used += t
            first = i
        }
        // Never start the visible window on an assistant reply without the question before it.
        while first < turns.count - 1 && !turns[first].fromUser {
            used -= try await tokens(of: turns[first])
            first += 1
        }

        var text = header
        for i in first..<turns.count { text += Self.render(turns[i]) }
        text += footer
        return .ok(text: text, promptTokens: fixed + used, firstIncluded: first)
    }

    /// Kotlin keys the cache on `id + ":" + text.length`; the same key, so the same cache behaviour
    /// (a streaming reply whose text keeps growing misses, a settled turn hits).
    private func tokens(of turn: Turn) async throws -> Int32 {
        let key = turn.id + ":" + String(turn.text.count)
        if let hit = cache[key] { return hit }
        let n = try await count(Self.render(turn))
        cache[key] = n
        return n
    }

    private func count(_ text: String) async throws -> Int32 {
        let n = try await countTokens(text)
        guard n >= 0 else { throw PromptError.countFailed }
        return n
    }

    // MARK: - The template itself

    /// Qwen3's non-thinking assistant opening: an empty think block, exactly as the template emits it.
    public static let assistantOpen = "<|im_start|>assistant\n<think>\n\n</think>\n\n"

    public static func system(_ text: String) -> String { "<|im_start|>system\n\(text)<|im_end|>\n" }

    public static func render(_ turn: Turn) -> String {
        let role = turn.fromUser ? "user" : "assistant"
        // Previous assistant turns are rendered without a think block, matching Qwen3's template.
        return "<|im_start|>\(role)\n\(turn.text)<|im_end|>\n"
    }
}

public extension BuiltPrompt {
    /// How much shorter the user should make a message that did not fit, as a percentage, clamped to
    /// 1–99. Users are not shown token counts: they do not know tokens, they know "half"
    /// (leaves/design.md, `message_too_long`).
    static func shorterPercent(messageTokens: Int32, limitTokens: Int32) -> Int {
        let n = max(messageTokens, 1)
        return min(max(Int(limitTokens) * 100 / Int(n), 1), 99)
    }
}
