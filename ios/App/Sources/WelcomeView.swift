// Shown once, before the first conversation (D-065).
//
// This is the screen C1 exists to refuse. "One tap and it works" has meant, from the first line of
// the Spine, that nothing stands between the icon and a place to type — no tour, no sign-in, no
// three-panel carousel about how revolutionary this is. Putting a page in front of the chat is
// exactly the thing every other app does and the reason most people never read any of it.
//
// It is here because the product is two things and only one of them was reachable. A person who
// opens Arivu and starts typing meets a small model that is bad at facts, with no idea that it is
// running on their phone, that it is small BECAUSE it runs on their phone, or that the learning
// page explaining all of that exists — because it was two taps inside About, where D-061 put it on
// the argument that wanting it should be an explicit act. That argument holds for the tenth
// session. It fails for the first, where nobody knows there is anything to want.
//
// So the compromise is exact, and it is what keeps C1 true:
//
//   ONCE      it never appears again. Not a setting, not a "show tips at startup" — a flag, set on
//             dismissal, the same shape as LoadedBeforeFlag.
//   ONE TAP   "Start using Arivu" is a single, obvious, primary action, and it lands in the chat.
//             That is the tap C1 promises; this screen spends it on a sentence rather than nothing.
//   NO GATE   nothing is asked for. No name, no account, no permission, no choice to get wrong.
//   IT STAYS  the learning page keeps its home under About, so this adds a door rather than moving
//             one, and the second tap here goes straight to it.
//
// What it must never become is a carousel. If a page is ever added to this, that is the signal the
// compromise has been lost.
//
// spine: C1, C5, C8

import ArivuChat
import ArivuCore
import SwiftUI

/// "The welcome has been seen." Mirrors `LoadedBeforeFlag` — one bool, owned by the app, with no
/// screen anywhere that can turn it back on. Resetting it is a developer affordance, not a setting.
public final class WelcomeSeenFlag: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "io.github.brettleehari.arivu.welcome.seen"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var value: Bool { defaults.bool(forKey: key) }
    public func set() { defaults.set(true, forKey: key) }
    public func reset() { defaults.removeObject(forKey: key) }
}

struct WelcomeView: View {
    @ObservedObject var session: ChatSession
    let onStart: () -> Void

    @State private var showingLearn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Strings.string(.welcome_title))
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Palette.onSurface)

                    Text(Strings.string(.welcome_body))
                        .font(.body)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Palette.surface)
            .safeAreaInset(edge: .bottom) {
                // Both actions pinned where a thumb is, primary first. Nothing here scrolls out of
                // reach, because a welcome whose dismissal is below the fold is a trap.
                VStack(spacing: 10) {
                    Button(Strings.string(.welcome_start), action: onStart)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier(A11y.welcomeStart)

                    Button(Strings.string(.welcome_later)) { showingLearn = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.primary)
                        .frame(minHeight: Metrics.minTouchTarget)
                        .accessibilityIdentifier(A11y.welcomeLearn)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(Palette.surface)
            }
            .navigationDestination(isPresented: $showingLearn) {
                LearnView(session: session)
            }
        }
    }
}
