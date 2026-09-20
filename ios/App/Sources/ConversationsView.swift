// The conversation list (D-011).
//
// Not a drawer. A hamburger that slides a panel over the screen is a Material idiom, and iOS has its
// own answer for "a list of things, and the thing you are looking at": NavigationSplitView. It is
// one control that is a sidebar on iPad and a push on iPhone, it brings the system's own back
// gesture, and it costs nothing to adopt because the chat is already inside a NavigationStack.
//
// The one adjustment that matters: `preferredCompactColumn = .detail`. Left alone, a split view on
// iPhone opens on the list, and Arivu would greet a new user with an empty table instead of a place
// to type. C1 says one tap and it works, so the app opens into the chat and the list is behind the
// back button — present, not in the way.
//
// Swipe-to-delete rather than an Edit button: it is the gesture iOS users already have for a list
// row, it needs no chrome, and the destructive role gets the system's colour and confirmation
// behaviour without Arivu choosing either.
//
// spine: C1, C3, C8

import ArivuChat
import ArivuCore
import SwiftUI

struct ConversationsView: View {
    @ObservedObject var session: ChatSession

    var body: some View {
        List(selection: Binding(get: { session.currentID },
                                set: { if let id = $0 { session.open(id) } })) {
            if session.conversations.isEmpty {
                Text(Strings.string(.conversations_empty))
                    .font(.footnote)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            ForEach(session.conversations) { conversation in
                row(conversation).tag(conversation.id)
            }
            .onDelete { offsets in
                for index in offsets { session.delete(session.conversations[index].id) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .navigationTitle(Strings.string(.conversations_title))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(Strings.string(.conversations_new)) { session.newConversation() }
                    .disabled(session.messages.isEmpty)
            }
        }
    }

    private func row(_ conversation: ConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title.isEmpty
                 ? Strings.string(.conversations_untitled) : conversation.title)
                .font(.body)
                .foregroundStyle(Palette.onSurface)
                .lineLimit(1)
            // Relative dates ("Yesterday", "Last week") rather than a timestamp: what a person needs
            // from this row is which conversation, not when precisely. The system formats it in the
            // reader's own language and calendar, which hand-built strings would not.
            Text(Date(timeIntervalSince1970: TimeInterval(conversation.updatedAt) / 1000),
                 format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
