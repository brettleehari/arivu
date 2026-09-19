// Typed access to the copy catalogue.
//
// Design's rule (leaves/design.md §14, request 1): take every string by key; never author a
// user-facing string in Swift. `StringKey` is that rule made into a compiler error — a screen cannot
// render a sentence that is not in the catalogue, and a test walks every case to prove each one
// resolves (StringsTests.swift).
//
// The catalogue is a plain `.strings` file, which is an old-style property list, so it is parsed
// here rather than gone through `NSLocalizedString`. Two reasons, both practical:
//   - it works identically under SwiftPM, under Xcode, and under the macOS verification harness,
//     which has no resource bundle at all;
//   - a missing key is a test failure with the key in it, not a silent fallback to the key text.
// Adding a language stays a data change: drop `fr.lproj/Localizable.strings` in beside `en.lproj`.
//
// spine: C5, C11

import Foundation

public enum StringKey: String, CaseIterable, Sendable {
    // Chat
    case app_name, input_hint, send, stop, copy, copied, ok, about, cancel, report, reported
    case empty_title, empty_body, empty_examples_label, empty_example_1, empty_example_2, empty_example_3
    case state_starting, state_starting_first_run, state_starting_long, state_reading
    case context_divider
    case stopped_by_user, stopped_context_full, stopped_max_tokens, stopped_error
    case stopped_low_memory, stopped_backgrounded
    case message_too_long, load_failed, load_failed_low_memory

    // VoiceOver
    case a11y_from_user, a11y_from_arivu, a11y_writing, a11y_reply_done
    case a11y_copy_message, a11y_report_reply, a11y_stop, a11y_expanded, a11y_collapsed

    // About
    case about_title, about_what_title, about_what_body, about_good_title, about_good_body
    case about_bad_title, about_bad_body, about_private_title, about_private_body
    case about_report_title, about_report_body, about_report_button, about_report_subject
    case about_report_template, report_reply_template, report_no_note, report_share_prefix

    // Report sheet
    case report_sheet_title, report_sheet_body, report_reason_label
    case report_reason_offensive, report_reason_harmful, report_reason_wrong_dangerous, report_reason_other
    case report_note_label, report_sheet_privacy, report_send

    // Privacy policy
    case about_privacy_policy, privacy_intro
    case privacy_short_title, privacy_short_body
    case privacy_internet_title, privacy_internet_body
    case privacy_stored_title, privacy_stored_body
    case privacy_collect_title, privacy_collect_body
    case privacy_report_title, privacy_report_body
    case privacy_copy_title, privacy_copy_body
    case privacy_play_title, privacy_play_body
    case privacy_children_title, privacy_children_body
    case privacy_choices_title, privacy_choices_body
    case privacy_changes_title, privacy_changes_body
    case privacy_contact_title, privacy_contact_body

    // Licences and version
    case about_licenses_title, about_license_entry, about_version

    // The gate
    case incompatible_title, incompatible_body, incompatible_remove_ios
    case gate_total_ram, gate_storage
}

public enum Strings {
    /// The whole catalogue, in the best available language.
    public static var table: [String: String] { Catalogue.shared.table }

    public static func string(_ key: StringKey) -> String {
        guard let value = Catalogue.shared.table[key.rawValue] else {
            assertionFailure("copy catalogue has no key \(key.rawValue)")
            return key.rawValue
        }
        return value
    }

    /// Positional formatting (`%1$@`, `%1$ld`). Sentences are never built by joining strings.
    public static func string(_ key: StringKey, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }

    /// Where the catalogue was found. Empty means "compiled-in fallback was used", which is a bug
    /// everywhere except a stripped-down tool; the map is exposed so a test can say so.
    public static var catalogueSource: String { Catalogue.shared.source }
}

/// Convenience so call sites read as `S(.send)` / `S(.about_version, version)`.
public func S(_ key: StringKey) -> String { Strings.string(key) }
public func S(_ key: StringKey, _ arguments: CVarArg...) -> String {
    String(format: Strings.string(key), locale: Locale.current, arguments: arguments)
}

final class Catalogue: @unchecked Sendable {
    static let shared = Catalogue()

    let table: [String: String]
    let source: String

    private init() {
        for (url, how) in Catalogue.candidateURLs() {
            if let parsed = Catalogue.parse(url) {
                table = parsed
                source = how
                return
            }
        }
        table = [:]
        source = ""
    }

    /// In order: an explicit override (the macOS verification harness and tests), the SwiftPM
    /// resource bundle, the app bundle, then any loaded bundle that carries the catalogue.
    private static func candidateURLs() -> [(URL, String)] {
        var roots: [(Bundle?, String, String)] = []
        if let dir = ProcessInfo.processInfo.environment["ARIVU_STRINGS_DIR"] {
            roots.append((nil, dir, "ARIVU_STRINGS_DIR"))
        }
        #if SWIFT_PACKAGE
        roots.append((Bundle.module, Bundle.module.bundlePath, "Bundle.module"))
        #endif
        roots.append((Bundle.main, Bundle.main.bundlePath, "Bundle.main"))
        for b in Bundle.allBundles where b !== Bundle.main {
            roots.append((b, b.bundlePath, "Bundle(\(b.bundleIdentifier ?? b.bundlePath))"))
        }

        var out: [(URL, String)] = []
        for (bundle, path, how) in roots {
            // Ask the Bundle first, where there is one. A bundle's internal layout is not the same
            // on every platform: iOS puts resources at the top level, macOS nests them under
            // Contents/Resources. Hand-building "<bundle>/en.lproj/Localizable.strings" therefore
            // finds the catalogue on a device and misses it under `swift test` on a Mac — which is
            // the one configuration this package exists to keep working, and it was failing with
            // "copy catalogue has no key message_too_long" the first time the suite ever ran here.
            if let bundle {
                for language in preferredLanguages() {
                    if let url = bundle.url(forResource: "Localizable", withExtension: "strings",
                                            subdirectory: nil, localization: language) {
                        out.append((url, how))
                    }
                }
                if let url = bundle.url(forResource: "Localizable", withExtension: "strings") {
                    out.append((url, how))
                }
            }
            // Then the hand-built paths, which are what a plain directory (ARIVU_STRINGS_DIR, the
            // macOS verification harness) needs, and a useful fallback for any layout the Bundle
            // API declines to resolve.
            let base = URL(fileURLWithPath: path, isDirectory: true)
            for language in preferredLanguages() {
                out.append((base.appendingPathComponent("\(language).lproj/Localizable.strings"), how))
                out.append((base.appendingPathComponent("Contents/Resources/\(language).lproj/Localizable.strings"), how))
            }
            // A flat layout (no .lproj) is what a String Catalog compiles down to in some configurations.
            out.append((base.appendingPathComponent("Localizable.strings"), how))
            out.append((base.appendingPathComponent("Contents/Resources/Localizable.strings"), how))
        }
        return out
    }

    /// The user's languages, then English. UI language itself is D-014; this is only the lookup order.
    private static func preferredLanguages() -> [String] {
        var langs = Locale.preferredLanguages.map { String($0.prefix(2)) }
        langs.append("en")
        var seen = Set<String>()
        return langs.filter { seen.insert($0).inserted }
    }

    private static func parse(_ url: URL) -> [String: String]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: String],
              !dict.isEmpty
        else { return nil }
        return dict
    }
}
