// The disclosure claims to show exactly what the model was given. This is the test that makes that
// claim true, and there is really only one that counts: build a prompt with the real PromptBuilder,
// rebuild it with PromptTranscript, and require the two strings to be equal. Anything less — a test
// that checks the rebuilt text merely "contains the system prompt" — would pass while the app shows
// a prompt that was never sent, which is worse than showing nothing (spine: C5, C6).
//
// spine: C5, C6, C7

import Foundation
import Testing
@testable import ArivuCore

@Suite("The prompt shown is the prompt that was sent")
struct PromptTranscriptTests {
    private let systemPrompt = "sys"

    private func builder(nCtx: Int32, reserve: Int32) -> PromptBuilder {
        PromptBuilder(systemPrompt: systemPrompt, nCtx: nCtx, replyReserve: reserve) { Int32($0.count) }
    }

    /// The conversation as the app holds it: turns, then an assistant message for the reply. The
    /// reply's own text is deliberately non-empty — it exists by the time anyone reads it back.
    private func conversation(_ turns: [Turn], replyStats: ReplyStats?) -> (Message, [Message]) {
        let history = turns.map {
            Message(id: $0.id, fromUser: $0.fromUser, text: $0.text, createdAt: 1)
        }
        let reply = Message(id: "reply", fromUser: false, text: "written", createdAt: 2,
                            stop: .endOfTurn, stats: replyStats)
        return (reply, history + [reply])
    }

    private func stats(firstIncluded: String, prompt: String? = nil) -> ReplyStats {
        ReplyStats(promptTokens: 1, generatedTokens: 1, decodeMs: 1,
                   contextFirstID: firstIncluded,
                   systemPromptHash: PromptTranscript.hash(prompt ?? systemPrompt))
    }

    @Test("a rebuilt prompt is byte-identical to the one the builder produced")
    func roundTrip() async throws {
        let turns = [
            Turn(id: "a", fromUser: true, text: "hello"),
            Turn(id: "b", fromUser: false, text: "hi there"),
            Turn(id: "c", fromUser: true, text: "explain AI and LLM in detail"),
        ]
        guard case .ok(let sent, _, let firstIncluded) =
                try await builder(nCtx: 2048, reserve: 512).build(turns: turns) else {
            Issue.record("the builder did not produce a prompt"); return
        }
        #expect(firstIncluded == 0, "nothing should have been dropped at this size")

        let (reply, messages) = conversation(turns, replyStats: stats(firstIncluded: turns[firstIncluded].id))
        #expect(try PromptTranscript.rebuild(reply: reply, in: messages,
                                             systemPrompt: systemPrompt).get() == sent)
    }

    /// The case the whole design turns on: when history is dropped to fit, the rebuild must drop
    /// exactly the same turns. Recording the window's first turn is what makes that possible.
    @Test("a prompt whose history was truncated rebuilds with the same turns dropped")
    func roundTripAfterTruncation() async throws {
        // One token per character, so a tight context forces old turns out.
        // Nine, so the newest turn is the user's — the builder refuses any other shape.
        let turns = (0..<9).map {
            Turn(id: "t\($0)", fromUser: $0 % 2 == 0, text: String(repeating: "x", count: 20))
        }
        guard case .ok(let sent, _, let firstIncluded) =
                try await builder(nCtx: 200, reserve: 20).build(turns: turns) else {
            Issue.record("the builder did not produce a prompt"); return
        }
        #expect(firstIncluded > 0, "this case is pointless unless something was dropped")

        let (reply, messages) = conversation(turns, replyStats: stats(firstIncluded: turns[firstIncluded].id))
        let rebuilt = try PromptTranscript.rebuild(reply: reply, in: messages,
                                                   systemPrompt: systemPrompt).get()
        #expect(rebuilt == sent)
        #expect(!rebuilt.contains(turns[0].id))
    }

    @Test("a reply written under a different system prompt refuses to show one it did not read")
    func systemPromptChanged() {
        let turns = [Turn(id: "a", fromUser: true, text: "hello")]
        let (reply, messages) = conversation(turns, replyStats: stats(firstIncluded: "a",
                                                                     prompt: "an older prompt"))
        #expect(PromptTranscript.rebuild(reply: reply, in: messages, systemPrompt: systemPrompt)
                == .failure(.systemPromptChanged))
    }

    @Test("a reply from before this was recorded says so rather than guessing")
    func notRecorded() {
        let turns = [Turn(id: "a", fromUser: true, text: "hello")]
        let (noStats, m1) = conversation(turns, replyStats: nil)
        #expect(PromptTranscript.rebuild(reply: noStats, in: m1, systemPrompt: systemPrompt)
                == .failure(.notRecorded))

        // Stats saved by the build that shipped the chat line but not the disclosure: the counts
        // are there, the window is not.
        let (older, m2) = conversation(turns, replyStats: ReplyStats(promptTokens: 9,
                                                                    generatedTokens: 9,
                                                                    decodeMs: 9))
        #expect(PromptTranscript.rebuild(reply: older, in: m2, systemPrompt: systemPrompt)
                == .failure(.notRecorded))
    }

    /// `hashValue` is seeded per process, so a stored hash would stop matching after a relaunch and
    /// every old reply would claim the prompt had changed. This one must not move.
    @Test("the hash is stable across launches and sensitive to any edit")
    func hashIsStableAndSensitive() {
        #expect(PromptTranscript.hash("") == 2_166_136_261)
        #expect(PromptTranscript.hash("sys") == PromptTranscript.hash("sys"))
        #expect(PromptTranscript.hash("sys") != PromptTranscript.hash("sy5"))
        // Same length, different words — the case a stored character count would miss.
        #expect(PromptTranscript.hash("Be brief and plain.") != PromptTranscript.hash("Be plain and brief."))
        #expect(PromptTranscript.hash(Policy.systemPrompt) > 0)
    }
}
