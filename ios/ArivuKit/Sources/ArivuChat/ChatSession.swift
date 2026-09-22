// The chat state machine — the iOS twin of Android's ChatViewModel.
//
// It holds no SwiftUI and no UIKit, so every state transition in leaves/design.md §3 can be driven
// from a test on this machine: Starting, Reading, streaming, Stopped, Cut off, Reply limit, Low on
// memory, Stopped in the background, Message too long, Load failed, Load failed low memory, the
// context divider, and a reply recovered after process death.
//
// spine: C1, C5, C7, C9, C10

import ArivuCore
import ArivuEngine
import Combine
import Foundation

public enum Notice: Equatable, Sendable {
    case tooLong(messageTokens: Int32, limitTokens: Int32)
    case loadFailed
    case loadFailedLowMemory

    /// The catalogue key. Copy is never assembled in Swift (leaves/design.md §14, request 1).
    public var key: StringKey {
        switch self {
        case .tooLong: return .message_too_long
        case .loadFailed: return .load_failed
        case .loadFailedLowMemory: return .load_failed_low_memory
        }
    }

    public var text: String {
        switch self {
        case .tooLong(let tokens, let limit):
            // Users are not shown token counts: they do not know tokens, they know "half".
            return Strings.string(.message_too_long,
                                  BuiltPrompt.shorterPercent(messageTokens: tokens, limitTokens: limit))
        case .loadFailed, .loadFailedLowMemory:
            return Strings.string(key)
        }
    }
}

/// Which "Starting" sentence is on screen. One idea per string: the line is *replaced*, never
/// appended to (leaves/design.md §5.2).
public enum StartingPhase: Equatable, Sendable {
    case normal
    case firstRun
    case long

    public var key: StringKey {
        switch self {
        case .normal: return .state_starting
        case .firstRun: return .state_starting_first_run
        case .long: return .state_starting_long
        }
    }
}

/// A send that failed before the model wrote anything, offered back to the input box (D-060).
///
/// An *offer*, not an action: the session cannot see the input field, so it cannot know whether
/// taking the text back would overwrite something the user has since typed. The view answers with
/// `acceptRetry()` or `declineRetry()`, and only an accept removes anything from the conversation.
/// Declining leaves the message exactly where it was, which is the behaviour this replaces — so the
/// worst case is the old behaviour rather than lost words.
public struct PendingRetry: Equatable, Sendable {
    /// What the user wrote, to be put back in the input.
    public let text: String
    let userID: String
    let replyID: String
}

@MainActor
public final class ChatSession: ObservableObject {
    /// False until history has been read from disk, so a returning user never sees the empty state flash.
    @Published public private(set) var loaded = false
    @Published public private(set) var messages: [Message] = []
    /// Id of the oldest message the model saw on the last send; nil when nothing was dropped. spine: C7
    @Published public private(set) var contextStartID: String?

    /// The wording THIS conversation runs with, or nil for the shipped one (D-064). Only the
    /// editable part: `Policy.systemPromptSafetySuffix` is added when the prompt is assembled.
    @Published public private(set) var customPromptBody: String?
    @Published public private(set) var generating = false
    @Published public private(set) var engineState: EngineState = .cold
    @Published public private(set) var notice: Notice?
    @Published public private(set) var startingPhase: StartingPhase = .normal
    /// Every conversation, newest first. Recomputed when one is opened, created or deleted.
    @Published public private(set) var conversations: [ConversationSummary] = []
    /// The one on screen.
    @Published public private(set) var currentID: String
    /// Set when a send failed before the model wrote anything. spine: C1, C6 (D-060)
    @Published public private(set) var pendingRetry: PendingRetry?
    /// The last reply's measurements, for the learning page. Nil until one has been produced —
    /// which is the honest state, not a zero (D-061).
    @Published public private(set) var lastStats: GenerationStats?
    /// What the loaded GGUF says about itself. Nil until the model is mapped, because it is mapped
    /// lazily on the first message (C1) and no page is worth forcing that.
    @Published public private(set) var modelInfo: ModelInfo?

