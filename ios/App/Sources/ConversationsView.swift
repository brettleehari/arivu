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
// DELETING. There are three ways in, and that is deliberate rather than indecisive. iOS teaches
// deletion by gesture, and the gesture is genuinely the fastest way — but a gesture is invisible,
// and a person who does not already know it is there has no way to discover it. So:
//
//   swipe         the system gesture, for the people who have it in their hands already.
//   long press    a context menu, which is how iOS lets you ask a row what it can do.
//   Edit          a visible button in the toolbar. This is the one that matters. It is the only
//                 affordance a person can SEE, and Mail, Notes and Files all put it in the same
//                 place, so it is already familiar even to someone meeting this screen first.
//
// All three call the same `session.delete(_:)`. Nothing here confirms first: the destructive role
// gives the system's red, iOS does not confirm a single-row delete anywhere else, and a confirmation
// sheet on every delete is the kind of chrome C8 exists to refuse. What protects the user is that
// the button says Delete and is red, not that Arivu asks twice.
//
// spine: C1, C3, C8, C10

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
                row(conversation)
                    .tag(conversation.id)
                    // Long press. `.destructive` is what turns the label red and puts it last in
                    // the menu — Arivu picks neither colour nor position.
                    .contextMenu {
                        Button(Strings.string(.conversations_delete), role: .destructive) {
                            session.delete(conversation.id)
                        }
                    }
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
            // The visible one. `EditButton` is the system's own: it says Edit, becomes Done, and
            // drives the same `.onDelete` the swipe does, so there is one delete path and not two.
            ToolbarItem(placement: .topBarLeading) {
                EditButton().disabled(session.conversations.isEmpty)
            }
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
            // How much is in it, and how long ago. Relative dates ("Yesterday", "Last week") rather
            // than a timestamp: what a person needs from this row is which conversation, not when
            // precisely. `.formatted` keeps the system doing it, in the reader's own language and
            // calendar, which a hand-built string would not.
            Text(Strings.string(.conversations_subtitle,
                                Strings.string(conversation.messageCount == 1
                                               ? .conversations_count_one : .conversations_count_many,
                                               conversation.messageCount),
                                Date(timeIntervalSince1970: TimeInterval(conversation.updatedAt) / 1000)
                                    .formatted(.relative(presentation: .named))))
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
