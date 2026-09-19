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
    @Published public private(set) var generating = false
    @Published public private(set) var engineState: EngineState = .cold
    @Published public private(set) var notice: Notice?
    @Published public private(set) var startingPhase: StartingPhase = .normal
    /// Set when a send failed before the model wrote anything. spine: C1, C6 (D-060)
    @Published public private(set) var pendingRetry: PendingRetry?

    private let repository: ChatRepository
    private let controller: InferenceController
    private let promptBuilder: PromptBuilder
    private var generation: Task<Void, Never>?
    private var startingTimer: Task<Void, Never>?
    private var stateWatcher: Task<Void, Never>?

    public init(repository: ChatRepository, controller: InferenceController) {
        self.repository = repository
        self.controller = controller
        self.promptBuilder = controller.makePromptBuilder()

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

    public func loadHistory() async {
        guard !loaded else { return }
        let stored = await Task.detached(priority: .userInitiated) { [repository] in repository.load() }.value
        // A reply interrupted by process death is kept, and marked as stopped. The app cannot know
        // why it was killed, so it does not guess (leaves/design.md §3).
        messages = stored.map { message in
            guard !message.fromUser, message.stop == nil else { return message }
            var repaired = message
            repaired.stop = stopAfterProcessDeath
            return repaired
        }
        loaded = true
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
                                maxNewTokens: controller.maxReplyTokens(promptTokens: promptTokens))
        }
    }

    private func runGeneration(replyID: String, userID: String, prompt: String, maxNewTokens: Int32) async {
        var stop: Stop = .error
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
            $0.text = String($0.text.reversed().drop { $0.isWhitespace }.reversed())
        }
        generating = false
        stopStartingPhase()
        persist()
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

    private func removeMessage(_ id: String) {
        messages.removeAll { $0.id == id }
    }

    private func updateMessage(_ id: String, _ change: (inout Message) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }

    private func persist() {
        let snapshot = messages
        Task.detached(priority: .utility) { [repository] in repository.save(snapshot) }
    }
}
