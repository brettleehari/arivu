---
spine_version: 0.2
leaf: gtm
artifact: Google Play store listing, v0.1.0
scope: Google Play only. The Apple App Store listing is `appstore-listing.md`; the shared argument is `positioning.md`.
---

# Store listing — Arivu v0.1.0 (Google Play)

## Reconciled to Spine 0.2 — what iOS changes here, and what it does not

Spine 0.2 puts iOS in scope (R7 withdrawn, C11: one product, two platforms). **Almost nothing in this
file changes**, which is the point: the Play listing describes the same product it always did, and the
platform-specific parts of it are exactly the parts that were always Android-specific.

What changed, and only this:

1. **This listing stays Android-only in its wording, and does not mention the other platform.** Apple's
   metadata rules forbid naming another platform in the App Store listing (Guideline 2.3.10), and the
   symmetric silence here costs us nothing — the repo and any website carry both. Proposed decision
   **D-GTM-E**.
2. **The privacy claim in this listing stays exactly as strong as it is.** "Arivu has no permission to
   use the internet" is true on Android, provable by the operating system, and checked by
   `tools/check_manifest.sh` on every build (M5). It does **not** get softened to match iOS, and it does
   **not** get copied to iOS. `positioning.md` §7 has the iOS wording and the list of banned sentences.
3. **Three new must-not-claim items** (13–15 below) cover the two-platform traps.
4. **Two fields now have an Apple counterpart** that must stay consistent even though they are filled in
   separately: target audience / content rating (see D-GTM-H in `appstore-listing.md`) and the Data
   safety form versus Apple's App Privacy card. W-GTM-i5 reads all four privacy artefacts side by side
   before either submission.
5. **The download size, the RAM floor and the uninstall offer are Android facts.** The App Store listing
   must not reuse any of the three. They stay here, unchanged.

Everything else — the name, the short and full descriptions, the claim-by-claim table, the category,
the D-017 quality risk, the compliance items — is unaffected by iOS and is left as it was.

---

Plain English, short sentences, no idioms: many readers use English as a second language.
Every claim below points at the code or Spine commitment that makes it true. Character counts are
Python `len()` on the exact text (Unicode code points, newlines counted as 1), measured 2026-09-15.
Limits verified against Play Console Help, "Create and set up your app" (answer 9859152):
name 30, short description 80, full description 4000.

## App name — 29 / 30

```text
Arivu: Offline Writing Helper
```

- In-app launcher name stays `Arivu` (`app_name`). The listing title adds what it is, because "Arivu"
  alone says nothing to someone searching in Lagos or Manila.
- No "Free", "AI", "Best" or "#1" in the title: Play metadata policy bans price, promotion and ranking
  signals in the title, icon and developer name.
- Fallbacks if the name is taken or reads badly in review: `Arivu: Offline Writing Help` (27),
  `Arivu - Writing Help, No Internet` (32 — too long, do not use).

## Short description — 79 / 80

```text
Rewrite, shorten, explain and summarise text on your phone. No internet needed.
```

Same verbs as the About screen `about_good_body`. It names tasks, not quality; see the D-017 quality risk
below. If W04 shows rewriting is unreliable, swap "Rewrite, shorten" for "Shorten" and recount. "Translate" is left out on
purpose: strings.xml does not promise it, and D-017 has no evidence for target languages yet.

## Full description — 2570 / 4000

```text
Arivu helps you with text. A letter you need to write. A message you want to make shorter or clearer. A notice you need to understand today.

It works with no internet. The AI model comes inside the app and runs on your phone. After you install Arivu, it does not use your mobile data.

What you can ask Arivu to do
• Explain a paragraph in simple words
• Summarise a notice, circular or letter
• Make long text shorter
• Rewrite your text in a different way
• Draft a short letter or message from your notes

Read every reply before you use it. Arivu is small, so even with your own text it can miss the point, repeat your words back, or change a detail.

What Arivu is not good at
Arivu uses a small AI model. It is not good at facts, news, dates, numbers, maths, or medical and legal questions. It can sound sure and still be wrong. Check anything important. Arivu works best on text you give it, not on questions it must answer from memory.

Private, because it cannot go online
• Arivu has no permission to use the internet.
• Your conversation is stored only on this phone, in the app's private storage. It is not included in phone backups.
• No account and no sign-in. No ads. No analytics or tracking.
• If a reply is harmful, tap Report under it. Arivu opens your own email app with that reply ready to send. Nothing is sent unless you send it.
• The full privacy policy is inside the app, on the About screen, so you can read it offline.

Simple on purpose
There is one screen. Type or paste your text and tap Send. Tap Stop at any time. Tap Copy to use the reply in another app. There are no settings to learn.

Arivu can only hold a certain amount of conversation at once. When older messages no longer fit, Arivu shows a line where its memory stops. It does not forget without telling you.

Before you install
• The download is about 400 MB, because the AI model is inside the app. Use Wi-Fi if you can.
• Arivu needs a 64-bit phone with Android 11 or newer and about 4 GB of memory or more.
• Speed depends on your phone. Replies appear word by word.
• If your phone cannot run Arivu well, Arivu will not start. It tells you why and helps you uninstall it.
• The app's screens are in English. You can write to Arivu in other languages, and it will try to reply in the same language. Check the result carefully.

Open source
Arivu is free, with no in-app purchases. The app is open source under the Apache 2.0 licence. The AI model is Qwen3 0.6B (Apache 2.0), and it runs with llama.cpp (MIT). All licences are listed inside the app.
Source code: [REPO_URL]
```