    /// Which conversation is open. `var`, because switching conversations is switching this file —
    /// every other property of the store (atomic writes, data protection, backup exclusion) comes
    /// along unchanged (D-011).
    private var repository: ChatRepository
    private let store: ConversationStore
    private let controller: InferenceController
    /// `var`, because the wording is per conversation now (D-064): switching conversations or
    /// editing the prompt replaces the builder rather than mutating it, which also throws away its
    /// token cache — the right thing, since the cache is keyed on turns whose header has changed.
    private var promptBuilder: PromptBuilder
    private var generation: Task<Void, Never>?
    private var startingTimer: Task<Void, Never>?
    private var stateWatcher: Task<Void, Never>?

    public init(store: ConversationStore, controller: InferenceController, openID: String? = nil) {
        self.store = store
        let id = openID ?? store.list().first?.id ?? store.create()
        self.currentID = id
        self.repository = store.repository(for: id)
        self.controller = controller
        let stored = self.repository.loadStored()
        self.customPromptBody = stored.systemPromptBody
        self.promptBuilder = controller.makePromptBuilder(
            systemPrompt: Policy.systemPrompt(customBody: stored.systemPromptBody))

        // The stream, not the controller: capturing `controller` here would keep it alive for as
        // long as this task is suspended, which is forever, because the stream only finishes when
        // the controller goes. That circle leaked an engine per session before it was spotted.
        let states = controller.states
        stateWatcher = Task { [weak self] in
            for await state in states {
                await MainActor.run { self?.engineState = state }
            }
        }
    }

    deinit {
        generation?.cancel()
        startingTimer?.cancel()
        stateWatcher?.cancel()
    }

    // MARK: - Conversations (D-011)

    /// Open another conversation. A reply in flight is stopped first: letting one finish into a file
    /// the user has navigated away from would write text into a conversation they are not looking at.
    public func open(_ id: String) {
        guard id != currentID else { return }
        if generating { controller.cancelBox.request(.user) }
        generation?.cancel()
        currentID = id
        repository = store.repository(for: id)
        let stored = repository.loadStored()
        messages = stored.messages.map(Self.repairUnfinished)
        adoptPrompt(stored.systemPromptBody)
        contextStartID = nil
        notice = nil
        pendingRetry = nil
        generating = false
        stopStartingPhase()
        refreshConversations()
    }

    /// Start a new one. Does nothing if the current conversation is already empty, so tapping twice
    /// cannot leave a trail of blank conversations behind.
    public func newConversation() {
        guard !messages.isEmpty else { return }
        open(store.create())
    }

    /// spine: C3 — the first way a user has ever had to take their own text off the device.
    public func delete(_ id: String) {
        // Deleting the conversation currently being written into stops the writing first. Without
        // this the generation keeps running against a conversation that no longer exists, and its
        // final save lands in whichever conversation was opened in its place — a reply appearing in
        // a thread that never asked for it (spine: C7, C10).
        if id == currentID && generating { stop() }
        store.delete(id)
        if id == currentID {
            let next = store.list().first?.id ?? store.create()
            currentID = next
            repository = store.repository(for: next)
            let stored = repository.loadStored()
            messages = stored.messages.map(Self.repairUnfinished)
            adoptPrompt(stored.systemPromptBody)
            contextStartID = nil
            notice = nil
            pendingRetry = nil
        }
        refreshConversations()
    }

    // MARK: - The wording this conversation runs with (D-064)

    /// The prompt as the model will actually receive it, safety sentences included. The one place
    /// a prompt is assembled, so there is no path that assembles one without them.
    public var effectiveSystemPrompt: String { Policy.systemPrompt(customBody: customPromptBody) }

    public var usesCustomPrompt: Bool { customPromptBody != nil }

