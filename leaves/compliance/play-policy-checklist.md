---
spine_version: 0.1
leaf: compliance
checked_on: 2026-09-15
artifact: android/app/build/outputs/bundle/release/app-release.aab (399,118,028 B at audit; final build 399,395,458 B per leaves/NOTES.md; versionCode 1, unsigned)
---

# Google Play submission checklist — Compliance Leaf

Status legend: **met** · **gap** (work to do before release) · **needs Hari** (a human call or Console action).
**BLOCKS** marks an item that, left as is, stops the app reaching production or is likely to fail review.
Source tags: **[V]** verified against the linked official page on 2026-09-15 · **[U]** unverified (memory,
inference or an interpretation — confirm in Play Console before relying on it).

Machine-checkable items are enforced by `tools/release_check.sh` (currently FAILS: placeholder report
address, D-001/D-010 pending, unsigned bundle). Everything below that says "Console" is not.

## Summary

| # | Policy | Status | Blocks release? | Spine |
|---|---|---|---|---|
| 1 | AI-generated content — in-app reporting | **gap** + needs Hari (D-021) | **BLOCKS** (review risk) | C9, C3 |
| 1b | AI-generated content — preventing restricted content | gap (no safeguard beyond model tuning) | review risk, not a hard block | C9, C5 |
| 2 | Data safety form | met in code; Console form to fill (answers below) | **BLOCKS** until submitted | C3, C9 |
| 3 | Privacy policy | **partly met** — in-app policy on About (Engineering, 2026-09-15); hosted URL pending D-022 | **BLOCKS** | C3, C9 |
| 4 | Foreground service (shortService) | met; confirm no declaration prompt in Console | no | C10 |
| 5 | Permissions (REQUEST_DELETE_PACKAGES, FOREGROUND_SERVICE) | met | no | C3, C6 |
| 6 | Target API level | met (36) | no | C1 |
| 7 | Target audience / Families | needs Hari (recommend 18+) | **BLOCKS** until declared | C9 |
| 8 | Content rating (IARC) | needs Hari (answers below) | **BLOCKS** until submitted | C9 |
| 9 | Developer verification + new-account testing | **needs Hari** — deadline 2026-09-30 | **BLOCKS** | C1 |
| 10 | 16 KB page size | met | no | C2 |
| 11 | Export compliance / encryption | met (no crypto; no Play declaration exists) | no | C1 |
| 12 | Play Asset Delivery size limits | met (397 MB pack) | no | C1 |
| 13 | App access / minimum functionality (gate vs reviewer devices) | gap — review notes needed | review risk | C6 |
| 14 | Other App content declarations (ads, advertising ID, news, health, financial, government) | met — answers below | Console | C3 |
| 15 | Signing / Play App Signing | gap — bundle unsigned | **BLOCKS** | C1 |

---

## 1. AI-generated content policy — in-app reporting

