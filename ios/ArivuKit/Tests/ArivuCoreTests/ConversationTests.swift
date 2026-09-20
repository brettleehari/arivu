// The conversation file is a cross-platform contract (MULTIPLATFORM.md appendix), so these tests
// check the bytes, not just the round trip: field names, field order, the null `stop`, the `false`
// `reported`, the `version` wrapper, and the enum spellings Kotlin writes.
//
// The behaviour tests mirror android/app/src/test/.../ChatRepositoryTest.kt case for case.
//
// spine: C3, C7

import Foundation
import Testing
@testable import ArivuCore

@Suite("Conversation JSON and the file it lives in")
struct ConversationTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("arivu-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("round trip keeps every field, including a stop reason and the reported flag")
    func roundTrip() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("conversation.json")
        let messages = [
            Message(id: "1", fromUser: true, text: "Rewrite: send it now", createdAt: 1),
            Message(id: "2", fromUser: false, text: "Could you send it, please? ✓ €", createdAt: 2,
                    stop: .contextFull, reported: true),
        ]
        ChatRepository(url: file).save(messages)
        #expect(ChatRepository(url: file).load() == messages)
    }

    /// The fields Kotlin writes with `encodeDefaults = true`. A JSON object is unordered and
    /// kotlinx's decoder ignores order, so the contract is the field names, the enum spellings and
    /// the presence of `stop: null` and `reported: false` — not the order. Our own output is sorted
    /// so that two saves of one conversation are the same bytes.
    @Test("the wire format carries every field kotlinx expects")
    func wireFormat() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("conversation.json")
        ChatRepository(url: file).save([
            Message(id: "a", fromUser: true, text: "hi", createdAt: 7),
            Message(id: "b", fromUser: false, text: "there", createdAt: 8, stop: .endOfTurn,
                    stats: ReplyStats(promptTokens: 12, generatedTokens: 34, decodeMs: 500,
                                      contextFirstID: "a", systemPromptHash: 99)),
        ])
        let json = try String(contentsOf: file, encoding: .utf8)
        #expect(json == #"{"messages":[{"createdAt":7,"fromUser":true,"id":"a","reported":false,"stats":null,"stop":null,"text":"hi"},{"createdAt":8,"fromUser":false,"id":"b","reported":false,"stats":{"contextFirstID":"a","decodeMs":500,"generatedTokens":34,"promptTokens":12,"systemPromptHash":99},"stop":"END_OF_TURN","text":"there"}"#
                     + #"],"version":1}"#)

        // The four things that would actually break the other platform.
        #expect(json.contains(#""stop":null"#), "kotlinx writes stop even when it is null")
        #expect(json.contains(#""reported":false"#), "kotlinx writes reported even when it is false")
        #expect(json.contains(#""stats":null"#), "kotlinx writes stats even when it is null")
        #expect(json.contains(#""version":1"#))
    }

    @Test("every stop reason keeps the spelling Kotlin uses")
    func stopSpellings() {
        let expected: [Stop: String] = [
            .endOfTurn: "END_OF_TURN", .cancelled: "CANCELLED", .contextFull: "CONTEXT_FULL",
            .maxTokens: "MAX_TOKENS", .error: "ERROR", .lowMemory: "LOW_MEMORY",
            .backgrounded: "BACKGROUNDED",
        ]
        for stop in Stop.allCases {
            #expect(stop.rawValue == expected[stop], "no agreed spelling for \(stop)")
        }
    }

    @Test("a missing file is an empty conversation, not an error")
    func missingFile() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(ChatRepository(url: dir.appendingPathComponent("none.json")).load().isEmpty)
    }

    @Test("a damaged file is set aside, never overwritten")
    func corruptIsSetAside() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("conversation.json")
        try "{not json".write(to: file, atomically: true, encoding: .utf8)

        #expect(ChatRepository(url: file).load().isEmpty)
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(left.contains { $0.hasPrefix("conversation.json.corrupt-") })
    }

    /// spine: C3 — damaged copies hold private text; only the newest one is kept.
    @Test("only the newest damaged copy is kept")
    func onlyNewestCorruptKept() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        for stamp in [100, 300, 200] {
            try "old".write(to: dir.appendingPathComponent("conversation.json.corrupt-\(stamp)"),
                            atomically: true, encoding: .utf8)
        }
        let file = dir.appendingPathComponent("conversation.json")
        try "{not json".write(to: file, atomically: true, encoding: .utf8)

        #expect(ChatRepository(url: file).load().isEmpty)
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("conversation.json.corrupt-") }
        #expect(left.count == 1)
        let stamp = Int64(left[0].replacingOccurrences(of: "conversation.json.corrupt-", with: "")) ?? 0
        #expect(stamp > 300, "kept an old copy instead of the newest: \(left)")
    }

    @Test("a stop reason a future build invented does not lose the message")
    func unknownStopReason() throws {
        let json = #"{"version":1,"messages":[{"id":"a","fromUser":false,"text":"hi","createdAt":1,"stop":"SOMETHING_NEW","reported":false}]}"#
        let decoded = try JSONDecoder().decode(StoredConversation.self, from: Data(json.utf8))
        #expect(decoded.messages.count == 1)
        #expect(decoded.messages[0].text == "hi")
        #expect(decoded.messages[0].stop == nil)
    }

    @Test("a message that cannot be read makes the whole file damaged, not silently empty")
    func malformedMessageThrows() {
        let json = #"{"version":1,"messages":[{"id":"a"}]}"#
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(StoredConversation.self, from: Data(json.utf8))
        }
    }

    @Test("a save that lands on top of an older one leaves no temp file behind")
    func noTempLeftBehind() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("conversation.json")
        let repository = ChatRepository(url: file)
        repository.save([Message(id: "a", fromUser: true, text: "one", createdAt: 1)])
        repository.save([Message(id: "a", fromUser: true, text: "two", createdAt: 1)])
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(left == ["conversation.json"])
        #expect(repository.load().first?.text == "two")
    }
}
