---
spine_version: 0.2
leaf: compliance
checked_on: 2026-09-15
platform: ios
artifact: none yet — /ios is being built in this session (ios/ArivuKit/Sources/ArivuCore/*.swift).
          There is no Xcode on this machine, so nothing below was checked against a built .app;
          `tools/ios_release_check.sh` is written to check it when there is one.
sources_checked: App Review Guidelines (developer.apple.com, "Last Updated: June 8, 2026", full page
          text fetched and grepped), developer.apple.com/tutorials/data/documentation JSON for the
          BundleResources privacy-manifest and entitlement pages, App Store Connect Help.
---

# Apple App Store submission checklist — Compliance Leaf

The App Store sibling of `play-policy-checklist.md`. Same legend:
**met** · **gap** (work to do before release) · **needs Hari** (a human call or App Store Connect action).
**BLOCKS** marks an item that, left as is, stops the app reaching the store or is likely to fail review.
Source tags: **[V]** verified against the linked official Apple page on 2026-09-15 ·
**[V: absent]** the official page was fetched in full and demonstrably does *not* say the thing ·
**[U]** unverified (an interpretation, a community reading, or something only App Store Connect can show).

Cross-store differences are collected in `play-policy-checklist.md` §16 — one table, so the two
answers can never drift apart unnoticed.

## The headline finding

**Apple has no equivalent of Play's AI-Generated Content policy.** The App Review Guidelines were
fetched in full on 2026-09-15 (Last Updated: June 8, 2026, 93 KB of guideline text) and the string
"AI" occurs in exactly one guideline: **5.1.2(i)**, about *sharing personal data with* third-party AI.
There is no 3.3.x AI section, no "Foundation Models" clause, no generative-content reporting rule, and
the age-rating questionnaire has no AI question. [V: absent]

Consequence: the item that **BLOCKS** on Play (§1, the "without needing to exit the app" reporting
wording) **does not block on the App Store**. The App Store's blockers are different and fewer:
privacy policy URL, App Privacy answers, the privacy manifest, and an honest age rating.

## Summary

| # | Policy / requirement | Status | Blocks release? | Spine |
|---|---|---|---|---|
| 1 | AI-generated content and reporting (Guideline 1.2, 4.7) | **met** — the per-reply Report sheet exceeds Apple's wording | no | C9, C3 |
| 1b | Preventing restricted output (1.1.x) | gap — same gap as Play §1b (D-026) | review risk, not a hard block | C9, C5 |
| 2 | Guideline 5.1.2(i) — third-party AI data sharing | **met** — nothing to declare, and nothing to *add* | no | C3 |
| 3 | Privacy manifest `PrivacyInfo.xcprivacy` | **gap** — not written yet; spec in §3 below | **BLOCKS** (App Store Connect rejects the upload) | C3 |
| 4 | App Privacy "nutrition label" | answers below; Console form to fill | **BLOCKS** until published | C3, C9 |
| 5 | Privacy policy URL + in-app text (5.1.1(i)) | **partly met** — in-app text exists on Android; hosted URL pending D-022 | **BLOCKS** | C3, C9 |
| 6 | Age rating questionnaire | needs Hari (recommend 18+ via manual override) | **BLOCKS** until answered | C9 |
| 7 | Export compliance `ITSAppUsesNonExemptEncryption` | gap — one Info.plist key, not yet written | small; blocks a *frictionless* upload | C1 |
| 8 | `com.apple.developer.kernel.increased-memory-limit` | **met by not using it** — not needed for the COMPACT profile | no | C2, C11 |
| 9 | App size, download, On-Demand Resources | **met** — bundle the model; do not use ODR/Background Assets | no | C1, C2, C3 |
| 10 | Apple Developer Program account | needs Hari — $99/yr; **no 12-tester/14-day gate** | **BLOCKS** until enrolled | C1 |
| 11 | Guideline 2.1 completeness / Review Notes | gap — notes needed (the gate screen, the offline model) | review risk | C6, C5 |
| 12 | Device/OS floor — the iOS substitute for Play device exclusion | gap — minimum iOS version not yet chosen (D-009 sibling) | no | C2, C6 |
| 13 | Guideline 2.5.2 self-contained bundle | met — the model ships in the bundle | no | C1 |
| 14 | Content rights, support URL, App Store Connect metadata | needs Hari | **BLOCKS** until filled | C4 |
| 15 | Licences in-app (C4) | see `licence-audit.md` §7 (iOS bundle) | no | C4 |

---

## 1. AI-generated content and in-app reporting

**What Apple actually says.** There is no AI-content policy. The nearest rules are:

**Guideline 1.2, User-Generated Content [V]** ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)):
> "Apps with user-generated content present particular challenges, ranging from intellectual property
> infringement to anonymous bullying. To prevent abuse, apps with user-generated content or social
> networking services must include:
> - A method for filtering objectionable material from being posted to the app
> - A mechanism to report offensive content and timely responses to concerns
> - The ability to block abusive users from the service
> - Published contact information so users can easily reach you"

**Guideline 4.7 [V]** covers "Mini apps, mini games, streaming games, **chatbots**, plug-ins, and game
emulators", but its scope is explicit: "software that is **not embedded in the binary**". Arivu's model
is a resource inside the app bundle and the inference runs in-process, so 4.7 does not apply. 4.7.1's
report/filter/block requirement therefore does not reach Arivu either. **If iOS ever downloads the model
(§9), re-read 4.7 before shipping** — that is the change that could pull Arivu into it [U].

**The comparison Hari asked for.**

| | Google Play | Apple App Store |
|---|---|---|
| Rule | AI-Generated Content policy, [answer/13985936](https://support.google.com/googleplay/android-developer/answer/13985936) | Guideline 1.2 (if it applies at all) |
| Scope trigger | "Text-to-text AI chatbot apps, in which the AI generated chatbot interaction is a central feature" — Arivu is squarely in | "apps with user-generated content **or social networking services**" — Arivu is single-user and offline; arguably out |
| Wording on reporting | "report or flag offensive content to developers **without needing to exit the app**" | "A mechanism to report offensive content **and timely responses to concerns**" |
| Does Arivu's Report sheet satisfy it? | **Literally no** — the email/share hand-off exits the app (play checklist §1, D-021) | **Yes** — Apple's text requires a mechanism, not an in-process transport |

So the same code is a documented gap on Play and a clean pass on Apple. The difference is six words.

**What Arivu has, and what it means on iOS.** Android already ships the per-reply Report sheet (reason
chips + note, reply pre-attached, "Reported" marked locally, then an email/share hand-off) —
`ui/ReportOutput.kt`, `ui/ChatScreen.kt:113`, verified by `ReportOutputTest.kt`. The iOS equivalent is
`MFMailComposeViewController` (`leaves/architecture/ios-port.md`), which is *more* in-app than Android's
`ACTION_SENDTO`: the compose sheet is presented by Arivu, inside Arivu, and control returns to Arivu.
If Play's wording is ever tested, the iOS implementation is the better evidence of intent.

**Assessment — met, non-blocking.** Two residual notes for Review Notes rather than for code:
- Arivu cannot "block abusive users" or "filter material from being posted": there are no other users
  and nothing is posted. Say so in App Review Information rather than inventing a moderation UI.
- "Published contact information" and "timely responses" need the same monitored mailbox as Play
  (**D-010**) and the same retention answer (**D-023**). One mailbox serves both stores.

## 1b. Preventing restricted output

`Policy.SYSTEM_PROMPT` now carries refusal guidance (Android `Policy.kt:26`, iOS `Policy.swift`,
byte-identical — asserted by `ProfileParityTest.theSystemPromptIsByteIdenticalOnBothPlatforms`). The
host probe in `leaves/NOTES.md` says that instruction barely moves refusals at 0.6B. Apple's relevant
guidelines are 1.1.1–1.1.7 (objectionable content) rather than an AI clause; the practical exposure is
a reviewer typing something ugly and getting an answer.

**gap, review risk, not a hard block.** Same fix as Play §1b: the red-team eval slice under **D-026**.
Nothing iOS-specific, which is the point — one safety layer, written once (`MULTIPLATFORM.md` appendix).

## 2. Guideline 5.1.2(i) — third-party AI

**Verbatim [V]:**
> "Unless otherwise permitted by law, you may not use, transmit, or share someone's personal data
> without first obtaining their permission. You must provide access to information about how and where
> the data will be used. **You must clearly disclose where personal data will be shared with third
> parties, including with third-party AI, and obtain explicit permission before doing so.**"

**Arivu sends nothing anywhere.** The clause is about *sharing personal data with* a third party. The
model weights are a third party's (Alibaba Cloud, Apache-2.0, quantized by Unsloth), but they are
bundled bytes executed in Arivu's own process; no data reaches Alibaba, Unsloth, Apple or anyone else.
The trigger for 5.1.2(i) is transmission, and there is none.

**What that means for the declaration — three things, one of them counter-intuitive:**
1. **Nothing to disclose.** No "we share your text with X" line, because there is no X.
2. **Nothing to consent to. Do not add a consent sheet.** A permission prompt for sharing that does not
   happen is a false statement to the user, and a screen Arivu has decided not to have (C8).
3. **Say it anyway, in the privacy policy, as a fact rather than a disclosure:** the model is a third
   party's weights running locally, and no text leaves the phone. That is C4/C5 honesty, not 5.1.2(i)
   compliance, and it is the sentence a reviewer looking for 5.1.2(i) will want to find.

**met.** [U on one point: "third-party AI" is undefined in the guidelines, so the reading above —
that a *bundled local model is not a third party you share data with* — is an interpretation. It is
the only reading consistent with the clause's own subject, which is transmission.]

## 3. Privacy manifest — `PrivacyInfo.xcprivacy`

**Rule [V]** ([Privacy manifest files](https://developer.apple.com/documentation/BundleResources/privacy-manifest-files),
[Describing use of required reason API](https://developer.apple.com/documentation/BundleResources/describing-use-of-required-reason-api)):
> "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy
> manifest file aren't accepted by App Store Connect."
> "For each executable or dynamic library in an app that uses a required reason API, the bundle that
> includes the executable or dynamic library needs to include a privacy manifest file that reports the API."

Filename is fixed: `PrivacyInfo.xcprivacy`, at the app bundle root. **BLOCKS** — this one is enforced by
a machine at upload, not by a reviewer.

**No separate manifest is needed for llama.cpp/ggml or ArivuKit** [V, from the sentence above]: both are
compiled from source into the app executable, so the app's own manifest covers them. This would change
if `/core` were ever shipped as a **binary** XCFramework — then it would need its own manifest and
signature. It is a source SwiftPM package (`ios/ArivuKit/Package.swift`), so it is not.

### Which required-reason APIs a local-LLM app actually touches

Four of the five categories are in play. The evidence is from this repo, not from a general guess.

| Category (exact `NSPrivacyAccessedAPIType` value [V]) | Does Arivu touch it? | Evidence | Reason code |
|---|---|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp` | **Yes** | `third_party/llama.cpp/src/llama-mmap.cpp:335` calls `fstat(fd, &file_stats)` to read `st_size` when mapping the GGUF. `fstat(_:_:)` is on Apple's list verbatim. | `C617.1` |
| `NSPrivacyAccessedAPICategoryDiskSpace` | **Yes** | `ios/ArivuKit/Sources/ArivuCore/DeviceGate.swift:97` reads `.volumeAvailableCapacityForImportantUsageKey`; the gate refuses the device below `Policy.minFreeStorageBytes` and the screen shows the figure. | `E174.1` **and** `85F4.1` |
| `NSPrivacyAccessedAPICategoryUserDefaults` | **Yes** | `DeviceGate.swift:125` `GatePassStore` writes the cached gate pass to `UserDefaults.standard`. | `CA92.1` |
| `NSPrivacyAccessedAPICategorySystemBootTime` | **Probably** — declare it | `core/src/engine.cpp:13` uses `std::chrono::steady_clock`, which on Apple platforms may lower to `mach_absolute_time()` depending on the libc++ version. ggml itself uses `clock_gettime(CLOCK_MONOTONIC)` (`ggml.c:564`), which is **not** on Apple's list. | `35F9.1` |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | **No** | Arivu is not a keyboard app and never reads the active-keyboard list. | — do not declare |

**Why those exact reason codes, in Apple's own words [V]:**
- `C617.1` — "Declare this reason to access the timestamps, size, or other metadata of files inside the
  app container, app group container, or the app's CloudKit container." This is the only reason that can
  apply: `DDA9.1` is for *displaying* timestamps (Arivu never shows one), `3B52.1` is for files the user
  picked with a document picker (SPINE R4 refuses document import), `0A2A.1` is third-party-SDK-only.
  [U on one nuance: the GGUF lives in the *app bundle*, and Apple's phrase is "app container". The
  conversation JSON is unambiguously in the app container, so `C617.1` is required regardless; there is
  no better-fitting code for the bundle read, and no code for "does not apply".]
- `E174.1` — "check whether there is sufficient disk space to write files ... The app must behave
  differently based on disk space in a way that is observable to users." Arivu's gate is exactly that:
  below the floor it shows the incompatible screen instead of the chat.
- `85F4.1` — "display disk space information to the person using the device." Declare this **only if**
  the iOS incompatible screen prints the byte figures the way Android's does (`ByteSize.si(...)` suggests
  it will). If the screen ends up showing no numbers, drop `85F4.1` and keep `E174.1`.
- `CA92.1` — "read and write information that is only accessible to the app itself." Not `1C8F.1`
  (that is for an App Group, and Arivu has none), not `C56D.1` (third-party SDK), not `AC6B.1` (MDM).
- `35F9.1` — "measure the amount of time that has elapsed between events that occurred within the app
  or to perform calculations to enable timers." That is precisely what `engine.cpp` does for
  `prefill_ms` / `decode_ms` / `first_token_ms`. Note the constraint attached to it: "Information
  accessed for this reason, or any derived information, may not be sent off-device" — trivially
  satisfied (C3), but it is a real obligation if telemetry is ever added.
  **If the iOS Leaf prefers to declare only what is provably called**, check the built binary for a
  `mach_absolute_time` reference (`tools/ios_release_check.sh` does exactly this) and drop the category
  if it is absent. Under-declaring gets an automatic rejection email from App Store Connect;
  over-declaring does not, so the asymmetry favours declaring it.

### The file, ready to write

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- spine: C3 — Arivu collects nothing and tracks nobody; this file is that claim, machine-readable. -->
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>
  <key>NSPrivacyCollectedDataTypes</key>
  <array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <!-- llama.cpp fstat()s the GGUF for its size; the conversation file is read and written. -->
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>C617.1</string></array>
    </dict>
    <dict>
      <!-- The compatibility gate refuses a phone without room for the model, and says how much. -->
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>E174.1</string><string>85F4.1</string></array>
    </dict>
    <dict>
      <!-- GatePassStore remembers "this phone already passed". Not a user setting (C8). -->
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
    <dict>
      <!-- engine.cpp times prefill and decode with std::chrono::steady_clock. Never sent off-device. -->
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>35F9.1</string></array>
    </dict>
  </array>
</dict>
</plist>
```

`NSPrivacyTrackingDomains` must stay empty: it may only be non-empty when `NSPrivacyTracking` is `true` [V].
`NSPrivacyCollectedDataTypes` is an empty array, not an absent key — the empty array is the positive
statement. Xcode's **Product > Archive > Generate Privacy Report** aggregates the declared manifests into
the PDF Apple expects; it does **not** detect undeclared calls [U], so it proves the file is present and
well-formed, not that it is complete.

## 4. App Privacy "nutrition label"

**Rules [V]** ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)):
> "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party
> partners to access it for a period longer than what is necessary to service the transmitted request in
> real time."
> "Data processed only on-device and never sent to a server is not 'collected' and does not need to be disclosed."

App Privacy responses must be published before a version can be submitted [V, App Store Connect Help].

**Answers**

| Question | Answer | Basis |
|---|---|---|
| Do you or your third-party partners collect data from this app? | **No** | Nothing is transmitted. The iOS proof is weaker than Android's missing `INTERNET` permission — see below. |
| Data types (Contact Info, Health & Fitness, Financial Info, Location, Sensitive Info, Contacts, User Content, Browsing History, Identifiers, Purchases, Usage Data, Diagnostics, Surroundings, Body, Other) | **none selected** | No analytics, no crash reporting, no ads, no accounts, no network. |
| Tracking / App Tracking Transparency | Not applicable; `NSPrivacyTracking` is `false` and no `NSUserTrackingUsageDescription` is present | C3 |
| Privacy policy URL | **required — missing (§5)** | [V] |
| Privacy choices URL | Not applicable (no data collected, so no choices to offer) | [U] |

Result on the product page: **"Data Not Collected"**.

**The report email, again [U].** Same reasoning as Play §2 and **D-025**: when the user sends a report,
*Mail* transmits the reply text and their address; Arivu transmits nothing, and the user chose it each
time. Under Apple's definition of "collect" ("transmitting data off the device") the answer stays **No**,
and the report flow is described in the privacy policy. The iOS case is slightly *stronger* than the
Android one, because `MFMailComposeViewController` returns control to Arivu and Arivu never gets the
message — worth one sentence in the policy so both stores read the same explanation.

**The honest caveat that belongs in the listing copy, not the form.** On Android, C3 is provable by
absence: no `INTERNET` permission, checked on every build by `tools/check_manifest.sh`. iOS has no
permission to withhold. The strongest available iOS claim is "Arivu does not use the network", backed
by open source, the App Privacy label, and `tools/ios_release_check.sh` asserting no networking symbol
or entitlement in the shipped binary. **This is a GTM copy decision, not a form answer** — the iOS
listing must not reuse the Android sentence verbatim (raised in `ios-port.md`; belongs in a decision).

## 5. Privacy policy

**Rule, Guideline 5.1.1(i) [V]:**
> "All apps must include a link to their privacy policy in the App Store Connect metadata field **and
> within the app in an easily accessible manner**. The privacy policy must clearly and explicitly:
> Identify what data, if any, the app/service collects, how it collects that data, and all uses of that
> data. ... Explain its data retention/deletion policies and describe how a user can revoke consent
> and/or request deletion of the user's data."

Apple requires the in-app copy *and* the URL; Play's wording allows "a privacy policy link **or** text
within the app itself". So Apple is marginally stricter, and Arivu's choice to ship the full text in
About (readable offline, because the user may not be able to load a browser) satisfies both.

**gap, BLOCKS** — for the same reason as Play §3: the hosted page does not exist yet (**D-022**).
One text, two stores; no iOS-specific content. Account-deletion rules do not apply (no accounts, and
5.1.1(v) only requires in-app deletion "If your app supports account creation") [V].

## 6. Age rating

**The questionnaire, as it now stands [V]**
([Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings/)).
Levels: **4+, 9+, 13+, 16+, 18+, Unrated**. Sections: In-App Controls (Parental Controls, Age Assurance);
Capabilities (Unrestricted Web Access, User-Generated Content, Social Media, Social Media Disabled for
Users Under 13, Messaging and Chat, Advertising); Mature Themes; Medical or Wellness; Sexuality or
Nudity; Violence; Chance-Based Activities. Frequencies: None / Infrequent / Frequent (+ Intense).
**There is no AI or generated-content question** [V: absent].

**Honest answers for Arivu**

| Section | Answer | Note |
|---|---|---|
| Parental Controls | No | No controls to offer; C8. |
| Age Assurance | No | No age gate. Do not add one — it is a settings screen wearing a hat. |
| Unrestricted Web Access | **No** | No network at all, let alone a browser. |
| User-Generated Content | **No** | "the broad distribution of content created by users" — Arivu distributes nothing; the conversation never leaves the phone. |
| Social Media / Social Media Disabled Under 13 | No | No feed, no sharing, no other users. |
| Messaging and Chat | **No** | Apple defines it as "Users can **directly communicate with one another**". The user talks to a model, not to a person. Answering Yes here would be inaccurate and would over-rate the app for the wrong reason. |
| Advertising | No | No ads, no ad identifier. |
| Mature Themes / Medical / Sexuality / Violence / Chance-Based | **None** for authored content | Arivu ships no such content. The model can produce some on request; that is the next paragraph, not a checkbox. |

Answered honestly, the questionnaire returns **4+** or close to it.

**Recommendation (needs Hari): answer the questionnaire honestly, then use Apple's manual override to
set 18+.** Apple supports this explicitly [V]: "If your app has a policy requiring a higher minimum user
age than the rating assigned by Apple, you can set a higher age rating after you respond to the age
ratings questions."

**Why.** The questionnaire measures authored content and it is right that Arivu scores 4+ on it. But the
app puts an unfiltered generative model in front of whoever holds the phone, and Guideline 2.3.6 says
[V]: "Answer the age rating questions in App Store Connect honestly so that your app aligns properly
with parental controls. If your app is mis-rated, customers might be surprised by what they get, or it
could trigger an inquiry from government regulators." A 4+ badge on an unfiltered chatbot is the single
most challengeable claim in the submission. The override exists for exactly this.

**The consequence, stated plainly.** 18+ costs real distribution:
- The app disappears for anyone whose Screen Time content restriction is below 18+ — including a lot of
  shared family phones in the Spine's target markets [U].
- It is excluded from child- and family-facing editorial surfaces, and from any Kids context.
- Some territories attach extra obligations or age verification to an 18+ rating (Korea, mainland China
  are the usual examples) [U] — relevant if the iOS launch waves mirror Play's (D-029).
- It is reversible: once the D-026 red-team slice exists and the eval shows the refusals hold, 16+ or 13+
  becomes defensible and the rating can be lowered.

**Make this the same decision as Play's D-024** (target audience 18+). Two stores, one call — otherwise
Arivu is 18+ on Play and 4+ on the App Store, which is not a position anyone can defend to either.

## 7. Export compliance — `ITSAppUsesNonExemptEncryption`

**Rule [V]** ([Complying with Encryption Export Regulations](https://developer.apple.com/documentation/Security/complying-with-encryption-export-regulations),
[ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/BundleResources/information-property-list/itsappusesnonexemptencryption)):
> "Set the value for this key to `NO` in your app's Info.plist file to indicate that your app — including
> any third-party libraries you link against — either uses no encryption, or only uses encryption that's
> exempt from export compliance requirements."
> "If you don't have the key in your app's Info.plist file, App Store Connect walks you through an export
> compliance questionnaire **every time you upload a new version**."
> "Typically, the use of encryption that's built into the operating system ... is exempt."

**Arivu: set `ITSAppUsesNonExemptEncryption` to `false`.** Arivu implements no cryptography: no TLS (no
network), no signing, no at-rest encryption of its own. iOS Data Protection encrypts the conversation
file (`ChatRepository.swift:105`, `.protectionKey` / `completeUnlessOpen`), and that is OS-provided
encryption, which the doc names as the exempt case.

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

**gap** (the key is not written yet) but low: without it every upload gets the questionnaire, which is
friction rather than a block. Asserted by `tools/ios_release_check.sh`.

**Two footnotes.**
- Apple: "If your app uses **exempt** forms of encryption, you might alternatively be required to submit
  a year-end self-classification report to the U.S. government" [V]. An app that uses *no* encryption of
  its own has nothing to classify [U — a legal reading, same standing as the EAR note in Play §11].
  Flag for Hari; cost of being wrong is low, cost of asking a lawyer is probably higher.
- Revisit if iteration-2 adds the signature-fingerprint screen (hashing only; still not 5D002 [U]).

**Difference from Play:** Play has no encryption declaration at all. This is a genuinely iOS-only item,
and it is the cheapest one on the list — one key.

## 8. `com.apple.developer.kernel.increased-memory-limit`

**What Apple says [V]** ([entitlement page](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.kernel.increased-memory-limit)):
> "A Boolean value that indicates whether core features of your app may perform better with a higher
> memory limit on supported devices."
> "Add this entitlement to your app to inform the system that some of your app's core features may
> perform better by exceeding the default app memory limit on supported devices. If you use this
> entitlement, make sure your app still behaves correctly if additional memory isn't available."
> Note: "An increased memory limit is only available on **some device models**. Call the
> `os_proc_available_memory` function to determine the amount of memory available. Higher memory use can
> affect system performance."

Availability: **iOS 15.0+, iPadOS 15.0+, visionOS 2.5+** [V, from the page's platform metadata].

**Does it need justification at review?** No documented review step, no request form, no Apple approval:
it is a standard capability added in Xcode's Signing & Capabilities editor, unlike the entitlements that
carry an application form (CarPlay, HLS, etc.). [V: absent — the entitlement page describes no request
process; U — an absence of documentation is not a guarantee.] Guideline 2.3.1(a) requires *features* to
be described in Review Notes with specificity; an entitlement is not a feature, so no note is required [U].

**Which devices?** Apple does not publish the list — "some device models" is all it says [V]. Community
measurement (not Apple, [U]) puts the boundary around devices with ≥ 4 GB RAM and reports the increase
in the low-GB range, not a blanket lift. The only supported way to know at runtime is
`os_proc_available_memory()`, which is what `MULTIPLATFORM.md` already says to use.

**Recommendation: do not add it in iteration-1.** The COMPACT profile peaks around 695–750 MB
(`leaves/NOTES.md`, emulator; W02 will say what a phone does), and `MULTIPLATFORM.md` puts an ordinary
app's budget on a 4 GB iPhone at roughly 1.3–2 GB before jetsam. Arivu fits with room. Adding an
entitlement the app does not need means: an extra capability on the App ID, an entitlement that must be
present in the distribution provisioning profile or it is silently stripped at signing (a build failure
mode, not a policy one), and a line in the binary that invites a question Arivu has no reason to answer.

**Record it as the gate on the next profile, not as a to-do.** `MULTIPLATFORM.md` caution 1 is right:
this entitlement is how local-LLM apps ship 3B+ models, and any future `qwen3-4b-q4km` profile depends
on it. That makes it a C11 question — "capability follows the device" — and the honest shape is: the
entitlement is part of the *profile's* requirements, checked by `arivu_profile_fits` against
`available_memory_bytes`, not a platform flag. Propose **D-039** below.

## 9. App size, download, and On-Demand Resources

**Limits [V]** ([Maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/)):
4 GB maximum uncompressed app size for iOS 9.0 and later; **80 MB maximum for the total of all `__TEXT`
sections in the binary**.

**Arivu at ~400 MB is nowhere near the bundle limit.** The `__TEXT` limit is the one that can bite, and
only through a mistake: the GGUF must be a **bundle resource**, never linked into the executable (no
Swift byte array, no `.o` blob). `Policy.modelResourceName`/`modelResourceExtension` already do this
correctly. `tools/ios_release_check.sh` asserts the model is a file in the bundle and that the executable
is small.

**Download.** The App Store's "App Downloads" setting defaults to **"Ask If Over 200 MB"** for cellular
[V, [Apple Support](https://support.apple.com/guide/iphone/manage-purchases-settings-and-restrictions-iph3dfd91de/ios)].
Arivu will prompt, or need Wi-Fi. This is the *same* threshold as Play's >200 MB mobile-data dialog —
so the "install on Wi-Fi" line in the store copy is identical on both stores, not two pieces of copy.
GGUF Q4_K_M is already near-incompressible, so the download stays ≈ the bundle size [U].

**Does On-Demand Resources change any obligation? Yes — it adds one, removes none, and it is deprecated.**

1. **It breaks the product.** ODR and its replacement both download over the network. That means a
   network-capable binary, a first-run download, and a phone that must be online once — which
   contradicts C1 ("no model download"), C2 ("no internet, ever") and guts the C3 claim that
   `ios_release_check.sh` is meant to prove. **This is a Spine change, not a packaging choice.**
2. **It adds Guideline 4.2.3(ii) [V]:** "If your app needs to download additional resources in order to
   function on initial launch, disclose the size of the download and prompt users before doing so."
   A new obligation, and a new screen, for an app whose whole shape is one screen.
3. **It is deprecated [V]** ([ODR size limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits)):
   "On-demand resources has been deprecated on Apple platforms as of iOS 27, iPadOS 27, tvOS 27, and
   visionOS 27, and support will be removed in future releases. Migrating to Background Assets is
   recommended." (Limits, for the record: iOS 18+ — 4 GB app bundle, 8 GB per asset pack, 70 GB hosted.)
4. **It relieves no pressure.** The 4 GB limit is not binding at 400 MB. ODR exists for apps that cannot
   fit; Arivu fits.

**Recommendation: bundle the model. Do not use ODR or Background Assets.** This is the iOS answer to the
question Play answered with an install-time PAD pack, and it lands in the same place for the same reason:
the app must work the moment it opens, on a phone that has never been online. **met.**

## 10. Account requirements — and the question about Play's tester gate

**Apple Developer Program [V]** ([Enrollment](https://developer.apple.com/programs/enroll/)):
**$99 USD per year.** Individual/sole proprietor needs an Apple Account with two-factor auth, legal age
of majority, and the enrollee's **legal name** (no aliases), email, phone and a physical address (no P.O.
boxes). Organization needs a **D-U-N-S Number**, a legal entity (no DBAs or branches), a work email on
the organization's domain, a publicly available website on that domain, and an account holder with legal
binding authority. Fee waivers exist for nonprofits, accredited educational institutions and governments.

**Hari's belief is correct: there is no App Store equivalent of Play's 12-tester/14-day gate.**
Play's rule [V] ([answer/14151465](https://support.google.com/googleplay/android-developer/answer/14151465))
requires personal accounts created after 2023-11-13 to run a closed test with "a minimum of 12 testers
who have been opted in continuously for at least 14 days" before applying for production access. Apple's
enrollment page states no testing requirement of any kind, and TestFlight imposes no minimum tester count
or duration before an App Store submission. [V: absent — the enrollment page was fetched and contains
nothing on testing; U — proving a universal negative from Apple's docs is not possible, so this should be
confirmed once the account exists, which costs nothing.]

**What that does to the plan, and it is not a small thing.**
`leaves/architecture/ios-port.md` assumed the shape "Android's 14-day dead time is the free budget for
the iOS port, then launch together". With no tester gate, **the iOS path's only calendar cost is App
Store review — typically days.** iOS could reach the store *before* Android production, not after. That
is a sequencing and positioning question (does the offline-Android product launch on iPhone first?), and
it belongs to Hari and the Sequencing Leaf, not to Compliance. Raised as **D-038** below.

**Also needs Hari.** Individual enrollment publishes Hari's **legal name as the seller** on every product
page. Play's personal-account rules push in the same direction, so this is not new — but it is worth
deciding once, for both stores, alongside **D-020** (Play account type) rather than twice.

## 11. Guideline 2.1 completeness and Review Notes

**Rule [V]:** "Submissions to App Review ... should be final versions with all necessary metadata and
fully functional URLs included; placeholder text, empty websites, and other temporary content should be
scrubbed before submission." Guideline 2.3.1(a) [V]: "All new features, functionality, and product
changes must be described with specificity in the Notes for Review section of App Store Connect (generic
descriptions will be rejected)."

**gap, review risk.** Draft the App Review Information note now, covering the four things a reviewer
will otherwise mis-read:
1. **No login, no network.** All functionality is available immediately; the app has no server and makes
   no network requests, by design. (The iOS analogue of Play's "App access" answer.)
2. **The model is on the device.** Replies are generated by a bundled ~400 MB Qwen3-0.6B; no API call.
   Cold start on the first message takes a few seconds while the model loads — that is the product, not
   a hang.
3. **The compatibility gate.** On a device below the RAM/storage floor the app deliberately shows a
   one-screen explanation instead of the chat. On iOS it cannot offer to uninstall itself the way the
   Android build does. Reviewers on current iPhones will not see it; say so before they do.
4. **Reporting.** Per-reply Report opens an in-app sheet and then a Mail compose sheet, because the app
   has no network. Give the report address (**D-010**).

Also 2.1: `report@example.invalid` is exactly the "placeholder text" 2.1 names. Same blocker as Play,
same fix, one decision.

## 12. The device floor — what replaces Play's device exclusion

**There is no App Store device-exclusion catalogue.** Play lets Arivu exclude phones by RAM (gate layer
2, D-009); the App Store filters on minimum iOS version and declared device capabilities only.
`ios-port.md` has this right, and `DeviceGate.swift` already carries the consequence: layers 1 and 2
collapse into "a minimum iOS version", and the runtime gate does the rest — but on iOS it can only
explain and stop, never offer `ACTION_DELETE`.

**gap, not blocking, but it needs a number.** The minimum iOS version is the only lever, and it is a
proxy for silicon: a floor of iOS 17 or 18 implies a chip and roughly implies a RAM class. Set it from
the same measurement that sets D-009, and record both in `leaves/NOTES.md` so the two platforms'
floors are visibly one decision. Expect more "it's slow" reviews per thousand installs than on Android,
or set the iOS floor higher than the Android one (`ios-port.md`).

## 13. Guideline 2.5.2 — self-contained

**Verbatim [V]:** "Apps should be self-contained in their bundles, and may not read or write data outside
the designated container area, nor may they download, install, or execute code which introduces or
changes features or functionality of the app, including other apps."

Arivu is the easy case: the model is in the bundle, the conversation is in the app container, nothing is
downloaded, nothing is executed that was not compiled in. **met** — and it is the guideline that makes §9's
recommendation (bundle, don't download) the low-risk option rather than merely the convenient one. [U: no
one has tested whether App Review treats downloaded *model weights* as "code"; not shipping a download is
the way not to find out.]

## 14. App Store Connect metadata

| Field | Answer | Status |
|---|---|---|
| Privacy Policy URL | pending D-022 | **BLOCKS** |
| Support URL | needed — a page Hari monitors (GitHub repo issues page is acceptable [U]) | needs Hari |
| Marketing URL | optional; omit | met |
| Copyright | Hari / the developer name chosen in D-022 | needs Hari |
| Content Rights — "does your app contain, show, or access third-party content?" | **Yes**, and Arivu has the rights: Qwen3-0.6B weights, Apache-2.0 (see `licence-audit.md`) [U on the exact question wording, which only Console shows] | needs Hari |
| Age Rating | §6 | **BLOCKS** |
| App Privacy | §4 | **BLOCKS** |
| Export Compliance | §7 (answered by the Info.plist key) | met once written |
| Category | Productivity (primary); Utilities (secondary) [U] | needs Hari |
| Price | Free, no in-app purchases | met |
| Sign in with Apple | Not applicable — no third-party login, no accounts (4.8 only bites if a social login exists) [V] | met |

## 15. Licences

`licence-audit.md` §7 covers what changes for an iOS bundle and what the in-app licences screen must
show. Short version: **nothing new enters the binary**, two things leave it, and one obligation
disappears entirely.

---

## What is NOT checkable from here

No Xcode, no built `.app`, no App Store Connect access. Everything above is either policy text (fetched
and quoted) or a claim about this repo's source (cited by file and line). The machine-checkable half is
written as `tools/ios_release_check.sh`, which has never been run against a real bundle — it was
verified against a synthetic fixture bundle. Items only App Store Connect can settle are marked
needs Hari.

---

## 16. Proposed decisions and work items

Compliance does not own `leaves/decisions.yml` or `leaves/sequencing/workitems.yml`. These are drafted
in the house style for the Decisions and Sequencing Leaves to paste. IDs continue from D-037.

### 16.1 Decisions to extend, not duplicate

These already exist and are **both-platform decisions**. They need a `platform: both` tag and one extra
sentence each, not a second entry — otherwise Arivu makes the same call twice and gets two answers.

| Decision | What to add |
|---|---|
| **D-021** Per-reply Report | "Satisfies Apple's Guideline 1.2 as written; remains a documented gap against Play's 'without needing to exit the app'. iOS uses `MFMailComposeViewController`, which is more in-app than `ACTION_SENDTO`." |
| **D-022** Privacy policy | "Apple's 5.1.1(i) requires the URL **and** in-app text; the same text and the same hosted page serve both stores." |
| **D-023** Report retention | "Same mailbox, same retention, both stores. Apple 1.2 also asks for 'timely responses to concerns'." |
| **D-024** 18+ | "On the App Store this is an age-rating **manual override** after answering the questionnaire honestly (which returns ~4+). Same position, different mechanism. Do not let the two stores diverge." |
| **D-025** "No data collected" | "Apple's App Privacy uses a narrower definition of 'collect' ('transmitting data off the device'), so the same answer is easier to defend there. Answer 'Data Not Collected'." |
| **D-026** Output safeguards | "Apple has no AI policy; the exposure is Guidelines 1.1.1–1.1.7 and the age rating. One red-team slice covers both stores." |
| **D-010** Report address | "Blocks both gates: `tools/release_check.sh` step 1 and `tools/ios_release_check.sh` step 8." |
| **D-009** RAM floor | "The same number sets the Android gate *and* the iOS one; only the enforcement differs (Play device exclusion vs `MinimumOSVersion` + runtime gate)." |

### 16.2 New decisions

```yaml
- id: D-038
  title: iOS has no 12-tester/14-day gate — does that change the launch shape?
  raised_at: 2026-09-15
  spine: [C1, C11]
  platform: both
  adjudication: human
  status: pending
  blocks_release: false
  raised_by: [Compliance]
  context: >
    leaves/architecture/ios-port.md assumed the iOS port would happen inside Play's 14-day closed-test
    window and the two would launch together. Apple has no equivalent gate: enrolment ($99/yr, 2FA,
    legal name or a D-U-N-S) and then App Store review, typically days. [V: absent — Apple's enrolment
    page states no testing requirement; TestFlight imposes no minimum tester count or duration.]
    So iOS could reach the store before Android production, not after.
  options:
    - hold iOS until Android production, purely for narrative coherence
    - ship iOS whenever it is ready, accept that the offline-Android app debuts on iPhone
    - keep them together by delaying iOS submission to the Android production date
  recommendation: >
    Decide what iOS is *for* first (D-037 asks the same question). If iOS exists for credibility and
    press, shipping it first undercuts the story the product is telling about $2 phones and prepaid
    data. If it exists to be used, waiting costs users nothing and buys nothing.
  if_rejected: no code changes; sequencing assumption in ios-port.md stands and should be corrected anyway.

- id: D-039
  title: com.apple.developer.kernel.increased-memory-limit — a profile requirement, not a platform flag
  raised_at: 2026-09-15
  spine: [C2, C11, C8]
  platform: ios
  adjudication: human
  status: pending
  blocks_release: false
  raised_by: [Compliance]
  context: >
    The entitlement is a Boolean, iOS 15.0+, needs no Apple approval or request form [V], and raises the
    jetsam limit on "some device models" only [V — Apple publishes no list]. The COMPACT profile peaks
    around 695-750 MB against a ~1.3-2 GB budget, so it is not needed. MULTIPLATFORM.md caution 1 is
    right that any future 3B/4B profile depends on it.
  options:
    - do not add it in iteration-1; record it as a precondition of any larger profile
    - add it now "in case"
  recommendation: >
    Option 1. Adding an unused entitlement means an extra App ID capability, an entitlement that is
    silently stripped if it is missing from the distribution profile, and a line in the binary inviting
    a question Arivu has no reason to answer. Model it as part of the *profile's* requirements — checked
    by arivu_profile_fits against available_memory_bytes — so it stays a device fact, not an #ifdef (C11).
  if_rejected: add the entitlement and the App ID capability; ios_release_check.sh already NOTEs its presence.

- id: D-040
  title: One NOTICE, or a generated NOTICE per platform?
  raised_at: 2026-09-15
  spine: [C4, C11]
  platform: both
  adjudication: human
  status: pending
  blocks_release: false
  raised_by: [Compliance]
  context: >
    The root NOTICE names kotlinx.coroutines, kotlinx.serialization and ThreeTen-BP. None of that code
    is in an iOS binary (licence-audit.md §7.1). Shipping it verbatim on iOS asserts obligations for
    code that is not there: harmless, but untrue. MULTIPLATFORM.md already lists "NOTICE generation"
    among the shared things.
  options:
    - ship the root NOTICE verbatim on both platforms (over-attribution breaches nothing)
    - generate per-platform NOTICE.txt from one source (tools/make_notice.py)
  recommendation: >
    Option 2, but not urgently. It also lets LicensesTest relax from equality to "covers everything in
    this binary", which is the assertion that is actually true. tools/ios_release_check.sh already
    implements that rule for iOS.
  if_rejected: ship the root NOTICE on iOS; licence-audit.md §7.5 says that is safe.

- id: D-041
  title: How the iOS listing words the privacy claim, given C3 is only provable on Android
  raised_at: 2026-09-15
  spine: [C3, C11, C5]
  platform: both
  adjudication: human
  status: pending
  blocks_release: true
  raised_by: [Compliance, Architecture]
  context: >
    On Android, "no internet permission" is enforced by the OS and asserted on every build by
    tools/check_manifest.sh. iOS has no permission to withhold. The strongest available iOS sentence is
    "Arivu does not use the network", backed by open source, App Privacy "Data Not Collected", and
    tools/ios_release_check.sh asserting no networking framework, symbol, entitlement or Info.plist key
    in the shipped Mach-O. That is a weaker sentence, and the Spine's positioning rests on the stronger
    one. Raised in ios-port.md; unresolved.
  options:
    - use the same copy on both stores and accept that the iOS version is a promise, not a proof
    - write iOS-specific copy that says exactly what is checkable, and says who checks it
    - say nothing about the network on iOS and lead on "works offline"
  recommendation: >
    Option 2, and say the checkable thing out loud: "Arivu has no networking code. The build is open
    source and the release check refuses a build that links one." C5 is the commitment to being honest
    about what Arivu is; this is the first place where honesty costs a good sentence.
  if_rejected: GTM reuses the Android copy; note the weakening in leaves/NOTES.md so nobody rediscovers it.
```

### 16.3 Work items (for the Sequencing Leaf)

| Proposed | Title | Owner | Depends on | Note |
|---|---|---|---|---|
| Wxx | Write `PrivacyInfo.xcprivacy` from §3 and add it to the app target's resources | Engineering (iOS) | — | **Blocks the first TestFlight upload.** The file in §3 is ready to paste. |
| Wxx | Add `ITSAppUsesNonExemptEncryption=false` to Info.plist | Engineering (iOS) | — | One key; saves a questionnaire on every upload. |
| Wxx | iOS licences assets + About screen (licence-audit.md §7.4, I1) | Engineering (iOS) / Design | — | Reuse the Android texts verbatim; only `index.txt` changes. |
| Wxx | Choose `MinimumOSVersion` from the same measurement that sets D-009 | Engineering (iOS) | W02 | The App Store's only device filter (§12). |
| Wxx | Draft App Review Information notes (§11) | Compliance / GTM | D-010 | Four points; mostly a translation of the Play "App access" text. |
| Wxx | Apple Developer Program enrolment | Hari | D-020 (account-type thinking) | $99/yr; no tester gate; legal name is published for individual accounts. |
| Wxx | Run `tools/ios_release_check.sh` against the first real archive | Compliance | first iOS build | It has only ever run against a synthetic fixture. |
| Wxx | `tools/make_notice.py` (D-040) | Engineering | D-040 | Also relaxes `LicensesTest.noticeShippedInAppMatchesRootNotice`. |
