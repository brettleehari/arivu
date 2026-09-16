// The copy catalogue, the report payload, and the promise that there is nothing to configure.
//
// Design's rule is "take every string by key; author none in Swift" (leaves/design.md §14). These
// tests are what makes that rule enforceable: every key resolves, the honesty statements are the
// exact words Design wrote, the iOS divergences are the ones the catalogue sanctions and no others,
// and nothing in Policy is a runtime setting.
//
// spine: C5, C8, C9

import Foundation
import Testing
@testable import ArivuCore

@Suite("Copy catalogue")
struct StringsTests {
    @Test("the catalogue was found at all")
    func catalogueLoads() {
        #expect(!Strings.catalogueSource.isEmpty,
                "no Localizable.strings was found; set ARIVU_STRINGS_DIR or ship the resource bundle")
        #expect(!Strings.table.isEmpty)
    }

    @Test("every key the app can ask for resolves to real text")
    func everyKeyResolves() {
        for key in StringKey.allCases {
            let value = Strings.table[key.rawValue]
            #expect(value != nil, "missing key: \(key.rawValue)")
            #expect(value?.isEmpty == false, "empty key: \(key.rawValue)")
        }
    }

    @Test("the catalogue carries nothing the app cannot reach")
    func noOrphans() {
        let known = Set(StringKey.allCases.map(\.rawValue))
        let orphans = Set(Strings.table.keys).subtracting(known)
        #expect(orphans.isEmpty, "catalogue keys with no StringKey case: \(orphans.sorted())")
    }

    /// The honesty statements are identical on both platforms, word for word
    /// (leaves/design/copy.md, `about_bad_body` and `empty_body`).
    @Test("the honesty statements are Design's exact words")
    func honestyStatements() {
        #expect(Strings.string(.about_bad_body)
                == "Facts, news, dates, numbers, maths, and medical or legal answers. It can sound sure and still be wrong.")
        #expect(Strings.string(.empty_title) == "Works with no internet")
        #expect(Strings.string(.empty_body).contains("It is not good at facts, news or numbers, so check anything important."))
        #expect(Strings.string(.about_good_body)
                == "Rewriting, shortening, explaining, summarising and drafting text you give it.")
    }

    /// Every stop label is shared, word for word (leaves/design.md §2).
    @Test("stop labels are the shared text")
    func stopLabels() {
        #expect(Strings.string(.stopped_by_user) == "Stopped")
        #expect(Strings.string(.stopped_context_full).hasPrefix("Cut off:"))
        #expect(Strings.string(.stopped_low_memory)
                == "Stopped: your phone ran low on memory. Close other apps, then send “continue” to get the rest.")
        #expect(Strings.string(.stopped_backgrounded)
                == "Stopped: Arivu cannot keep writing while you are in another app. Send “continue” to get the rest.")
        #expect(Strings.string(.context_divider) == "Arivu can no longer see the messages above this line")
    }

    /// D-038: the iOS privacy claim must be the weaker, TRUE one. Copying the Android sentence
    /// across would be a false claim, so it is a test, not a review note.
    @Test("the iOS privacy claim never says Android's sentence")
    func privacyClaimIsTheIOSOne() {
        let claim = Strings.string(.about_private_body)
        #expect(!claim.contains("no permission to use the internet"),
                "the Android claim has been copied onto iOS; there is no permission to withhold here")
        #expect(claim.contains("no code that can reach the internet"))
        #expect(Strings.string(.privacy_internet_title) == "Arivu has no way to reach the internet")
    }

    /// The composer opens inside Arivu on iOS, so the Android wording would describe something the
    /// user never sees (leaves/design/copy.md, `report_sheet_privacy` and `report_send`).
    @Test("the report copy describes what iOS actually does")
    func reportCopy() {
        #expect(Strings.string(.report_send) == "Write the email")
        #expect(Strings.string(.report_sheet_privacy).contains("The message opens here, already written"))
        #expect(Strings.string(.load_failed).contains("app switcher"))
        #expect(Strings.string(.incompatible_remove_ios)
                == "To remove Arivu: touch and hold its icon on the Home Screen, then choose Delete App.")
    }

    /// Keys the catalogue marks `platforms: [android]`. Shipping them here would mean showing a
    /// user an uninstall button that cannot exist, or a notification the app never posts.
    @Test("android-only keys are absent")
    func androidOnlyKeysAbsent() {
        for key in ["incompatible_uninstall", "gate_abi", "gate_low_ram",
                    "notification_channel", "notification_writing", "back"] {
            #expect(Strings.table[key] == nil, "android-only key present on iOS: \(key)")
        }
    }

    @Test("placeholders are in iOS spelling and in the right number")
    func placeholders() {
        #expect(Strings.string(.message_too_long).contains("%1$ld"))
        #expect(Strings.string(.a11y_from_user).contains("%1$@"))
        for n in 1...4 {
            #expect(Strings.string(.report_reply_template).contains("%\(n)$@"),
                    "report_reply_template is missing %\(n)$@")
        }
        #expect(Strings.string(.about_report_template).contains("%1$@"))
        #expect(Strings.string(.report_share_prefix).contains("%1$@"))
        #expect(Strings.string(.report_share_prefix).contains("%2$@"))
    }

    @Test("formatting a string fills the placeholders in the right order")
    func formatting() {
        #expect(Strings.string(.a11y_from_arivu, "hello") == "Arivu wrote: hello")
        #expect(Strings.string(.message_too_long, 82)
                == "This message is too long for Arivu to read at once. Try sending a part about 82% as long.")
        #expect(Strings.string(.gate_total_ram, "2.0 GB", "3.5 GB")
                == "This phone has 2.0 GB of memory. Arivu needs at least 3.5 GB.")
    }

    /// British spelling, consistently (leaves/design/copy.md rule 4).
    @Test("no American spellings crept in")
    func britishSpelling() {
        let american = ["summarize", "summarizing", "license ", "licenses", "color", "behavior", "apologize"]
        for (key, value) in Strings.table {
            let lower = value.lowercased()
            for word in american {
                #expect(!lower.contains(word), "\(key) contains an American spelling: \(word)")
            }
        }
    }

    /// The product's core claim, checked against its own copy: nothing in the catalogue offers a
    /// setting, a sign-in, a download or a model choice (C1, C8, R3, R5).
    @Test("the copy offers nothing to configure, download or sign in to")
    func nothingToConfigure() {
        let forbidden = ["sign in", "sign up", "log in", "create an account", "download the model",
                         "choose a model", "settings screen", "api key", "subscribe"]
        for (key, value) in Strings.table {
            let lower = value.lowercased()
            for phrase in forbidden {
                #expect(!lower.contains(phrase), "\(key) offers something the product refuses: \(phrase)")
            }
        }
    }
}

