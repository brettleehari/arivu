// About: what Arivu is, what it is bad at, how it is private, how to report a reply, and every
// licence it owes. Sections in the order leaves/design.md §8 fixes, identical to Android's.
//
// The privacy policy is readable with no network, because a URL alone would need the network the
// product does not have. The licences list is generated from the build (tools/ios/sync_licences.sh),
// not copied from Android, because the two apps link different things.
//
// UNVERIFIED: not compiled.
//
// spine: C3, C4, C5, C9

import ArivuCore
import SwiftUI

struct AboutView: View {
    @State private var openRow: String?
    @State private var reportPresentation: ReportPresentation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AboutSection(title: .about_what_title, text: .about_what_body)
                AboutSection(title: .about_good_title, text: .about_good_body)
                AboutSection(title: .about_bad_title, text: .about_bad_body)
                AboutSection(title: .about_private_title, text: .about_private_body)

                ExpandableRow(label: Strings.string(.about_privacy_policy),
                              isOpen: openRow == Self.privacyKey) {
                    openRow = openRow == Self.privacyKey ? nil : Self.privacyKey
                }
                if openRow == Self.privacyKey { PrivacyPolicy() }

                AboutSection(title: .about_report_title, text: .about_report_body)
                Button(Strings.string(.about_report_button)) {
                    reportPresentation = ReportPresentation(payload: ReportPayload.build(
                        recipient: AppInfo.reportEmail, appVersion: AppInfo.version))
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: Metrics.minTouchTarget)

                Divider()
                Text(Strings.string(.about_licenses_title))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Licences.all, id: \.name) { entry in
                    ExpandableRow(label: Strings.string(.about_license_entry, entry.name, entry.spdx),
                                  isOpen: openRow == entry.name) {
                        openRow = openRow == entry.name ? nil : entry.name
                    }
                    if openRow == entry.name {
                        Text(Licences.text(of: entry))
                            .font(.footnote.monospaced())
                            .foregroundStyle(Palette.onSurfaceVariant)
                            .textSelection(.enabled)
                    }
                }

                Text(Strings.string(.about_version, AppInfo.version))
                    .font(.caption)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.surface)
        .navigationTitle(Strings.string(.about_title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reportPresentation) { presentation in
            ReportHandoff(payload: presentation.payload) { reportPresentation = nil }
        }
    }

    private static let privacyKey = "privacy"
}

struct ReportPresentation: Identifiable {
    let id = UUID()
    let payload: ReportPayload
}

/// A heading and a paragraph, both by key. Named `AboutSection` rather than `Section` because a
/// `body` stored property would collide with the `View` requirement of the same name.
private struct AboutSection: View {
    let title: StringKey
    let text: StringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Strings.string(title))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(Strings.string(text))
                .font(.body)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
    }
}

/// A full-width row with an open/closed state a screen reader can hear. A word and a marker, never
/// a bare chevron (leaves/design.md §8).
struct ExpandableRow: View {
    let label: String
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(label)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isOpen ? "−" : "+")
                    .font(.body.monospaced())
            }
            .frame(minHeight: Metrics.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.primary)
        .accessibilityValue(Strings.string(isOpen ? .a11y_expanded : .a11y_collapsed))
    }
}

/// The whole policy, offline, as headed sections. Text owned by Compliance (D-022); the iOS
/// divergences are the ones leaves/design/copy.md §6 sanctions.
private struct PrivacyPolicy: View {
    private static let sections: [(StringKey, StringKey)] = [
        (.privacy_short_title, .privacy_short_body),
        (.privacy_internet_title, .privacy_internet_body),
        (.privacy_stored_title, .privacy_stored_body),
        (.privacy_collect_title, .privacy_collect_body),
        (.privacy_report_title, .privacy_report_body),
        (.privacy_copy_title, .privacy_copy_body),
        (.privacy_play_title, .privacy_play_body),
        (.privacy_children_title, .privacy_children_body),
        (.privacy_choices_title, .privacy_choices_body),
        (.privacy_changes_title, .privacy_changes_body),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.string(.privacy_intro, AppInfo.version))
                .font(.footnote)
                .foregroundStyle(Palette.onSurfaceVariant)
            ForEach(Self.sections, id: \.0) { title, paragraph in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Strings.string(title))
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(Strings.string(paragraph)).font(.footnote)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(Strings.string(.privacy_contact_title))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(Strings.string(.privacy_contact_body, AppInfo.reportEmail))
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
        .foregroundStyle(Palette.onSurfaceVariant)
    }
}

/// spine: C4 — every shipped component, including the model weights. The list is generated from the
/// build by tools/ios/sync_licences.sh; "Notices (read first)" sits on top.
enum Licences {
    struct Entry { let name: String; let spdx: String; let file: String }

    static let all: [Entry] = {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "txt", subdirectory: "licenses"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { return nil }
            return Entry(name: String(parts[0]), spdx: String(parts[1]), file: String(parts[2]))
        }
    }()

    static func text(of entry: Entry) -> String {
        guard let url = Bundle.main.url(forResource: entry.file.replacingOccurrences(of: ".txt", with: ""),
                                        withExtension: "txt", subdirectory: "licenses"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}
