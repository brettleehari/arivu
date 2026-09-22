// The one screen: message list, input, Send, Stop, Copy, Report. Nothing else (SPINE §3, R5).
//
// Every state in leaves/design.md §3 is here, and the behaviour is tested without SwiftUI in
// ArivuChatTests — this file renders that state machine and adds nothing to it.
//
// UNVERIFIED: not compiled. There is no iOS SDK on the machine this was written on.
//
// spine: C1, C5, C7, C9, C10

import ArivuChat
import ArivuCore
import SwiftUI
import UIKit

struct ChatView: View {
    @ObservedObject var session: ChatSession
    @State private var input = ""
    @State private var reportingID: String?
    @State private var editingPrompt = false
    @State private var copiedID: String?
    @State private var followsNewestLine = true
    @FocusState private var inputFocused: Bool
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        // `preferredCompactColumn: .detail` is the whole reason this is safe on iPhone: a split view
        // otherwise opens on the list, and Arivu would greet a new user with an empty table instead
        // of somewhere to type. C1 says one tap and it works, so the chat is what opens and the
        // conversations sit behind the back button.
        NavigationSplitView(columnVisibility: $columnVisibility,
                            preferredCompactColumn: .constant(.detail)) {
            ConversationsView(session: session)
        } detail: {
            VStack(spacing: 0) {
                content
                session.notice.map { NoticeBar(notice: $0, onDismiss: session.dismissNotice) }
                composer
            }
            .background(Palette.surface)
            .navigationTitle(Strings.string(.app_name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // A word, not a gear: there are no settings to put behind one (C8).
                    NavigationLink(Strings.string(.about)) { AboutView(session: session) }
                        .accessibilityIdentifier(A11y.about)
                }
            }
        }
        .sheet(item: Binding(get: { reportingID.map(Identified.init) },
                             set: { reportingID = $0?.id })) { wrapper in
            if let reply = session.messages.first(where: { $0.id == wrapper.id }) {
                ReportSheet(replyText: reply.text,
                            onReported: { session.markReported(wrapper.id) },
                            onDismiss: { reportingID = nil })
            }
        }
        .sheet(isPresented: $editingPrompt) { SystemPromptEditor(session: session) }
    }

    @ViewBuilder
    private var content: some View {
        if !session.loaded {
            // History is still being read: show nothing rather than flash the empty state.
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.messages.isEmpty {
            EmptyState()
        } else {
            messageList
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(session.messages) { message in
                        if message.id == session.contextStartID { ContextDivider() }
                        // Between the question and the answer, because that is where the question
                        // "how did six words become 196 tokens?" is actually asked.
                        PromptDisclosure(reply: message,
                                         messages: session.messages,
                                         systemPrompt: session.effectiveSystemPrompt,
                                         isCustom: session.usesCustomPrompt,
                                         onEdit: { editingPrompt = true })
                        MessageBubble(
                            message: message,
                            streaming: session.generating && message.id == session.messages.last?.id && !message.fromUser,
                            startingPhase: session.startingPhase,
                            engineState: session.engineState,
                            copied: copiedID == message.id,
                            onCopy: { copy(message) },
                            onReport: { reportingID = message.id })
                        .id(message.id)
                    }
                    // An anchor at the very end, so "follow the newest line" lands on the last line
                    // of a long reply rather than the top of it.
                    Color.clear.frame(height: 1).id(ScrollAnchor.bottom)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.messages.last?.text) { _, _ in follow(proxy) }
            .onChange(of: session.messages.count) { _, _ in follow(proxy) }
            // A reply that ends gains a label and a Copy/Report row without its text changing, and
            // that row must be scrolled into view too (found on the Android emulator run, bug 1).
            .onChange(of: session.messages.last?.stop) { _, _ in follow(proxy) }
            .onChange(of: session.generating) { _, _ in follow(proxy) }
        }
    }

    private func follow(_ proxy: ScrollViewProxy) {
        guard followsNewestLine else { return }
        proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(Strings.string(.input_hint), text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .textInputAutocapitalization(.sentences)
                .focused($inputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Palette.outline, lineWidth: 1))
                // Return inserts a newline (pasted text has paragraphs); ⌘Return sends.
                .onSubmit { /* nothing: Return is a newline */ }
                .accessibilityIdentifier(A11y.input)

            sendOrStop
        }
        .padding(12)
        .background(Palette.surface)
        // D-060: a send that failed before the model wrote anything comes back to the input, so the
        // Send button the user already knows is the retry — no second control, no new copy.
        //
        // Only when the box is empty. If they have started typing something else, decline: the
        // session then leaves the message in the conversation, which is what it did before D-060
        // and is the one outcome that cannot lose words.
        .onChange(of: session.pendingRetry) { _, retry in
            guard let retry else { return }
            if input.isEmpty {
                input = retry.text
                session.acceptRetry()
                inputFocused = true
            } else {
                session.declineRetry()
            }
        }
    }

    /// spine: C10 — Send and Stop share one slot at one size. There is never a moment with neither.
    @ViewBuilder
    private var sendOrStop: some View {
        if session.generating {
            Button(Strings.string(.stop)) { session.stop() }
                .accessibilityIdentifier(A11y.stop)
                .buttonStyle(.bordered)
                .frame(minWidth: Metrics.sendSlotWidth, minHeight: Metrics.sendSlotHeight)
                .accessibilityLabel(Strings.string(.a11y_stop))
        } else {
            Button(Strings.string(.send)) { send() }
                .accessibilityIdentifier(A11y.send)
                .buttonStyle(.borderedProminent)
                .frame(minWidth: Metrics.sendSlotWidth, minHeight: Metrics.sendSlotHeight)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !session.loaded)
                .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private func send() {
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !session.generating else { return }
        session.send(text)
        input = ""
        followsNewestLine = true
    }

    /// leaves/design.md §4 — iOS confirms nothing, so Arivu confirms itself: the Copy button's own
    /// label becomes "Copied" for 2 s. No toast, no banner, no overlay of our own.
    private func copy(_ message: Message) {
        UIPasteboard.general.string = message.text
        copiedID = message.id
        UIAccessibility.post(notification: .announcement, argument: Strings.string(.copied))
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Policy.copiedFeedbackSeconds * 1_000_000_000))
            if copiedID == message.id { copiedID = nil }
        }
    }
}