@Suite("Report payload")
struct ReportTests {
    @Test("a per-reply report carries the reply, the reason, the note and the version")
    func perReplyReport() {
        let payload = ReportPayload.build(
            recipient: "report@example.invalid",
            appVersion: "1.2.3",
            report: ReplyReport(replyText: "the reply", reason: .wrongDangerous, note: "  it is wrong  "))
        #expect(payload.recipient == "report@example.invalid")
        #expect(payload.subject == "Arivu: report of harmful output")
        #expect(payload.body.contains("Reason: Wrong in a dangerous way"))
        #expect(payload.body.contains("My note: it is wrong"))
        #expect(payload.body.contains("The reply Arivu wrote:\nthe reply"))
        #expect(payload.body.contains("App version: 1.2.3"))
    }

    @Test("an empty note says so rather than leaving a blank line")
    func emptyNote() {
        let payload = ReportPayload.build(recipient: "r@e.invalid", appVersion: "1.0",
                                          report: ReplyReport(replyText: "x", reason: .other, note: "   "))
        #expect(payload.body.contains("My note: (none)"))
    }

    @Test("the general report from About is a blank form with the version in it")
    func generalReport() {
        let payload = ReportPayload.build(recipient: "r@e.invalid", appVersion: "9.9")
        #expect(payload.body.contains("Paste the reply here:"))
        #expect(payload.body.contains("App version: 9.9"))
        #expect(!payload.body.contains("Reason:"))
    }

