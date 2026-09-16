// The report payload: what goes into the email, built with no network and no side effects.
//
// Play's AI-generated-content policy is what put Report on Android; the App Store's UGC rules ask
// for the same thing. Arivu has no way to send anything, so a report is a message handed to the
// user's own Mail app, which they check and send. Nothing leaves the phone from here.
//
// This file builds the text only. Handing it to `MFMailComposeViewController` (or the activity
// sheet, when no mail account exists) is the app's job — that part is UIKit and cannot be unit
// tested on this machine, so everything that CAN be tested lives here.
//
// spine: C3, C9

import Foundation

/// Why a reply is being reported. Order is the order of the rows in the sheet.
public enum ReportReason: String, CaseIterable, Sendable {
    case offensive, harmful, wrongDangerous, other

    public var labelKey: StringKey {
        switch self {
        case .offensive: return .report_reason_offensive
        case .harmful: return .report_reason_harmful
        case .wrongDangerous: return .report_reason_wrong_dangerous
        case .other: return .report_reason_other
        }
    }

    public var label: String { Strings.string(labelKey) }
}

/// A report about one specific reply. `nil` in `ReportPayload.build` means the general report
/// from About.
public struct ReplyReport: Equatable, Sendable {
    public let replyText: String
    public let reason: ReportReason
    public let note: String

    public init(replyText: String, reason: ReportReason, note: String) {
        self.replyText = replyText
        self.reason = reason
        self.note = note
    }
}

public struct ReportPayload: Equatable, Sendable {
    public let recipient: String
    public let subject: String
    public let body: String

    /// The text the activity sheet gets when the phone has no mail account: the address has to be
    /// inside the text, because a share sheet has no "to" field.
    public var shareText: String { Strings.string(.report_share_prefix, recipient, body) }

    public static func build(recipient: String, appVersion: String, report: ReplyReport? = nil) -> ReportPayload {
        let subject = Strings.string(.about_report_subject)
        let body: String
        if let report {
            let note = report.note.trimmingCharacters(in: .whitespacesAndNewlines)
            body = Strings.string(.report_reply_template,
                                  appVersion,
                                  report.reason.label,
                                  note.isEmpty ? Strings.string(.report_no_note) : note,
                                  report.replyText)
        } else {
            body = Strings.string(.about_report_template, appVersion)
        }
        return ReportPayload(recipient: recipient, subject: subject, body: body)
    }
}
