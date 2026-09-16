// The chat state machine, driven through the states in leaves/design.md §3.
//
// These run against the fake core, so they say nothing about model quality or speed. What they do
// say is that every state the Design Leaf specifies is reachable, that a partial reply is always
// kept, and that a stop is labelled by *why* it happened — which is the difference between "Stopped",
// "your phone ran low on memory" and "Arivu cannot keep writing while you are in another app".
//
// spine: C1, C5, C7, C9, C10

import CArivuStub
import Foundation
import Testing
@testable import ArivuChat
@testable import ArivuCore
@testable import ArivuEngine

@MainActor
private final class Harness {
    let directory: URL
    let repository: ChatRepository
    let controller: InferenceController
    let session: ChatSession
    private let modelFile: URL

    init(profile: Profile = .compact, loadedBefore: Bool = true) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("arivu-chat-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        modelFile = directory.appendingPathComponent("model.gguf")
        try Data(repeating: 0x42, count: 4096).write(to: modelFile)

        repository = ChatRepository(url: directory.appendingPathComponent("conversation.json"))
        let defaults = UserDefaults(suiteName: "arivu.chat.tests.\(UUID().uuidString)")!
        let flag = LoadedBeforeFlag(defaults: defaults)
        if loadedBefore { flag.set() }
        controller = InferenceController(modelSource: FileModelSource(url: modelFile),
                                         profile: profile,
                                         loadedBefore: flag)
        session = ChatSession(repository: repository, controller: controller)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    /// Waits for the session to stop generating, or gives up. Tests must never hang a whole run.
    func settle(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while session.generating && Date() < deadline {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(!session.generating, "generation did not finish within \(timeout)s")
    }

    func waitForText(in id: String, atLeast count: Int, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while (session.messages.first { $0.id == id }?.text.count ?? 0) < count && Date() < deadline {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}

@Suite(.serialized)
@MainActor
struct ChatSessionTests {
    init() { arivu_stub_reset() }

    @Test("a first message shows both bubbles at once, then streams")
    func firstMessage() async throws {
        arivu_stub_set_script("Dear parents, the trip is on Friday.")
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send("Write a short letter to parents")
        // Both bubbles exist from the same moment, so "Starting Arivu…" has somewhere to live (C1).
        #expect(h.session.messages.count == 2)
        #expect(h.session.messages[0].fromUser)
        #expect(h.session.messages[1].text.isEmpty)
        #expect(h.session.generating)

        try await h.settle()
        #expect(h.session.messages[1].text == "Dear parents, the trip is on Friday.")
        #expect(h.session.messages[1].stop == .endOfTurn)
        #expect(h.session.notice == nil)
    }

    @Test("Stop keeps the partial text and labels it Stopped")
    func stopKeepsPartialText() async throws {
        arivu_stub_set_script(String(repeating: "word ", count: 400))
        arivu_stub_set_piece_delay_us(300)
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send("go")
        let replyID = h.session.messages[1].id
        try await h.waitForText(in: replyID, atLeast: 10)
        h.session.stop()
        try await h.settle()

        let reply = h.session.messages.first { $0.id == replyID }
        #expect(reply?.stop == .cancelled)
        #expect(reply?.text.isEmpty == false, "the partial reply was thrown away")
        #expect((reply?.text.count ?? 0) < 400 * 5)
    }

    /// leaves/design.md §14, request 3 — and Android's bug 2: Stop during the cold start was ignored
    /// and the reply was generated anyway.
    @Test("Stop works before a single token exists")
    func stopDuringStarting() async throws {
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send("go")
        h.session.stop()   // same instant: the model has not been mapped yet
        try await h.settle()

        let reply = h.session.messages[1]
        #expect(reply.stop == .cancelled)
        #expect(reply.text.isEmpty, "a stop before any token must not produce a reply")
    }

    /// leaves/design.md §7 — the user's own Stop keeps its label; memory pressure gets its own.
    @Test("memory pressure mid-reply is labelled as memory, not as Stopped")
    func memoryPressureLabel() async throws {
        arivu_stub_set_script(String(repeating: "word ", count: 400))
        arivu_stub_set_piece_delay_us(300)
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send("go")
        let replyID = h.session.messages[1].id
        try await h.waitForText(in: replyID, atLeast: 10)
        h.session.onMemoryWarning()
        try await h.settle()

        let reply = h.session.messages.first { $0.id == replyID }
        #expect(reply?.stop == .lowMemory)
        #expect(reply?.text.isEmpty == false)
    }

    /// leaves/design.md §5.1 — the background allowance running out is its own sentence, and it
    /// travels the same cancel path as Stop, so the partial reply is saved the same way.
    @Test("the background allowance running out is labelled as itself")
    func backgroundExpiryLabel() async throws {
        arivu_stub_set_script(String(repeating: "word ", count: 400))
        arivu_stub_set_piece_delay_us(300)
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send("go")
        let replyID = h.session.messages[1].id
        try await h.waitForText(in: replyID, atLeast: 10)
        h.session.onBackgroundTimeExpiring()
        try await h.settle()

        #expect(h.session.messages.first { $0.id == replyID }?.stop == .backgrounded)
    }

    @Test("a reply that hits its length limit says so")
    func replyLimit() async throws {
        arivu_stub_set_script("a b c d e f g h")
        var profile = Profile.compact
        profile.maxReplyTokens = 3
        let h = try Harness(profile: profile)
        await h.session.loadHistory()

        h.session.send("go")
        try await h.settle()
        #expect(h.session.messages[1].stop == .maxTokens)
    }

    @Test("a full context is Cut off, and the partial reply is kept")
    func contextFull() async throws {
        let h = try Harness()
        await h.session.loadHistory()
        arivu_stub_next_stop_context_full()

        h.session.send("go")
        try await h.settle()
        #expect(h.session.messages[1].stop == .contextFull)
    }

    /// leaves/design.md §3 — the message stays so it can be copied and shortened; the reply bubble
    /// that appeared is removed; nothing is sent.
    @Test("a message that is too long is reported, and the message is kept")
    func messageTooLong() async throws {
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send(String(repeating: "x", count: 5000))
        try await h.settle()

        #expect(h.session.messages.count == 1, "the reply bubble should have been removed")
        #expect(h.session.messages[0].fromUser)
        #expect(h.session.messages[0].text.count == 5000)
        guard case .tooLong(let messageTokens, let limitTokens) = h.session.notice else {
            Issue.record("expected a tooLong notice, got \(String(describing: h.session.notice))"); return
        }
        #expect(messageTokens > limitTokens)
        // The user is told how much shorter, never how many tokens.
        #expect(h.session.notice?.text.contains("% as long") == true)
        #expect(h.session.notice?.text.contains("token") == false)
    }

    /// leaves/design.md §7 — a memory failure must not wear the generic "close Arivu fully" message,
    /// which sends the user to a remedy that will not help.
    @Test("a load failure names memory when it was memory")
    func loadFailureNotices() async throws {
        let h = try Harness()
        await h.session.loadHistory()

        arivu_stub_fail_next_load("gguf: unknown magic")
        h.session.send("go")
        try await h.settle()
        #expect(h.session.notice == .loadFailed)
        #expect(h.session.messages.count == 1, "no empty reply bubble should be left behind")

        h.session.dismissNotice()
        arivu_stub_fail_next_load("failed to allocate: Cannot allocate memory")
        h.session.send("again")
        try await h.settle()
        #expect(h.session.notice == .loadFailedLowMemory)
        #expect(h.session.notice?.text.contains("low on memory") == true)
    }

    /// spine: C7 — the edge of what the model can see is shown, never crossed silently.
    @Test("dropped history sets the context divider")
    func contextDivider() async throws {
        arivu_stub_set_script("ok")
        let h = try Harness()
        await h.session.loadHistory()

        for round in 0..<6 {
            h.session.send(String(repeating: "y", count: 200) + " \(round)")
            try await h.settle()
        }
        #expect(h.session.contextStartID != nil, "history was dropped without telling the user")
        let index = h.session.messages.firstIndex { $0.id == h.session.contextStartID }
        #expect(index != nil)
        #expect(h.session.messages[index ?? 0].fromUser,
                "the divider must sit above a user turn, never above a reply with no question")
    }

    /// spine: C7 — a reply the OS interrupted is kept and labelled, and the app does not guess why.
    @Test("an unfinished reply found on disk is labelled Stopped")
    func processDeathRecovery() async throws {
        let h = try Harness()
        h.repository.save([
            Message(id: "u", fromUser: true, text: "hello", createdAt: 1),
            Message(id: "r", fromUser: false, text: "half a re", createdAt: 2, stop: nil),
        ])
        await h.session.loadHistory()
        #expect(h.session.messages.count == 2)
        #expect(h.session.messages[1].text == "half a re")
        #expect(h.session.messages[1].stop == .cancelled)
    }

    @Test("the conversation survives a restart, reported flag and all")
    func persistence() async throws {
        arivu_stub_set_script("fine")
        let h = try Harness()
        await h.session.loadHistory()
        h.session.send("hello")
        try await h.settle()
        h.session.markReported(h.session.messages[1].id)

        // Give the detached save a moment, then read the file back through a new repository.
        try await Task.sleep(nanoseconds: 200_000_000)
        let reloaded = ChatRepository(url: h.repository.url).load()
        #expect(reloaded.count == 2)
        #expect(reloaded[1].text == "fine")
        #expect(reloaded[1].reported)
        #expect(reloaded[1].stop == .endOfTurn)
    }

    /// leaves/design.md §5.2 — the first send after install gets its own line; every later one does not.
    @Test("the first-ever send says it is the slowest it will ever be")
    func firstRunStartingLine() async throws {
        arivu_stub_set_script("ok")
        let fresh = try Harness(loadedBefore: false)
        await fresh.session.loadHistory()
        fresh.session.send("go")
        #expect(fresh.session.startingPhase == .firstRun)
        #expect(Strings.string(fresh.session.startingPhase.key).contains("slowest it will ever be"))
        try await fresh.settle()

        let returning = try Harness(loadedBefore: true)
        await returning.session.loadHistory()
        returning.session.send("go")
        #expect(returning.session.startingPhase == .normal)
        try await returning.settle()
    }

    @Test("an empty or whitespace message sends nothing")
    func emptySendIsIgnored() async throws {
        let h = try Harness()
        await h.session.loadHistory()
        h.session.send("   \n ")
        #expect(h.session.messages.isEmpty)
        #expect(!h.session.generating)
    }

    @Test("a second send while a reply is being written is ignored")
    func noConcurrentSends() async throws {
        arivu_stub_set_script(String(repeating: "word ", count: 200))
        arivu_stub_set_piece_delay_us(300)
        let h = try Harness()
        await h.session.loadHistory()

        h.session.send("first")
        h.session.send("second")
        #expect(h.session.messages.count == 2)
        h.session.stop()
        try await h.settle()
    }
}