private enum ScrollAnchor: Hashable { case bottom }

/// `sheet(item:)` needs an Identifiable; a message id is a String.
private struct Identified: Identifiable { let id: String }

// MARK: - Pieces

private struct EmptyState: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(Strings.string(.empty_title))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(Strings.string(.empty_body))
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                Text(Strings.string(.empty_examples_label))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .padding(.top, 8)
                // Plain text, not buttons (D-030 is still open).
                VStack(spacing: 6) {
                    ForEach([StringKey.empty_example_1, .empty_example_2, .empty_example_3], id: \.self) { key in
                        Text(Strings.string(key))
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Palette.surfaceVariant, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}

/// spine: C7 — the visible edge of what the model can see.
private struct ContextDivider: View {
    var body: some View {
        VStack(spacing: 4) {
            Rectangle().fill(Palette.outline).frame(height: 1)
            Text(Strings.string(.context_divider))
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

private struct MessageBubble: View {
    let message: Message
    let streaming: Bool
    let startingPhase: StartingPhase
    let engineState: EngineState
    let copied: Bool
    let onCopy: () -> Void
    let onReport: () -> Void

    var body: some View {
        HStack {
            if message.fromUser { Spacer(minLength: Metrics.userBubbleLeadingInset) }
            VStack(alignment: .leading, spacing: 6) {
                // The message is ONE accessibility element; the actions beneath it are not part of
                // it. This used to combine the whole bubble, which read the Copy button's label
                // into the message ("You wrote: Say hello, Copy this message") and made the bubble
                // inherit the button's identifier — so a tap aimed at Copy landed on the message.
                // Found by dumping what the app actually exposes rather than what it looked like.
                VStack(alignment: .leading, spacing: 6) {
                if message.text.isEmpty && streaming {
                    HStack(spacing: 8) {
                        ProgressView().accessibilityHidden(true)
                        Text(Strings.string(startingLineKey))
                            .font(.body)
                    }
                } else if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .accessibilityLabel(Strings.string(message.fromUser ? .a11y_from_user : .a11y_from_arivu,
                                                           message.text))
                }

                stopLabelKey.map { key in
                    Text(Strings.string(key))
                        .font(.caption)
                        .foregroundStyle(isErrorLabel ? Palette.error : Palette.onSurfaceVariant)
                }

                if !message.fromUser && message.reported {
                    Text(Strings.string(.reported))
                        .font(.caption)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }

                // What this reply cost. Its own line, like the stop label and the reported label
                // above it, and NOT squeezed onto the Copy row: that row is already two buttons
                // wide, and at an accessibility text size the three of them would fight for a
                // bubble that cannot grow. A line that truncates to "24 in · 143 o…" is worse
                // than a line that costs 12 points.
                if let stats = message.stats, !streaming { StatsLine(stats: stats) }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(streaming ? Strings.string(.a11y_writing) : "")

                if !message.text.isEmpty && !streaming {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        if !message.fromUser {
                            // Report first, so Copy keeps its place at the edge.
                            Button(Strings.string(.report), action: onReport)
                                .accessibilityLabel(Strings.string(.a11y_report_reply))
                                .frame(minHeight: Metrics.minTouchTarget)
                        }
                        Button(copied ? Strings.string(.copied) : Strings.string(.copy), action: onCopy)
                            .accessibilityIdentifier(A11y.copy)
                            // The label has to move with the title. It was pinned to "Copy this
                            // message" in both states, so the confirmation design.md §4 exists to
                            // give — iOS confirms nothing, so Arivu confirms itself — reached
                            // sighted users and nobody else. A VoiceOver user tapped Copy and was
                            // told nothing had changed.
                            .accessibilityLabel(copied ? Strings.string(.copied)
                                                       : Strings.string(.a11y_copy_message))
                            .frame(minHeight: Metrics.minTouchTarget)
                    }
                    .font(.subheadline)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: Metrics.bubbleMaxWidth, alignment: .leading)
            .background(message.fromUser ? Palette.primaryContainer : Palette.surfaceVariant,
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(message.fromUser ? Palette.onPrimaryContainer : Palette.onSurfaceVariant)
            if !message.fromUser { Spacer(minLength: Metrics.replyBubbleTrailingInset) }
        }
    }

    /// While the model is being mapped the line is `state_starting`, or the first-run line, or —
    /// after 15 s — `state_starting_long`. Replaced, never appended (leaves/design.md §5.2).
    private var startingLineKey: StringKey {
        engineState == .starting ? startingPhase.key : .state_reading
    }

    private var stopLabelKey: StringKey? {
        switch message.stop {
        case nil, .endOfTurn: return nil
        case .cancelled: return .stopped_by_user
        case .contextFull: return .stopped_context_full
        case .maxTokens: return .stopped_max_tokens
        case .error: return .stopped_error
        case .lowMemory: return .stopped_low_memory
        case .backgrounded: return .stopped_backgrounded
        }
    }

    private var isErrorLabel: Bool {
        message.stop == .error || message.stop == .contextFull || message.stop == .lowMemory
    }
}

/// The exact text handed to the model, between the question and the answer.
///
/// Arivu is an appliance and a way to understand the appliance, and this is the second one doing
/// the work the first cannot. A user typed six words and the line under the reply said 196 tokens
/// in; nothing in the app accounted for the other 190. They are the system prompt, the template's
/// role markers and the conversation so far — re-read in full on every single turn, because the
/// model keeps nothing between them. That is the one fact about a chat model that everything else
/// about context, memory and speed follows from, and no amount of prose teaches it as well as
/// showing the bytes.
///
/// Apple's rules, applied: collapsed by default and captioned, so the chat stays a chat for
/// everyone who did not ask (C1, C8) — `DisclosureGroup` is the system's own control for exactly
/// this, and brings its chevron, its animation and its VoiceOver "expanded/collapsed" for free.
/// The text inside is monospaced, because it is a format and not a sentence, and selectable,
/// because someone who wants this will want to paste it somewhere.
private struct PromptDisclosure: View {
    let reply: Message
    let messages: [Message]
    let systemPrompt: String
    let isCustom: Bool
    let onEdit: () -> Void
    @State private var expanded = false

    var body: some View {
        // User messages have no prompt of their own, and a reply still being written has not
        // recorded one yet. Both are simply absent rather than shown as empty.
        if !reply.fromUser, let stats = reply.stats {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    // Rebuilt once. The three parts below all describe the same answer and asking
                    // twice would let them disagree.
                    let rebuilt = PromptTranscript.rebuild(reply: reply, in: messages,
                                                           systemPrompt: systemPrompt)
                    switch rebuilt {
                    case .success:
                        Text(Strings.string(.prompt_disclosure_body))
                            .font(.footnote)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    case .failure(let reason):
                        // Never an approximation. A page whose whole claim is "this is exactly what
                        // went in" has nothing to offer if it starts guessing (spine: C6).
                        Text(Strings.string(reason == .systemPromptChanged
                                            ? .prompt_disclosure_changed : .prompt_disclosure_unknown))
                            .font(.footnote)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    }

                    // OUTSIDE the switch, and above the text. It used to live in the success branch
                    // only, which produced a dead end nobody would have predicted: editing the
                    // instructions makes every existing reply fail the hash check, so every
                    // disclosure fell into the failure branch — and the way back to the editor
                    // disappeared from the chat the moment you used it once. The branch that says
                    // "the instructions changed" is exactly where someone wants to go and look.
                    Button(Strings.string(.prompt_edit_open), action: onEdit)
                        .accessibilityIdentifier(A11y.editInstructions)
                        .font(.footnote)
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.primary)
                        .frame(minHeight: Metrics.minTouchTarget)

                    if case .success(let text) = rebuilt {
                        Text(text)
                            .font(.caption.monospaced())
                            .foregroundStyle(Palette.onSurface)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 6) {
                    Text(Strings.string(.prompt_disclosure_label, Int(stats.promptTokens)))
                    // A conversation running on edited wording says so without being opened: the
                    // replies below are not the app's behaviour any more, they are yours.
                    if isCustom {
                        Text(Strings.string(.prompt_disclosure_custom))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Palette.primaryContainer, in: Capsule())
                            .foregroundStyle(Palette.onPrimaryContainer)
                    }
                }
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
                // COMBINED, then identified. Two things are going on here and both were bugs.
                //
                // The identifier is on the label rather than on the DisclosureGroup because an
                // identifier on the group is inherited by every descendant that has one of its
                // own, which silently renamed the Edit button inside it.
                //
                // And the label is combined because it gains a second child — the badge — the
                // moment a conversation runs on edited wording, and that changed what the row
                // exposed: addressable before the first edit, not afterwards. One label is also
                // what it is to a reader, who sees "what Arivu read, and whose words those are"
                // rather than two separate facts.
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(A11y.promptDisclosure)
            }
            .tint(Palette.onSurfaceVariant)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.surfaceVariant.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHint(Strings.string(.a11y_prompt_disclosure))
        }
    }
}

/// Tokens in, tokens out, and how fast the reply was written — under the reply it describes.
///
/// This used to live on the learning page as "your last reply", where it described a reply the
/// reader had navigated away from. Here it is attached to the thing it measures, which is the only
/// place a per-reply number is honest (spine: C5).
///
/// Apple's rules, applied: `.caption2` and a muted colour so it recedes below even the Copy row;
/// monospaced digits so the figures do not jitter as a conversation scrolls; and one combined
/// VoiceOver phrase, because "24" "143" "9.4" read out as three loose numbers is noise. Middle dots
/// rather than slashes or pipes — that is the separator iOS itself uses in a metadata line.
private struct StatsLine: View {
    let stats: ReplyStats

    var body: some View {
        Text(Strings.string(.chat_stats,
                            "\(stats.promptTokens)",
                            "\(stats.generatedTokens)",
                            Self.rate(stats.tokensPerSecond)))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Palette.onSurfaceVariant.opacity(0.7))
            .accessibilityLabel(Strings.string(.a11y_chat_stats,
                                               "\(stats.promptTokens)",
                                               "\(stats.generatedTokens)",
                                               Self.rate(stats.tokensPerSecond)))
    }

    /// One decimal below 10 tokens a second, none above it. A phone writing at 84.7 does not need
    /// the .7, and one at 4 does — the digit carries information exactly where the number is small.
    private static func rate(_ value: Double) -> String {
        String(format: value < 10 ? "%.1f" : "%.0f", value)
    }
}

private struct NoticeBar: View {
    let notice: Notice
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(notice.text)
                .font(.body)
                .foregroundStyle(Palette.onErrorContainer)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(Strings.string(.ok), action: onDismiss)
                .foregroundStyle(Palette.onErrorContainer)
                .frame(minHeight: Metrics.minTouchTarget)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.errorContainer)
        .accessibilityElement(children: .combine)
        .onAppear { UIAccessibility.post(notification: .announcement, argument: notice.text) }
    }
}
