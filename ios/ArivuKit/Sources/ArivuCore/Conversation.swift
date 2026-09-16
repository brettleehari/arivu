// The conversation, and the file it lives in.
//
// The JSON is the SAME FILE FORMAT as Android's (MULTIPLATFORM.md appendix: "Conversation schema —
// same JSON, so a future export/import works across devices"). That is a contract, not a
// convenience: field names, field order, the enum spelling and the `version` wrapper all match
// android/app/.../chat/ChatRepository.kt, which serialises with kotlinx and `encodeDefaults = true`.
// So `stop` is written even when it is null, and `reported` even when it is false.
//
// spine: C3, C7

import Foundation

/// Why a reply ended. Wire names match Kotlin's `enum class Stop` exactly.
public enum Stop: String, Codable, Sendable, CaseIterable {
    case endOfTurn = "END_OF_TURN"
    case cancelled = "CANCELLED"
    case contextFull = "CONTEXT_FULL"
    case maxTokens = "MAX_TOKENS"
    case error = "ERROR"
    /// The OS took memory back while the reply was being written (leaves/design.md §7).
    case lowMemory = "LOW_MEMORY"
    /// iOS: the background allowance ran out before the reply finished (leaves/design.md §5.1).
    /// A capability behaviour, not a platform one — it fires wherever the allowance is short (C11).
    case backgrounded = "BACKGROUNDED"
}

public struct Message: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let fromUser: Bool
    public var text: String
    public let createdAt: Int64
    /// Null while streaming, and on the user's own messages.
    public var stop: Stop?
    /// The user flagged this reply with Report. Kept on the phone; the report itself goes by Mail. spine: C9
    public var reported: Bool

    public init(id: String = UUID().uuidString,
                fromUser: Bool,
                text: String,
                createdAt: Int64 = Message.now(),
                stop: Stop? = nil,
                reported: Bool = false) {
        self.id = id
        self.fromUser = fromUser
        self.text = text
        self.createdAt = createdAt
        self.stop = stop
        self.reported = reported
    }

    /// Milliseconds since the epoch, like Kotlin's `System.currentTimeMillis()`.
    public static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    private enum CodingKeys: String, CodingKey { case id, fromUser, text, createdAt, stop, reported }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fromUser = try c.decode(Bool.self, forKey: .fromUser)
        text = try c.decode(String.self, forKey: .text)
        createdAt = try c.decode(Int64.self, forKey: .createdAt)
        // A stop reason this build does not know is not a reason to lose the message. Kotlin's
        // `ignoreUnknownKeys` does the same for fields; this does it for values.
        stop = (try? c.decode(String.self, forKey: .stop)).flatMap(Stop.init(rawValue:))
        reported = (try? c.decode(Bool.self, forKey: .reported)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fromUser, forKey: .fromUser)
        try c.encode(text, forKey: .text)
        try c.encode(createdAt, forKey: .createdAt)
        // encodeDefaults = true on the Kotlin side: the key is present even when the value is null.
        if let stop { try c.encode(stop, forKey: .stop) } else { try c.encodeNil(forKey: .stop) }
        try c.encode(reported, forKey: .reported)
    }
}

public struct StoredConversation: Codable, Equatable, Sendable {
    public var version: Int
    public var messages: [Message]

    public init(version: Int = 1, messages: [Message] = []) {
        self.version = version
        self.messages = messages
    }

    private enum CodingKeys: String, CodingKey { case version, messages }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        // Deliberately NOT tolerant: a malformed message must throw, so ChatRepository sets the file
        // aside instead of quietly starting an empty conversation over the top of it.
        messages = try c.decode([Message].self, forKey: .messages)
    }
}