    /// Edit the wording, or pass nil to go back to the shipped one. Takes effect on the next
    /// message; replies already written were written under whatever was in force then, and the
    /// disclosure says so rather than redrawing history (spine: C7).
    public func setCustomPrompt(_ body: String?) {
        let cleaned = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved: String?
        if let cleaned, !cleaned.isEmpty,
           cleaned != Policy.systemPromptBody.trimmingCharacters(in: .whitespacesAndNewlines) {
            resolved = String(cleaned.prefix(Policy.customPromptMaxChars))
        } else {
            // Empty, whitespace, or the standard wording typed back in by hand: all of them mean
            // "standard", and storing it as a custom string would mark the conversation edited for
            // a prompt that is not.
            resolved = nil
        }
        guard resolved != customPromptBody else { return }
        customPromptBody = resolved
        promptBuilder = controller.makePromptBuilder(systemPrompt: effectiveSystemPrompt)
        persist()
    }

    // MARK: - The token playground (D-065)

    /// Count tokens in arbitrary text with the REAL tokenizer, for the learning page.
    ///
    /// It goes through the same `InferenceController.countTokens` the prompt builder uses, which
    /// means it maps the model if the model is not mapped — a second or two on a cold start. That
    /// cost is why the playground counts on a tap rather than on every keystroke: a learning page
    /// that silently loads a gigabyte because someone typed a letter has taught them something
    /// untrue about what this costs.
    public func countTokens(_ text: String) async -> Int32? {
        try? await controller.countTokens(text)
    }

    /// What the conversation's own instructions cost, in tokens. The figure the context budget is
    /// actually spending before the user has written anything.
    public func systemPromptTokens() async -> Int32? {
        try? await controller.countTokens(PromptBuilder.system(effectiveSystemPrompt)
                                          + PromptBuilder.assistantOpen)
    }

    public func refreshConversations() {
        conversations = store.list()
    }

    /// A reply interrupted by process death is kept, and marked as stopped. The app cannot know why
    /// it was killed, so it does not guess (leaves/design.md §3).
    private static func repairUnfinished(_ message: Message) -> Message {
        guard !message.fromUser, message.stop == nil else { return message }
        var repaired = message
        repaired.stop = stopAfterProcessDeath
        return repaired
    }

    public func loadHistory() async {
        guard !loaded else { return }
        let stored = await Task.detached(priority: .userInitiated) { [repository] in repository.load() }.value
        // A reply interrupted by process death is kept, and marked as stopped. The app cannot know
        // why it was killed, so it does not guess (leaves/design.md §3).
        messages = stored.map(Self.repairUnfinished)
        loaded = true
        refreshConversations()
    }

    // MARK: - Sending

    public func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !generating, loaded else { return }

        let now = Message.now()
        let user = Message(fromUser: true, text: trimmed, createdAt: now)
        // The reply bubble exists from the first moment, so "Starting Arivu…" is on screen while the
        // model is mapped and the prompt is measured (spine: C1), and Stop works throughout (C10).
        let reply = Message(fromUser: false, text: "", createdAt: now)
        messages.append(user)
        messages.append(reply)
        generating = true
        notice = nil
        pendingRetry = nil
        startStartingPhase()
        persist()

