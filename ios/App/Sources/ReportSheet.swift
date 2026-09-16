// Reporting a reply, with no network.
//
// Play's AI-generated-content policy is what put this on Android; the App Store's UGC rules ask for
// the same. Arivu cannot send anything, so the report is a message written for the user, which they
// read and send themselves. On iOS the composer appears *inside* Arivu, which is why the copy says
// "The message opens here, already written" rather than Android's "your email app opens"
// (leaves/design/copy.md, `report_sheet_privacy`).
//
// Falls back to the activity sheet when the phone has no mail account, with the address written
// into the text, because a share sheet has no "to" field.
//
// UNVERIFIED: not compiled.
//
// spine: C3, C9

import ArivuCore
import MessageUI
import SwiftUI
import UIKit

struct ReportSheet: View {
    let replyText: String
    let onReported: () -> Void
    let onDismiss: () -> Void

    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var handoff: ReportPresentation?

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    Text(Strings.string(.report_sheet_body))
                        .font(.footnote)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }

                // A grouped single-select list, not a chip row: it is the iOS idiom and it survives
                // AX5 text where a chip row cannot (leaves/design.md §2).
                SwiftUI.Section(Strings.string(.report_reason_label)) {
                    ForEach(ReportReason.allCases, id: \.self) { candidate in
                        Button {
                            reason = candidate
                        } label: {
                            HStack {
                                Text(candidate.label).foregroundStyle(Palette.onSurface)
                                Spacer()
                                if reason == candidate {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.primary)
                                }
                            }
                            .frame(minHeight: Metrics.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(reason == candidate ? [.isButton, .isSelected] : .isButton)
                    }
                }

                SwiftUI.Section(Strings.string(.report_note_label)) {
                    TextField("", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.sentences)
                }

                SwiftUI.Section {
                    Text(Strings.string(.report_sheet_privacy))
                        .font(.footnote)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            .navigationTitle(Strings.string(.report_sheet_title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.string(.cancel), action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.string(.report_send)) {
                        guard let reason else { return }
                        // Marked on the phone before the hand-off: the user asked, whatever Mail does next.
                        onReported()
                        handoff = ReportPresentation(payload: ReportPayload.build(
                            recipient: AppInfo.reportEmail,
                            appVersion: AppInfo.version,
                            report: ReplyReport(replyText: replyText, reason: reason, note: note)))
                    }
                    .disabled(reason == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $handoff) { presentation in
            ReportHandoff(payload: presentation.payload) {
                handoff = nil
                onDismiss()
            }
        }
    }
}

/// The mail composer, or the activity sheet when there is no mail account. Nothing is sent by Arivu
/// in either case; the user presses send in the app that can.
struct ReportHandoff: View {
    let payload: ReportPayload
    let onFinish: () -> Void

    var body: some View {
        if MFMailComposeViewController.canSendMail() {
            MailComposer(payload: payload, onFinish: onFinish)
                .ignoresSafeArea()
        } else {
            ActivitySheet(text: payload.shareText, subject: payload.subject, onFinish: onFinish)
                .ignoresSafeArea()
        }
    }
}

private struct MailComposer: UIViewControllerRepresentable {
    let payload: ReportPayload
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([payload.recipient])
        controller.setSubject(payload.subject)
        controller.setMessageBody(payload.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            onFinish()
        }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let text: String
    let subject: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        controller.setValue(subject, forKey: "subject")
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
