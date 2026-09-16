// The app: a launch screen, then a chat. Nothing in between.
//
// There is no onboarding, no notification prompt, no tracking prompt and no rating prompt
// (leaves/design.md §14, request 5). The first screen after the launch image is either the empty
// chat or, on a phone that cannot run the model, the screen that says so.
//
// Nothing here touches the model. The engine is created on the first send, never at app start
// (leaves/BRIEF.md "Lifecycle"), which is why a cold launch costs nothing and C1 holds.
//
// UNVERIFIED: no part of this file has been compiled. There is no iOS SDK on the machine it was
// written on, so everything UIKit- or SwiftUI-shaped is unbuilt. See leaves/engineering-ios.md.
//
// spine: C1, C2, C6, C10

import ArivuChat
import ArivuCore
import ArivuEngine
import SwiftUI
import UIKit

@main
struct ArivuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// Evaluated once, before anything is loaded, and cached after the first pass.
    private let gate: GateResult = CompatibilityGate.check(appVersion: AppInfo.version)

    @StateObject private var session: ChatSession = {
        let controller = InferenceController(modelSource: BundleModelSource())
        let repository = ChatRepository(url: (try? ChatRepository.defaultURL())
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Policy.conversationFileName))
        return ChatSession(repository: repository, controller: controller)
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                switch gate {
                case .pass:
                    ChatView(session: session)
                case .fail(let failure):
                    // spine: C6, R8 — it explains and stops. There is no "continue anyway", and on
                    // iOS there is no button at all: an app cannot delete itself.
                    IncompatibleView(failure: failure)
                }
            }
            .tint(Palette.primary)
            .background(Palette.surface)
            .task {
                guard case .pass = gate else { return }
                await session.loadHistory()
                appDelegate.session = session
            }
            .onChange(of: scenePhase) { _, phase in
                guard case .pass = gate else { return }
                switch phase {
                case .active:
                    session.onForeground()
                case .background:
                    // The context goes now. Jetsam will not ask first.
                    session.onBackground()
                case .inactive:
                    // Deliberately nothing: `inactive` is the transient state of a notification
                    // shade pull or an app-switcher peek, and freeing the context there would make
                    // every glance cost a reload.
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

/// UIKit still owns two things SwiftUI does not surface: the memory warning, and the background
/// assertion that decides whether a reply can finish after the user leaves.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set once the session exists. Weak would be wrong — the App struct owns it and outlives us.
    var session: ChatSession?

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // A courtesy the system may never extend; nothing in the lifecycle rules depends on it
        // arriving (see InferenceController). While a reply is being written this stops it cleanly
        // and labels it (leaves/design.md §7).
        Task { @MainActor in session?.onMemoryWarning() }
    }

    /// iOS gives roughly 30 seconds here, against Android's ~3 minutes of foreground service, so a
    /// long reply will outlive it. The design decision (leaves/design.md §5.1): stop cleanly and say
    /// so. Never truncate silently, never resume by surprise, and never post a notification — that
    /// would need a permission prompt this product refuses to show (D-041).
    func applicationDidEnterBackground(_ application: UIApplication) {
        endBackgroundTask()
        backgroundTask = application.beginBackgroundTask(withName: "arivu.finish-reply") { [weak self] in
            // The expiration handler. Same cancel path as the Stop button, so the partial reply is
            // saved by the same throttled save and labelled `stopped_backgrounded`.
            Task { @MainActor in self?.session?.onBackgroundTimeExpiring() }
            self?.endBackgroundTask()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// The address a report is sent to. It lives in Info.plist (set from `ARIVU_REPORT_EMAIL` in
    /// project.yml) rather than in source, so the release check can reject the placeholder the way
    /// tools/release_check.sh does on Android (D-010).
    static var reportEmail: String {
        Bundle.main.object(forInfoDictionaryKey: "ARIVUReportEmail") as? String ?? "report@example.invalid"
    }
}