        generation = Task { [weak self] in
            guard let self else { return }
            await self.runSend(replyID: reply.id, userID: user.id)
        }
    }

    private func runSend(replyID: String, userID: String) async {
        let history = messages.filter { !$0.text.isEmpty }
        let turns = history.map { Turn(id: $0.id, fromUser: $0.fromUser, text: $0.text) }

        let built: BuiltPrompt
        do {
            built = try await promptBuilder.build(turns: turns)
        } catch {
            generating = false
            stopStartingPhase()
            notice = Self.notice(for: error)
            offerRetry(replyID: replyID, userID: userID)
            persist()
            return
        }

        switch built {
        case .tooLong(let messageTokens, let limitTokens):
            // Back to the input, where it can actually be shortened. It used to stay in the
            // conversation "so the user can copy and shorten it" — but a bubble has no cursor, and
            // the notice asks for an edit the user had no way to make in place (D-060).
            generating = false
            stopStartingPhase()
            notice = .tooLong(messageTokens: messageTokens, limitTokens: limitTokens)
            offerRetry(replyID: replyID, userID: userID)
            persist()

        case .ok(let text, let promptTokens, let firstIncluded):
            contextStartID = firstIncluded > 0 ? history[firstIncluded].id : nil
            await runGeneration(replyID: replyID,
                                userID: userID,
                                prompt: text,
                                maxNewTokens: controller.maxReplyTokens(promptTokens: promptTokens),
                                // Where the model's window starts, kept as an id: it is the one
                                // input to the prompt that cannot be derived later, because
                                // PromptBuilder drops old turns to fit. Everything else the
                                // disclosure needs it can rebuild (PromptTranscript).
                                contextFirstID: history[firstIncluded].id)
        }
    }

    private func runGeneration(replyID: String, userID: String, prompt: String,
                               maxNewTokens: Int32, contextFirstID: String) async {
        var stop: Stop = .error
        var reply: ReplyStats?
        var lastSave = Date()
        do {
            for try await event in controller.generate(prompt: prompt, maxNewTokens: maxNewTokens) {
                switch event {
                case .text(let piece):
                    stopStartingPhase()
                    updateMessage(replyID) { $0.text += piece }
                    // spine: C7 — a reply cut short by process death keeps what was written.
                    // Throttled: one small file write every couple of seconds, not per token.
                    if Date().timeIntervalSince(lastSave) >= Policy.streamSaveSeconds {
                        lastSave = Date()
                        persist()
                    }
                case .done(let stats):
                    stop = resolveStop(stats.stop, cancelCause: controller.cancelBox.cause)
                    if stats.generated > 0 {
                        lastStats = stats
                        // The numbers belong to this reply, so they are stored on it and shown
                        // under it. A cancelled reply that wrote nothing gets none: there is no
                        // rate to quote for zero tokens (spine: C5, C6).
                        reply = ReplyStats(promptTokens: stats.promptTokens,
                                           generatedTokens: stats.generated,
                                           decodeMs: stats.decodeMs,
                                           contextFirstID: contextFirstID,
                                           systemPromptHash: PromptTranscript.hash(self.effectiveSystemPrompt))
                    }
                }
            }
        } catch {
            // The bubble carries the same verdict as the notice. This said `.error` while the
            // notice said "your phone is low on memory", so the saved reply disagreed with the
            // sentence above it — and Android labels the same failure LOW_MEMORY (spine: C6, C11).
            let isMemory = (error as? ArivuEngineError)?.isMemoryFailure == true
            stop = isMemory ? .lowMemory : .error
            notice = Self.notice(for: error)
            // `controller.generate` throws only for a model or context that would not load, so
            // nothing has been written and the whole send can be offered back. This is the headline
            // case: on iOS jetsam gives no warning, so "the phone was briefly busy" is the expected
            // failure and the same send usually succeeds a moment later (D-060).
            offerRetry(replyID: replyID, userID: userID)
        }

        updateMessage(replyID) {
            $0.stop = stop
            $0.stats = reply
            $0.text = String($0.text.reversed().drop { $0.isWhitespace }.reversed())
        }
        generating = false
        stopStartingPhase()
        persist()

        // The model is mapped by now, so the card can be read. Once only: it cannot change while
        // one model ships.
        if modelInfo == nil {
            Task { [weak self] in
                guard let info = await self?.controller.modelInfo() else { return }
                await MainActor.run { self?.modelInfo = info }
            }
        }
    }

    // MARK: - The user's controls

    /// spine: C10 — works at any moment, including while the model is still being mapped.
    public func stop() {
        controller.cancelBox.request(.user)
    }

    public func dismissNotice() { notice = nil }

    // MARK: - Retrying a send that failed before anything was written (D-060)

    /// The view took the text into its input: drop the unanswered pair from the conversation, so
    /// the user is not left looking at a message with no reply next to a copy of it they are about
    /// to send again.
    public func acceptRetry() {
        guard let retry = pendingRetry else { return }
        removeMessage(retry.replyID)
        removeMessage(retry.userID)
        pendingRetry = nil
        persist()
    }

    /// The view could not take it — the user has typed something else since. Leave the conversation
    /// exactly as it was: the message stays visible and copyable, which is what happened before
    /// D-060 and is the one outcome that cannot lose anything.
    public func declineRetry() {
        pendingRetry = nil
    }

    /// Offers the send back. Refuses if anything was written, because a reply with text in it is
    /// kept and labelled (C7) and resuming that is D-032, not this.
    private func offerRetry(replyID: String, userID: String) {
        guard let reply = messages.first(where: { $0.id == replyID }), reply.text.isEmpty,
              let user = messages.first(where: { $0.id == userID }), !user.text.isEmpty
        else { return }
        pendingRetry = PendingRetry(text: user.text, userID: userID, replyID: replyID)
    }

    /// spine: C9 — the reply is marked on the phone when the user confirms the report sheet.
    public func markReported(_ id: String) {
        updateMessage(id) { $0.reported = true }
        persist()
    }

    // MARK: - Events from the app

    public func onForeground() {
        Task { await controller.onUIVisible() }
    }

    /// Going to the background. The context is freed immediately unless a reply is in flight; on
    /// iOS nothing waits to be warned (see InferenceController).
    public func onBackground() {
        Task { await controller.onUIHidden() }
    }

    /// `didReceiveMemoryWarning`, while a reply is being written: stop cleanly, keep the partial
    /// text, and label it. Silent when nothing is in flight — nothing of the user's was lost, so
    /// there is nothing to tell them (leaves/design.md §5.3).
    public func onMemoryWarning() {
        if generating { controller.cancelBox.request(.memoryPressure) }
        Task { await controller.onMemoryWarning() }
    }

    /// The background assertion is about to expire. Same cancel path as Stop, so the partial reply
    /// is saved by the same throttled save and labelled `stopped_backgrounded`
    /// (leaves/design.md §5.1, §14 request 2).
    public func onBackgroundTimeExpiring() {
        if generating { controller.cancelBox.request(.backgroundExpiring) }
    }

    // MARK: - Internals

    private func startStartingPhase() {
        startingPhase = controller.hasLoadedBefore ? .normal : .firstRun
        startingTimer?.cancel()
        startingTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Policy.startingLongSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.generating else { return }
                self.startingPhase = .long
            }
        }
    }

    private func stopStartingPhase() {
        startingTimer?.cancel()
        startingTimer = nil
    }

    private static func notice(for error: Error) -> Notice {
        if let engineError = error as? ArivuEngineError, engineError.isMemoryFailure {
            return .loadFailedLowMemory
        }
        return .loadFailed
    }

    /// Adopt the wording a conversation was saved with, rebuilding the builder only when it
    /// actually differs — a new builder throws away a token cache that is usually still valid.
    private func adoptPrompt(_ body: String?) {
        guard body != customPromptBody else { return }
        customPromptBody = body
        promptBuilder = controller.makePromptBuilder(systemPrompt: effectiveSystemPrompt)
    }

    private func removeMessage(_ id: String) {
        messages.removeAll { $0.id == id }
    }

    private func updateMessage(_ id: String, _ change: (inout Message) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }

    private func persist() {
        let snapshot = messages
        let prompt = customPromptBody
        Task.detached(priority: .utility) { [repository] in
            repository.save(snapshot, systemPromptBody: prompt)
        }
        // The list shows each conversation's first line and its age, so it changes when the
        // conversation does. Cheap enough to redo here; if it stops being, it needs an index.
        refreshConversations()
    }
}