### Claim-by-claim check

| Claim in the description | Why it is true today | Spine | Depends on |
|---|---|---|---|
| Works with no internet; model inside the app | Install-time Play Asset Delivery pack `:modelpack` (`app/build.gradle.kts`); no `INTERNET` permission | C1, C2, C3 | — (on iOS the same claim is true, but the *evidence* differs — `positioning.md` §7) |
| Does not use your mobile data after install | No network permission in any manifest; `tools/check_manifest.sh` fails on INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_NETWORK_STATE | C3, M5 | Play Store's own updates are not Arivu (see privacy policy) |
| Task list ("What you can ask Arivu to do") | Same verbs as `about_good_body` and `empty_body`, framed as tasks, not as quality | C5 | **D-017 quality risk, see below** |
| "Read every reply… can miss the point, repeat your words back, or change a detail" | Capture log 2026-09-15: polite rewrite echoed the input 6/6 tries; circular summary said "two school terms" for a one-term trial | C5 | Keep until the W04 eval shows otherwise |
| Not good at facts, news… | Word-for-word from `about_bad_body` | C5 | — |
| Stored only on this phone, not in backups | `filesDir/conversation.json` (`ArivuApp.kt`); `allowBackup=false`, `fullBackupContent=false`, `data_extraction_rules.xml` excludes every domain from cloud backup and device transfer | C3 | — |
| No account, no ads, no analytics or tracking | Dependency list in `app/build.gradle.kts` and `libs.versions.toml`: no ads, analytics, crash or billing SDK | C1, C3 | Keep true: any new dependency must be checked |
| Report under a reply; opens your email app with that reply; nothing sent automatically | `ui/ReportOutput.kt`: in-app `ReportSheet` (reason chips, optional note), marks reply `reported`, then `ACTION_SEND` with `mailto:` selector, share-sheet fallback; body has reason, note, reply text, version | C9 | D-010 address; **Hari's approval of the per-reply Report scope change** — if rejected, revert to the About-screen wording |
| Privacy policy inside the app, readable offline | About → "Privacy policy" (`about_privacy_policy`, `privacy_*` strings) | C3, C9 | Wording must stay in step with `privacy-policy.html` (diffs listed in the GTM report) |
| One screen, Send / Stop / Copy / Report (Report pending D-021), no settings | `ChatScreen.kt`, `Policy.kt` | C8, C10 | — |
| Shows a line where memory stops | `context_divider` | C7 | — |
| About 400 MB download | Release AAB 399,118,011 B, model pack 396.7 MB (leaves/NOTES.md). Play's device-specific download is not measured yet | C1 | W18: read real size in App bundle explorer; change the number if it differs by more than 10% |
| 64-bit, Android 11+, about 4 GB memory | `abiFilters arm64-v8a`, `minSdk 30`, `arivu.minTotalRamBytes` = 3.3 GiB (provisional) | C2, C6 | **D-009 / W03** — if the floor moves above a "4 GB" phone, change this line |
| Will not start on a phone it cannot serve | Gate layer 3, `incompatible_*` strings, no continue-anyway | C6 | W10 on-device check |
| Screens in English; replies try to match your language | `strings.xml` English only (D-014); system prompt "Reply in the language the user writes in" (`Policy.kt`) | C5 | D-014; D-017 non-English eval |
| Free, no in-app purchases; licences | No billing dependency; `assets/licenses/index.txt` | C4 | — |

## Category, tags, contact

