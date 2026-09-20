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
    /// What the reply cost, under the reply. Explained on the learning page, not here.
    case chat_stats, a11y_chat_stats
    /// The exact text handed to the model, between the question and the answer.
    case prompt_disclosure_label, prompt_disclosure_body, a11y_prompt_disclosure
    case prompt_disclosure_changed, prompt_disclosure_unknown, prompt_disclosure_custom
    /// Editing the wording this conversation runs with (D-064).
    case prompt_edit_open, prompt_edit_nav_title, prompt_edit_title, prompt_edit_body
    case prompt_edit_fixed_title, prompt_edit_fixed_body, prompt_edit_reset, prompt_edit_save
    case prompt_edit_chars
    case learn_prompt_title, learn_prompt_body, learn_prompt_state
    case learn_prompt_standard, learn_prompt_edited

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

    // How Arivu works — the learning page (leaves/design.md §8a)
    case about_learn_link, learn_title, learn_intro_body
    case learn_model_title, learn_model_body
    case learn_model_name, learn_model_quant, learn_model_quant_value
    case learn_model_size, learn_model_licence, learn_model_licence_value
    case learn_context_title, learn_context_body
    case learn_context_window, learn_context_reply, learn_context_reserve
    case learn_tokens_value, learn_tokens_approx
    case learn_memory_title, learn_memory_body
    case learn_memory_weights, learn_memory_working, learn_memory_peak
    case learn_memory_now, learn_memory_unmeasured
    case learn_speed_title, learn_speed_body
    case learn_speed_threads, learn_speed_backend, learn_speed_backend_value
    case learn_engine_core
    case learn_card_title, learn_card_body, learn_card_unloaded
    case learn_card_params, learn_card_layers, learn_card_heads, learn_card_kv_heads
    case learn_card_sharing, learn_card_head_dim, learn_card_embd, learn_card_vocab
    case learn_card_trained_ctx, learn_card_kv_cost, learn_card_arch
    case learn_billions, learn_sharing_value
    case learn_metal_title, learn_metal_body
    case learn_speed_measured_title, learn_speed_measured_body
    // The three parts of the line the chat prints under each reply, and what each one means.
    // `learn_speed_ttft`, `learn_speed_read`, `learn_speed_none`, `learn_tps` and `learn_ms` were
    // removed with the live figures: the catalogue is not allowed to carry a string nothing reaches.
    case learn_speed_tokens_in, learn_speed_tokens_in_body
    case learn_speed_tokens_out, learn_speed_tokens_out_body
    case learn_speed_write, learn_speed_write_body
    case about_build

    // Conversations (D-011)
    case conversations_title, conversations_new, conversations_empty, conversations_untitled
    case conversations_delete, conversations_count_one, conversations_count_many
    case conversations_subtitle
    case a11y_conversations
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