    /// The activity sheet has no "to" field, so the address has to be in the text.
    @Test("the share fallback carries the address in the text")
    func shareFallback() {
        let payload = ReportPayload.build(recipient: "report@example.invalid", appVersion: "1.0")
        #expect(payload.shareText.hasPrefix("To: report@example.invalid"))
        #expect(payload.shareText.contains(payload.body))
    }

    @Test("the four reasons are the four Design wrote, in order")
    func reasons() {
        #expect(ReportReason.allCases.map(\.label)
                == ["Offensive", "Harmful", "Wrong in a dangerous way", "Something else"])
    }

    /// spine: C3 — nothing on this path can reach the network. The payload is text and nothing else.
    @Test("the payload is text, with no URL and no request in sight")
    func noNetwork() {
        let payload = ReportPayload.build(recipient: "r@e.invalid", appVersion: "1.0")
        #expect(!payload.body.lowercased().contains("http"))
        #expect(!payload.subject.lowercased().contains("http"))
    }
}

@Suite("Policy — every setting is a decision already made (C8)")
struct PolicyTests {
    /// The same values as android/app/.../Policy.kt. A difference here would be a different product
    /// on the two platforms, which C11 refuses.
    @Test("the numbers are Android's numbers")
    func numbersMatchAndroid() {
        #expect(Policy.nCtx == 2048)
        #expect(Policy.nBatch == 512)
        #expect(Policy.kvQ8_0)
        #expect(Policy.replyReserveTokens == 512)
        #expect(Policy.maxReplyTokens == 768)
        #expect(Policy.temperature == 0.7)
        #expect(Policy.topK == 20)
        #expect(Policy.topP == 0.8)
        #expect(Policy.contextIdleSeconds == 30)
        #expect(Policy.repackWeights == false)
        #expect(Policy.minTotalRamBytes == 3_543_348_019)
        #expect(Policy.minFreeStorageBytes == 268_435_456)
    }

    /// spine: C5 — the model is told what it is bad at, in the same words the user is told.
    @Test("the system prompt is Android's, byte for byte")
    func systemPromptMatchesAndroid() {
        #expect(Policy.systemPrompt.hasPrefix(
            "You are Arivu, an offline writing and comprehension assistant running on the user's phone. "))
        #expect(Policy.systemPrompt.contains("You have no internet access and your memory of facts is unreliable."))
        #expect(Policy.systemPrompt.contains("Refuse sexual content involving minors"))
        #expect(Policy.systemPrompt.contains("If someone mentions self-harm"))
        // 659 characters, the length of Policy.SYSTEM_PROMPT in android/app/.../Policy.kt, compared
        // string-by-string when this port was written. A change to either is a change to the product.
        #expect(Policy.systemPrompt.count == 659, "the system prompt changed; check it against Policy.kt")
    }

    /// D-013 is Android-only complexity: an iOS bundle is a directory, so there is no `.so` suffix,
    /// no alignment rule and no offset arithmetic.
    @Test("the model is a plain bundle file")
    func modelFileName() {
        #expect(Policy.modelFileName == "qwen3-0.6b-q4_k_m.gguf")
        #expect(!Policy.modelFileName.hasSuffix(".so"))
    }

    @Test("the conversation file has the same name as Android's, so a future export lines up")
    func conversationFileName() {
        #expect(Policy.conversationFileName == "conversation.json")
    }
}