| Field | Value | Note |
|---|---|---|
| App or game | App | |
| Category | **Productivity** | Education was considered: Amaka is a teacher, but the app is for adults' own text, and "Education" invites a children's audience we have not designed for (see proposed decision on target age). |
| Tags (Play Console, up to 5, chosen from Google's list) | Candidates: Writing, Productivity, Documents — **pick the nearest names from the Console list at W19**; tag names not verified from here | Do not pick "Chatbot/AI assistant"-style tags if they promise open-domain Q&A |
| Contact email (public on the listing) | `[CONTACT_EMAIL — decisions.yml D-010]` | Play shows this publicly. Recommend the same monitored mailbox as `arivu.reportEmail`, so harmful-output reports and listing contacts land in one place someone reads. |
| Website | `[REPO_URL]` or the privacy-policy host | Optional field |
| Privacy policy URL | `[PRIVACY_POLICY_URL]` — see `privacy-policy.html` | Required even for apps that collect nothing (verified) |
| Ads | "No, my app does not contain ads" | True: no ads SDK |
| Content rating (IARC) | Answer questionnaire honestly: user-generated/AI-generated text, no user-to-user sharing, no purchases | Compliance owns the answers. Apple's age rating is a **separate** questionnaire with different tiers (4+/9+/13+/16+/18+ since 2026); the two must not contradict each other — see D-GTM-H in `appstore-listing.md` |
| Target audience | `[DECISION — proposed below]` | |

## What we must NOT claim

In the listing, screenshots, feature graphic, release notes, social posts and anything sales/marketing
extracts from this Leaf:

1. **No speed or memory numbers.** Not "fast", not "instant", not "X words per second", not "runs on any
   phone". M1–M4 are targets; leaves/NOTES.md W02 is empty. "Speed depends on your phone" is the only speed line.
2. **No accuracy claims.** Not "accurate", "correct answers", "smart", "knows everything", "your personal
   tutor", "ask anything". The product is "not an offline oracle".
3. **No health, legal, financial or exam advice claims.** Not "understand your medical results", "check your
   contract", "pass WAEC/JAMB". The model is bad at exactly these (`about_bad_body`).
4. **No rewrite-quality promise.** Not "makes your writing polite / professional / perfect", "fixes your
   grammar", "writes like a pro". The 2026-09-15 capture shows the model echoing a polite-rewrite request 6/6
   times (D-017). Name rewriting as a task you can ask for, never as an outcome.
4b. **No translation promise.** Not "translate into Yoruba/Tagalog/…" until D-017's non-English eval passes.
5. **No store-performance or price-promotion language.** No "best", "#1", "top", "popular", "new",
   "Editor's choice", award icons, "free for a limited time". (Play metadata policy.)
6. **No testimonials, user counts or ratings we do not have.** The quotes in leaves/SPINE.md §1 are *hypotheses*,
   never customer quotes. No "trusted by teachers" until someone real says so, with permission and attribution.
7. **No keyword stuffing.** No lists of country names, languages or competitor names ("ChatGPT offline").
8. **No absolute privacy overreach.** Say "has no permission to use the internet" and "stored only on this
   phone". Do not say "100% secure", "unhackable", "encrypted" (the file is not encrypted beyond Android's
   own app-sandbox and device encryption), or "anonymous" (we receive the sender's address if they email a report).
9. **No sharing / offline-transfer promise.** Phone-to-phone sharing is iteration-2 (R1).
10. **No emojis, ALL CAPS headings or repeated special characters** in listing text.
11. **No "zero data" claim about Google Play itself.** Downloading and updating from Play uses data; Arivu
    using none after install is the claim.
12. **No endorsement by Alibaba/Qwen, Google, or llama.cpp.** Name them only as licensed components.
13. **No cross-platform copy in either store listing.** This listing does not mention iPhone or the App
    Store; the App Store listing does not mention this platform (Apple Guideline 2.3.10). Cross-platform
    availability belongs on the website and in the repo, not in store metadata.
14. **Never carry this listing's privacy sentence to the App Store.** "Has no permission to use the
    internet" is an Android fact. The approved iOS wording is in `positioning.md` §7, and the word
    "cannot" is banned there. The reverse also holds: do not weaken this listing to match iOS.
15. **No device-profile feature claims on either store.** Never "on newer phones you also get…". A
    larger device profile (C11) changes how well and how much, never what the user can ask for. The only
    public sentence about the ceiling is that how much text Arivu can hold depends on the phone.

## D-017 quality risk (do not hide)

The Spine promises rewriting (C5, `about_good_body`), and the listing still names it. But the screenshot capture
on 2026-09-15 (release build, emulator, `screenshots/CAPTURE-LOG.md`) shows the 0.6B model **failed the
headline rewrite task**: "Rewrite this to sound polite: …" returned the input unchanged or nearly unchanged in
3/3 tries, and the backup input produced polite-sounding text that reversed who was late in 3/3 tries. The
summary of the circular also got a detail wrong ("two school terms" for a one-term trial).

What this Leaf changed because of it:
- "What Arivu does well" became "What you can ask Arivu to do". Explain and summarise are listed first, and
  rewrite is described neutrally ("in a different way"), with no "polite, clear or formal" quality claim.
- The description now says to read every reply, and names the three failure modes we saw.
- No polite-rewrite screenshot is uploaded (see `screenshot-shotlist.md`).

What it does not fix: if W04 finds rewriting unreliable, the in-app `about_good_body` and the empty-state
example chip "Rewrite this to sound polite: …" promise more than the model delivers. That is a Spine/Design
question for Hari (D-017), not a copy tweak.

## Compliance items (status after this round)

**R-AI — reporting "without needing to exit the app."** The Play AI-Generated Content policy (verified
2026-09-15, Play Console Help answers 13985936 and 14094294) requires in-scope apps to let users "report or flag
offensive content to developers without needing to exit the app." Engineering added a per-reply Report sheet:
the user chooses a reason and the reply is marked "Reported" inside the app, and only then does the email app open.
This is the strongest position available without a network. It is **pending Hari's approval as a Spine scope
change**. Compliance still has to judge whether the email hand-off is acceptable.

**R-PP — privacy policy inside the app.** Now present: About → Privacy policy (`privacy_*` strings), readable
offline. The Console URL (`privacy-policy.html`, hosted) is still needed.