**Policy text [V]** ([AI-Generated Content policy, answer/13985936](https://support.google.com/googleplay/android-developer/answer/13985936)):
> "Apps that generate content using AI must contain in-app user reporting or flagging features that allow
> users to report or flag offensive content to developers **without needing to exit the app**."

**Scope [V]** ([Understanding the AI-Generated Content policy, answer/14094294](https://support.google.com/googleplay/android-developer/answer/14094294)):
in scope — "Text-to-text AI chatbot apps, in which the AI generated chatbot interaction is a central feature".
Arivu is squarely in scope (the chat *is* the product). The "summarizes non-AI content as its only feature" and
"productivity app improving an existing feature" exclusions do not fit: Arivu drafts free text.
The policy does not say whether reporting must be per-output, and says nothing about on-device models [V: absent].

**What Arivu has** — `android/app/src/main/java/io/github/brettleehari/arivu/app/ui/AboutScreen.kt:82-83` (section + "Report a reply"
button on the About screen) → `reportOutput()` at `AboutScreen.kt:156` fires `ACTION_SENDTO mailto:` to
`BuildConfig.REPORT_EMAIL`, falling back to an `ACTION_SEND` chooser. The body is a template; the user must copy
the offending reply themselves (`res/values/strings.xml:64,67`). Verified by
`android/app/src/test/java/io/github/brettleehari/arivu/app/ReportOutputTest.kt` (C9).

**Assessment — gap, BLOCKS (review risk).**
- *Leaves the app:* the email/share hand-off opens another app. Read literally, that fails "without needing to exit the app".
- *Two screens and a manual copy away from the output:* the user must go Chat → About → Report, then paste. A reviewer
  testing "can I flag this reply?" from the chat will not find it.
- *Destination is a placeholder* (`android/gradle.properties` `arivu.reportEmail=report@example.invalid`, D-010).

**The constraint:** without `INTERNET` (C3, the product's core claim), no report can reach the developer unless some
other app carries it. So the literal text cannot be met by any offline app; the achievable reading is "the
flagging act happens in-app, on the output, and the only external step is the unavoidable transport".
Recommended (D-021, needs Hari because it touches the single-screen scope):
1. A **"Report" action on every AI reply** (next to Copy) that opens an **in-app report sheet**: the reply text is
   pre-attached, a reason picker (offensive / sexual / dangerous / hateful / other) and an optional note.
2. "Send report" then hands a fully pre-filled message (recipient, subject, reply text, reason, version) to email,
   with the share sheet as fallback. Copy on the sheet says why: "Arivu cannot use the internet, so your email app sends it."
3. The flagged reply is marked "Reported" locally so the flag is visible in-app even if the user never sends.
4. Keep the About entry. Explain the mechanism in the Console "App access"/review notes.
Residual risk remains [U]: a reviewer may still reject the email hand-off. The only fully literal alternative is a
network call, which breaks C3 — not recommended.

## 1b. AI-generated content — preventing restricted content

**Policy [V]** (answer/13985936, answer/14094294): apps must prohibit **and prevent** generation of restricted
content, including content that exploits or abuses children and content enabling deceptive behaviour
(examples include "official documentation enabling dishonest conduct", bullying, malicious code).
**Arivu:** relies solely on Qwen3's alignment; `Policy.SYSTEM_PROMPT` (`Policy.kt:29`) sets task scope but has no
refusal guidance; no output filter. **gap, review risk.** Proposed: add refusal guidance to the system prompt, add a
red-team slice (CSAE, self-harm, weapons, forged official letters) to the W04 eval, record results. Decision
D-026. A keyword output filter is not recommended as the only measure (brittle across target languages).

## 2. User Data / Data safety form

**Rules [V]** ([Data safety, answer/10787469](https://support.google.com/googleplay/android-developer/answer/10787469)):
- "'Collect' means transmitting data from your app off a user's device."
- "User data accessed by your app that is only processed locally on the user's device and not sent off device does not need to be disclosed."
- "Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy."
- Sharing exemption: "Transferring user data to a third party based on a specific user-initiated action, where the user reasonably expects the data to be shared".

**Evidence that nothing leaves the device**
- No network permission in the shipped bundle: `AndroidManifest.xml:5` comment; merged-manifest dump shows only
  `FOREGROUND_SERVICE`, `REQUEST_DELETE_PACKAGES`, `io.github.brettleehari.arivu.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
  (`tools/check_manifest.sh`, run by `tools/release_check.sh`). No `com.google.android.gms.permission.AD_ID`.
- Conversation stored in app-private `filesDir/conversation.json` (`ArivuApp.kt`, `ChatRepository.kt:24`).
- Backup and device transfer off: `AndroidManifest.xml:17-18` (`allowBackup=false`), `res/xml/data_extraction_rules.xml` excludes every domain.
- No analytics, crash-reporting, ads or Firebase SDKs (dependencies: `android/app/build.gradle.kts` `dependencies {}`).
- Library components in the merged manifest (`androidx.startup` provider with emoji2/lifecycle/profileinstaller
  initializers; `ProfileInstallReceiver`, guarded by `android.permission.DUMP`) transmit nothing. EmojiCompat may
  request a font from the Google Play services font provider over IPC; no user data is involved [U].

**Form answers (App content → Data safety)**

| Question | Answer | Basis |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Nothing is transmitted by the app (no INTERNET). |
| Is all of the user data collected by your app encrypted in transit? | Not asked after "No" [U]; if shown: not applicable | — |
| Do you provide a way for users to request that their data is deleted? | Not asked after "No" [U]; if shown: users delete locally by uninstalling / clearing storage | — |
| Data types (Location, Personal info, Financial, Health, Messages, Photos, Audio, Files, Calendar, Contacts, App activity, Web browsing, App info & performance, Device IDs) | **none selected** | — |
| Independent security review badge | No | — |
| "Committed to follow the Play Families Policy" | No (not child-directed; see §7) | — |
| Privacy policy URL | **required — missing (§3)** | [V] |

**Interpretation needing Hari — the report email [U].** When a user sends a report, *their email app* transmits the
reply text and their email address to the developer. The app itself transmits nothing and the action is explicit
and user-initiated. Reading: not collection by the app → "No" stands. The conservative alternative is to declare
"Messages → Emails / Other in-app messages: collected, optional, user-initiated, purpose: app safety", which
costs the "No data collected" label (C3's cheapest credibility). Recommendation: answer "No", and describe report
emails explicitly in the privacy policy. Android vitals / Play pre-launch data are collected by Google Play, not by
the app, and are not declared [U].

## 3. Privacy policy

**Rule [V]** ([User Data policy, answer/9888076](https://support.google.com/googleplay/android-developer/answer/9888076)):
> "All apps must post a privacy policy link in the designated field within Play Console, and a privacy policy link
> or text within the app itself." It must be on "an active, publicly accessible and non-geofenced URL (no PDFs)"
> and include developer information and a privacy contact, data accessed/collected/used/shared, secure handling,
> and retention/deletion.

**Arivu:** no privacy policy anywhere in the repo; About has a two-line "Private by design" summary
(`strings.xml:61-62`). **gap, BLOCKS.**
Needed: (a) a hosted page (GTM/Hari — e.g. arivu.org/privacy if D-001 confirms the domain, or a GitHub Pages URL);
(b) the full text **inside the app** (an About section, readable offline — a link alone would open a browser the
user may not be able to load). Required content: developer name + contact; what is accessed (text typed/pasted,
model replies) and that it is processed and stored only on the phone, not backed up, removed on uninstall/clear
storage; what the developer receives if the user sends a report (reply text, note, app version, the sender's
email address), who reads it, retention period; no ads, analytics, accounts, or third-party sharing; not directed
at children. Account-deletion rules do not apply (no accounts) [V].

## 4. Foreground service — `shortService`

**Evidence:** `AndroidManifest.xml:39` `foregroundServiceType="shortService"`; `GenerationService.kt:37`
passes `FOREGROUND_SERVICE_TYPE_SHORT_SERVICE`; `onTimeout` stops (`GenerationService.kt:58`).
**Platform [V]** ([FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types)):
shortService needs only `FOREGROUND_SERVICE`, no type permission, no runtime prerequisites; ~3 min timeout;
must `stopSelf()` within seconds of `onTimeout`.
**Play [V]** ([Device and Network Abuse policy, answer/16559646](https://support.google.com/googleplay/android-developer/answer/16559646)):
use cases with "foreground service types systemExempted or shortService" are exempt from the FGS criteria; the
declaration form is to "describe the use case for each Foreground Services (FGS) permission used" — shortService
has no type-specific permission. The Help page [answer/13392821](https://support.google.com/googleplay/android-developer/answer/13392821)
does not mention shortService at all [V: absent], and the Android page tells targetSdk 34+ apps to declare types in
App content generally.
**Status: met; needs Hari to confirm in Console** that no FGS declaration is requested. If the form appears,
declare shortService: "Keeps a reply being written on-device alive for a brief app switch; user starts it by
pressing Send; stops on the last token or Stop." Not blocking.

## 5. Permissions

- `REQUEST_DELETE_PACKAGES` (`AndroidManifest.xml:13`, used by `IncompatibleScreen.kt:85` `ACTION_DELETE` for the
  app's own package, D-006): **not** on Play's sensitive/restricted list. The [Permissions and APIs that Access
  Sensitive Information policy (answer/9888170)](https://support.google.com/googleplay/android-developer/answer/9888170)
  requires declaration forms for SMS/Call Log, background location, `QUERY_ALL_PACKAGES`,
  `MANAGE_EXTERNAL_STORAGE`, `REQUEST_INSTALL_PACKAGES`; `REQUEST_DELETE_PACKAGES` is not mentioned [V].
  Normal-protection permission, no prompt [U: platform, not re-fetched]. **met.**
- `FOREGROUND_SERVICE`: normal, see §4. **met.**
- `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`: AndroidX-generated signature permission. **met.**
- No `INTERNET`, no `AD_ID`, no `POST_NOTIFICATIONS`, no `QUERY_ALL_PACKAGES` — enforced by `tools/check_manifest.sh`.

## 6. Target API level

**Rule [V]** ([answer/11926878](https://support.google.com/googleplay/android-developer/answer/11926878)):
"Starting August 31, 2026: New apps and app updates must target Android 16 (API level 36) or higher" (extension
to November 1, 2026 on request). **Arivu:** `android/app/build.gradle.kts:17` `targetSdk = 36`; bundle manifest
`targetSdkVersion="36"`. **met**; `release_check.sh` asserts ≥ 36.

## 7. Target audience and Families

**Rule [V]** ([Families policies, answer/9893335](https://support.google.com/googleplay/android-developer/answer/9893335)):
obligations apply "If one of the target audiences for your app is children"; including under-13 brings Families
requirements (Families Self-Certified Ads SDKs only, no transmitting device identifiers, privacy policy covering
children, restrictions on data practices); the declared audience can be overridden by Play if imagery/terminology
appeals to children. No explicit extra AI rules on that page [V: absent]; no restrictions stated for 18+ only.

**Recommendation (needs Hari): target age group 18+ only; "Appeals to children": No.**
Justification: the Spine persona is an adult professional (SPINE §2); the model is a small general chatbot with no
output filter and cannot guarantee child-appropriate replies, which is exactly what Play expects of child-directed
apps and would make §1b a hard requirement; Arivu has no ads or identifiers, so the only thing an under-13 audience
buys is policy exposure. Declaring 18+ does not block installs by younger users but sets the review bar correctly.
16–17 could be added later with the §1b safeguards in place. **If under-13 were included:** Families policy
applies in full, Teacher Approved/Families badges become relevant, the AI content bar rises sharply, and the
store listing, icon and copy would be reviewed for child appeal — not recommended for iteration-1.

## 8. Content rating (IARC questionnaire)

**Rule [V]** ([answer/9898843](https://support.google.com/googleplay/android-developer/answer/9898843)): all apps
need an IARC rating; "Misrepresentation of your app's content may result in removal or suspension"; resubmit when
features change. The exact current question wording was **not** retrievable [U] — answer in Console against
these facts:

| Topic | Answer | Note |
|---|---|---|
| Category | Not a game; utility / productivity ("All other app types" or nearest equivalent) [U] | |
| Violence, blood, sexual content, nudity, profanity, drugs/alcohol/tobacco, discrimination, fear/horror in *designed* content | No | The app ships no such content. |
| Gambling / simulated gambling | No | |
| Users can interact or exchange content with other users | No | Single-user, offline. |
| Shares user's location with others | No | |
| Shares personal information with third parties | No | |
| Digital purchases | No | Free, no IAP. |
| Unrestricted internet / web browser | No | No INTERNET permission. |
| Generated / AI content, or content not reviewed by the developer (if asked) | **Yes** — describe: "on-device text model writes replies to user prompts; output is unfiltered beyond model tuning; in-app report" | Answer honestly; misstatement risks removal. |

Expected outcome [U]: a low age rating (e.g. Everyone/PEGI 3/USK 0) unless the generative-content question raises
it; accept whatever IARC assigns — it does not conflict with an 18+ target audience.

## 9. Developer verification and new-account testing

**Verification [V]** ([developer.android.com/developer-verification](https://developer.android.com/developer-verification)):
"September 30, 2026 — Regional deadline in Brazil, Indonesia, Singapore, and Thailand" for participating stores
including Google Play; global rollout 2027. "Google Play automatically registers 99% of apps. Use Play Console to
manually register remaining apps or those distributed outside Google Play."
Note: leaves/BRIEF.md says enforcement "began" 2026-09-30 — as of today (2026-09-15) it is **15 days away**.
**needs Hari, BLOCKS for BR/ID/SG/TH installs:** complete Play Console identity verification now; after the first
upload confirm the package shows as registered.

**Closed-testing requirement [V]** ([answer/14151465](https://support.google.com/googleplay/android-developer/answer/14151465)):
personal developer accounts created after 2023-11-13 must run a closed test with "a minimum of 12 testers who have
been opted in continuously for at least 14 days" before applying for production access. The page does not state
the organisation-account position [V: absent]. **needs Hari:** which account type? If personal and new, production
is ≥ 14 days after 12 testers opt in — the longest pole in the Play slice.

## 10. 16 KB page size

**Rule [V]** ([page sizes](https://developer.android.com/guide/practices/page-sizes)): apps targeting API 35+ with
native code must support 16 KB pages on 64-bit devices; the page names 2027-02-01 as the date updates without
support can no longer be released. **Arivu:** NDK 29 (`android/llama/build.gradle.kts:11`),
`-Wl,-z,max-page-size=16384` (`android/llama/src/main/cpp/CMakeLists.txt:35`); all 13 `.so` in the AAB have
LOAD align 0x4000 (checked from the AAB by `tools/release_check.sh` step 5; leaves/NOTES.md). Native libs are compressed
and extracted (`useLegacyPackaging = true`, `extractNativeLibs="true"`), so 16 KB zip alignment of `.so` entries
does not apply; the page notes this costs install size [V]. The model asset's own alignment is D-013/W18. **met.**

## 11. Export compliance / encryption

Play has no encryption declaration; the Help page only warns apps "may be subject to US export laws" and defers to
BIS [V] ([answer/113770](https://support.google.com/googleplay/android-developer/answer/113770)). Arivu implements
no cryptography and makes no network connections; the source is public under Apache-2.0 [U: EAR classification is
a legal reading — publicly available open-source software without encryption functionality is generally outside
EAR]. **met; no action.** Revisit if iteration-2 adds signature verification UI (hashing only, still not 5D002 [U]).

## 12. Play Asset Delivery size limits

**Limits [V]** ([answer/9859372](https://support.google.com/googleplay/android-developer/answer/9859372)):
base module 500 MB; individual asset pack 1.5 GB; "Cumulative total for all modules and install-time asset packs"
4 GB; users on mobile data see a non-blocking dialog above 200 MB. Install-time packs are served as split APKs and
need ~2× their size free at install [V] ([asset delivery](https://developer.android.com/guide/playcore/asset-delivery)).
**Arivu:** modelpack 396,705,472 B install-time (`android/modelpack/build.gradle.kts:9`), base+arm64 ≈ 6.9 MB. **met.**
**Finding:** leaves/BRIEF.md and D-004 state an install-time limit of **1 GB**; the current Help Center table says **4 GB**
cumulative / 1.5 GB per pack. The 1.7B Q4_K_M (1,107,409,472 B) would fit. D-004's premise needs correcting
(Engineering/Hari). Also: Amaka on mobile data sees the >200 MB warning — GTM copy should say "install on Wi-Fi".

## 13. App access / minimum functionality vs the compatibility gate

Reviewers and pre-launch-report devices below 3.3 GiB totalMem, or flagged low-RAM, see only the incompatible
screen (C6, `IncompatibleScreen.kt`) — which can read as "broken app" [U]. **gap, review risk.** In App content →
App access, state: "All functionality is available without login. Requires an arm64 device with ≥ 4 GB RAM
(reports ≥ 3.3 GiB); on smaller devices the app deliberately shows a one-screen explanation and uninstall button."
Layer-2 device exclusion (D-009, W19) should be set *before* review so Play does not offer the app to such devices.

## 14. Other App content declarations [U: list from Console memory]

| Declaration | Answer |
|---|---|
| Ads | No ads |
| Advertising ID (targetSdk 33+) | Does not use advertising ID (no `AD_ID` permission in merged manifest [V: bundletool dump]) |
| App access | All functionality available without special access (+ device note, §13) |
| Government app | No |
| Financial features | None |
| Health | Not a health app |
| News app | No |
| Data safety / Target audience / Content rating | §2, §7, §8 |

## 15. Signing

`app-release.aab` has no `META-INF/*.RSA|EC` signature — it cannot be uploaded. Enrol in Play App Signing with an
upload key (W17); the key custody matters for iteration-2 (leaves/BRIEF.md "Guard the signing key"). **gap, BLOCKS**;
checked by `tools/release_check.sh` step 8.
