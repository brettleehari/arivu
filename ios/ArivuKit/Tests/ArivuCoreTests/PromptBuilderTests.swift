// The same cases as android/app/src/test/.../PromptBuilderTest.kt, with the same arithmetic.
//
// "Keep whole turns" is a product decision, not a platform one (MULTIPLATFORM.md appendix), so if
// these two test files ever disagree, one of the two apps is silently forgetting the user's words.
//
// spine: C7

import Testing
@testable import ArivuCore

@Suite("Prompt building and whole-turn truncation")
struct PromptBuilderTests {
    /// One token per character keeps the arithmetic obvious — the same trick the Kotlin test uses.
    private func builder(nCtx: Int32, reserve: Int32) -> PromptBuilder {
        PromptBuilder(systemPrompt: "sys", nCtx: nCtx, replyReserve: reserve) { Int32($0.count) }
    }

    private var fixed: Int32 {
        Int32(PromptBuilder.system("sys").count + PromptBuilder.assistantOpen.count)
    }

    private func turn(_ i: Int, user: Bool, length: Int) -> Turn {
        Turn(id: "t\(i)", fromUser: user, text: String(repeating: "x", count: length))
    }

    private func rendered(_ t: Turn) -> Int32 { Int32(PromptBuilder.render(t).count) }

    @Test("everything fits, firstIncluded is zero")
    func everythingFits() async throws {
        let turns = [turn(0, user: true, length: 10), turn(1, user: false, length: 10), turn(2, user: true, length: 10)]
        let result = try await builder(nCtx: 2048, reserve: 512).build(turns: turns)
        guard case .ok(let text, let promptTokens, let firstIncluded) = result else {
            Issue.record("expected .ok, got \(result)"); return
        }
        #expect(firstIncluded == 0)
        #expect(text.hasPrefix(PromptBuilder.system("sys")))
        #expect(text.hasSuffix(PromptBuilder.assistantOpen))
        #expect(Int(promptTokens) == text.count)
    }

    @Test("oldest turns are dropped, and the window starts on a user turn")
    func oldestDropped() async throws {
        let turns = [turn(0, user: true, length: 100), turn(1, user: false, length: 100),
                     turn(2, user: true, length: 100), turn(3, user: false, length: 100),
                     turn(4, user: true, length: 100)]

        // Room for exactly turns 2, 3, 4. Turn 2 is a user turn.
        let budget = rendered(turns[2]) + rendered(turns[3]) + rendered(turns[4])
        let first = try await builder(nCtx: fixed + budget + 50, reserve: 50).build(turns: turns)
        guard case .ok(_, _, let firstIncluded) = first else { Issue.record("expected .ok"); return }
        #expect(firstIncluded == 2)

        // Room for turns 3, 4 would start on assistant turn 3; the builder must skip to user turn 4.
        let second = try await builder(nCtx: fixed + rendered(turns[3]) + rendered(turns[4]) + 50, reserve: 50)
            .build(turns: turns)
        guard case .ok(_, _, let secondFirst) = second else { Issue.record("expected .ok"); return }
        #expect(secondFirst == 4)
    }

    @Test("a newest message that does not fit is reported, never truncated")
    func newestTooLong() async throws {
        let turns = [turn(0, user: true, length: 5000)]
        let result = try await builder(nCtx: 2048, reserve: 512).build(turns: turns)
        guard case .tooLong(let messageTokens, let limitTokens) = result else {
            Issue.record("expected .tooLong, got \(result)"); return
        }
        #expect(messageTokens == rendered(turns[0]))
        #expect(limitTokens == 2048 - 512 - fixed)
    }

    @Test("an empty history, or one that does not end with the user, is a programming error")
    func invalidHistory() async {
        await #expect(throws: PromptError.invalidHistory) {
            _ = try await builder(nCtx: 2048, reserve: 512).build(turns: [])
        }
        await #expect(throws: PromptError.invalidHistory) {
            _ = try await builder(nCtx: 2048, reserve: 512).build(turns: [turn(0, user: false, length: 10)])
        }
    }

    @Test("a tokenizer that fails is an error, not a silently short prompt")
    func countFailure() async {
        let failing = PromptBuilder(systemPrompt: "sys", nCtx: 2048, replyReserve: 512) { _ in -1 }
        await #expect(throws: PromptError.countFailed) {
            _ = try await failing.build(turns: [Turn(id: "a", fromUser: true, text: "hello")])
        }
    }

    @Test("the template is Qwen3 ChatML in non-thinking mode")
    func template() {
        #expect(PromptBuilder.assistantOpen == "<|im_start|>assistant\n<think>\n\n</think>\n\n")
        #expect(PromptBuilder.system("S") == "<|im_start|>system\nS<|im_end|>\n")
        #expect(PromptBuilder.render(Turn(id: "a", fromUser: true, text: "hi")) == "<|im_start|>user\nhi<|im_end|>\n")
        #expect(PromptBuilder.render(Turn(id: "b", fromUser: false, text: "ok")) == "<|im_start|>assistant\nok<|im_end|>\n")
    }

    /// The user is told how much shorter to make it, not how many tokens it was.
    @Test("the shorter-message percentage is clamped to something sayable")
    func shorterPercent() {
        #expect(BuiltPrompt.shorterPercent(messageTokens: 200, limitTokens: 100) == 50)
        #expect(BuiltPrompt.shorterPercent(messageTokens: 1000, limitTokens: 820) == 82)
        #expect(BuiltPrompt.shorterPercent(messageTokens: 10_000, limitTokens: 1) == 1)
        #expect(BuiltPrompt.shorterPercent(messageTokens: 10, limitTokens: 10_000) == 99)
        #expect(BuiltPrompt.shorterPercent(messageTokens: 0, limitTokens: 100) == 99)
    }

    /// The cache is keyed on id + text length, exactly as Kotlin keys it, so a settled turn is
    /// counted once and a streaming one is re-counted as it grows.
    @Test("token counts are cached per turn")
    func cachesCounts() async throws {
        let counter = CallCounter()
        let builder = PromptBuilder(systemPrompt: "sys", nCtx: 2048, replyReserve: 512) { text in
            await counter.record()
            return Int32(text.count)
        }
        let turns = [Turn(id: "a", fromUser: true, text: "one"),
                     Turn(id: "b", fromUser: false, text: "two"),
                     Turn(id: "c", fromUser: true, text: "three")]
        _ = try await builder.build(turns: turns)
        let afterFirst = await counter.count
        _ = try await builder.build(turns: turns)
        let afterSecond = await counter.count
        // Second build: system header and assistant open are not cached; the three turns are.
        #expect(afterSecond - afterFirst == 2)
    }
}

actor CallCounter {
    private(set) var count = 0
    func record() { count += 1 }
}
