---
spine_version: 0.2
leaf: gtm
artifact: Apple App Store listing, v1.0.0 (iPhone)
status: draft. The iOS app is in development and has NOT been submitted. Every number marked [PENDING] stays a placeholder until Engineering measures it.
---

# App Store listing — Arivu (iPhone)

Companion to `store-listing.md` (Google Play). **One product, two platforms (Spine C11):** the two
listings say the same thing about the same app, and differ only where the platforms differ. Every
difference below is traceable to a real one — see `positioning.md` §3 for the rule and §7 for the
privacy wording, which is the one place the Android copy must never be reused.

Plain English, short sentences, no idioms: many readers use English as a second language.
Character counts are Python `len()` on the exact text (Unicode code points, newlines counted as 1),
measured 2026-09-15. Byte counts are UTF-8, because Apple's own pages disagree about which one the
keyword field uses (see below).

## Field limits — verified 2026-09-15

| Field | Limit | Status | Source |
|---|---|---|---|
| App name | 30 characters (min 2) | **Verified** | App Store Connect Help, *App Information* (`developer.apple.com/help/app-store-connect/reference/app-information/`); Review Guideline 2.3.7 repeats "limited to 30 characters" |
| Subtitle | 30 characters, optional | **Verified** | Same ASC Help page |
| Promotional text | 170 characters, optional, **editable without submitting a new version** | **Verified** | ASC Help, *Platform Version Information*; `developer.apple.com/app-store/product-page/` |
| Description | 4000 characters, required, plain text (no HTML), changed only with a new version | **Verified** | ASC Help, *Platform Version Information* |
| Keywords | **100 bytes** per ASC Help; **100 characters** per Apple's marketing pages. Identical for ASCII | **Verified, with a documented conflict between Apple's own pages** | ASC Help *Platform Version Information* ("up to 100 bytes") vs `developer.apple.com/app-store/search/` ("limited to 100 characters") |
| Keywords format | Comma-separated, **no space after a comma**; spaces allowed *inside* a phrase | **Verified** | `developer.apple.com/app-store/search/`: "terms separated by commas and no spaces… You can use spaces to separate words within keyword phrases" |
| Keywords: do not repeat | App name, subtitle and category are already indexed — do not repeat those words | **Verified** | `developer.apple.com/app-store/search/`; Apple Tech Talk 110358 |
| What's New | 4000 characters — **and not available for a first version** | **Verified** | ASC Help: "isn't available for the first version of the app but required for all subsequent versions" |
| Support URL | **Required**, and "must lead to actual contact information (legal address, email address, telephone number), as may be required by local law" | **Verified** | ASC Help, *Platform Version Information* |
| Marketing URL | Optional | **Verified** | Same page |
| Privacy policy URL | Required for iOS apps | **Verified** | ASC Help, *App Information* |
| Screenshots | 1–10 per size, JPEG/PNG, **no alpha channel** | **Verified** | ASC Help, *Screenshot specifications* |
| Age ratings | Tiers are now **4+, 9+, 13+, 16+, 18+** (12+ and 17+ are legacy) | **Verified** | ASC Help, *Age ratings: values and definitions*; Apple Developer News 2025-07-24 (`?id=ks775ehf`) |
| Other-platform names in metadata | Forbidden — **the word "Android" cannot appear anywhere in this listing** | **Verified** | Review Guideline 2.3.10 |
| Prices / unverifiable claims in metadata | Guideline 2.3.7; misleading marketing 2.3.1(a); "avoid including specific prices in your app description" | **Verified** | `developer.apple.com/app-store/review/guidelines/` (last updated 2026-06-08); `developer.apple.com/app-store/product-page/` |
| Beta / test wording | "Demos, betas, and trial versions… don't belong on the App Store" (2.2) | **Verified** | Review Guidelines |
| Screenshots must suit 4+ | Guideline 2.3.8: icons, screenshots and previews must adhere to a 4+ age rating even if the app is rated higher | **Verified** | Review Guidelines |

**Unverified, do not repeat as fact:** widely circulated claims that Apple's June 2026 guidelines
require AI features to be labelled, require human review of generative output, or mandate a report
button for AI content. **That text is not in Apple's guidelines.** The real hooks are 1.2
(user-generated content and moderation, which turns on content being *shared between users* — Arivu
shares nothing) and 4.7/4.7.1 (software not embedded in the binary — our model *is* embedded).
We ship the Report path anyway, because Play requires it and because it is one product.

---

## App name — 8 / 30

```text
Arivu AI
```

RESERVED IN APP STORE CONNECT ON 2026-09-23, which is what makes this the name rather than the
better one below. `Arivu` alone is taken — it is a common Tamil word, so that was always likely —
and Apple offers a trademark-dispute route that needs registered rights nobody here holds and takes
weeks regardless.

What this costs, recorded so it is not rediscovered later:

- It no longer matches the Play title (`Arivu: Offline Writing Helper`), breaking the "one product,
  one name" rule this section used to state. Play titles do not have to be globally unique, so the
  fix is to take `Arivu AI` there too when the Play listing is created.
- 22 of 30 characters are unused, and the descriptor that used to carry search weight has gone with
  them. The subtitle now does that work alone.

What it does not cost: the home screen still says **Arivu**. `CFBundleDisplayName` is a separate
field with no uniqueness requirement, and it is unchanged. And unlike the bundle id (D-001) the
store name can be changed in a later version, so this is reversible if `Arivu` is ever released.

No price, no superlative, no competitor, no other platform.

## Subtitle — 27 / 30

```text
Explain, summarise, rewrite
```

Three verbs, no quality claim — the same discipline as the Play short description, and the same
reason (D-017: we name tasks, never outcomes). It is also search text: Apple indexes the subtitle,
so it carries three terms the name does not.

Spelling note: the body copy uses British spelling throughout (matching the Play listing and Wave A
markets). "summarize" therefore appears in the keyword field instead. [U] Whether Apple's search
treats the two spellings as one term is not documented by Apple; we spend the bytes rather than guess.

Rejected: "Explain, summarise and rewrite" (30/30 — no margin), anything containing "AI assistant"
(invites the open-domain expectation C5 exists to refuse), anything with "free" (2.3.7).

## Promotional text — 167 / 170

```text
Paste a letter, a notice or your draft. Arivu explains it, shortens it or rewrites it, on your phone, with no internet. Read every reply: it is small and can be wrong.
```

This is the only field that can be changed without submitting a new build, which makes it our
**correction channel**: if the D-017 eval says rewriting is unreliable, this line changes the same
day, without a release. Apple states promotional text does **not** affect search ranking, so no
keywords are stuffed here.

## Description — 2942 / 4000

```text
Arivu helps you with text. A letter you need to write. A message you want to make shorter or clearer. A notice you need to understand today.

It works with no internet. The AI model comes inside the app and runs on your iPhone. After you install Arivu, it does not use your mobile data.

What you can ask Arivu to do
• Explain a paragraph in simple words
• Summarise a notice, circular or letter
• Make long text shorter
• Rewrite your text in a different way
• Draft a short letter or message from your notes

Read every reply before you use it. Arivu is small, so even with your own text it can miss the point, repeat your words back, or change a detail.

What Arivu is not good at
Arivu uses a small AI model. It is not good at facts, news, dates, numbers, maths, or medical and legal questions. It can sound sure and still be wrong. Check anything important. Arivu works best on text you give it, not on questions it must answer from memory.

Private, and here is how you can check
Arivu does not use the internet. There is no account, no sign-in and no server. On iPhone an app cannot prove that by giving up a permission, because iOS has no such permission to give up. So here is what we can show you instead:
• Arivu's source code is public, and there is no networking code in it.
• You can settle it yourself in ten seconds. Turn on Airplane Mode and use Arivu normally. Nothing changes, because nothing was being sent.
• This app's privacy card on the App Store says Data Not Collected.

Your conversation stays in Arivu's private storage on this iPhone. There is no advertising, no analytics and no tracking in the app. If a reply is harmful, tap Report under it. Arivu opens your own mail app with that reply ready to send, and nothing is sent unless you send it. The full privacy policy is inside the app, on the About screen, so you can read it with no internet.

Simple on purpose
There is one screen. Type or paste your text and tap Send. Tap Stop at any time. Tap Copy to use the reply in another app. There are no settings to learn.

Arivu can only hold a certain amount of conversation at once. When older messages no longer fit, Arivu shows a line where its memory stops. It does not forget without telling you. How much it can hold depends on your iPhone.

Before you install
• The download is about 1039 MB MB, because the AI model is inside the app. Use Wi-Fi if you can.
• Arivu needs 17.0 or newer, on 3.5 GB.
• Speed depends on your iPhone. Replies appear word by word.
• If your iPhone cannot run Arivu well, Arivu tells you and does not start.
• The app's screens are in English. You can write to Arivu in other languages, and it will try to reply in the same language. Check the result carefully.

Open source
Arivu is open source under the Apache 2.0 licence. The AI model is Qwen3 0.6B (Apache 2.0), and it runs with llama.cpp (MIT). All licences are listed inside the app.
Source code: https://github.com/brettleehari/arivu
```

### What changed from the Play description, and why

| Change | Reason |
|---|---|
| "your phone" → "your iPhone" throughout | Guideline 2.3.10 forbids naming other platforms; the app is iPhone-only at launch |
| The whole privacy section rewritten | `positioning.md` §7. The Android sentence ("no permission to use the internet") is **false on iOS** and is replaced by source + label + the Airplane Mode test, in that order of strength |
| "Private, because it cannot go online" → "Private, and here is how you can check" | Same. The word "cannot" is banned in iOS copy |
| "helps you uninstall it" → "tells you and does not start" | An iPhone app cannot offer to uninstall itself (`leaves/architecture/ios-port.md`) |
| "64-bit phone with Android 11 or newer and about 4 GB of memory" → `17.0`, `3.5 GB` | There is no App Store device-exclusion catalogue. The floor is a minimum iOS version plus the runtime gate. **The Android RAM number must not be carried across** |
| "about 400 MB" → `1039 MB` | The 400 MB figure is a measured Android artifact size. Measuring the iOS download is W-GTM-i2. **No number ships until it is measured** |
| "free, with no in-app purchases" dropped | Price terms in metadata: Guideline 2.3.7, plus Apple's advice to keep prices out of the description. The price field already says it |
| "Report… opens your email app" → "your own mail app" | The iOS hand-off is the system mail composer / share sheet |

### Placeholders that block submission

| Placeholder | Filled by | Blocks |
|---|---|---|
| `1039 MB` | W-GTM-i2, measured on a device. Expect a figure near the Android one: `leaves/architecture.md` §4.4 chose to **bundle the model in the app** rather than use On-Demand Resources, precisely so that no app code ever fetches anything — the same property the Play asset pack gives us. Do not write "400" from the Android measurement; measure it | Submission |
| `17.0`, `3.5 GB` | **Hari.** `leaves/architecture.md` §11 is explicit that "the iOS minimum version is a product decision, not a build setting": it is the only pre-install filter the App Store has, and setting it loosely means charging someone a large download to reach a wall. It is the counterpart of D-009 and it needs an answer before this listing can be finished | Submission |
| `https://github.com/brettleehari/arivu` | D-035 (resolved: `github.com/brettleehari/arivu`) — write the final URL in | Submission |
| `Qwen3-1.7B-Q4_K_M` in the review notes | The shipped profile. Iteration-1 ships one profile, `compact` (Qwen3 0.6B Q4_K_M), on both platforms — `leaves/architecture.md` §2.8, §3.4 | Submission |

**The download size is copy, not an apology** (`leaves/architecture.md` §4.4): the model is inside the
app, so it never needs the internet again; install on Wi-Fi. Note that iOS warns before a large
download over cellular, as Play does above 200 MB — [U] the current iOS threshold and whether the user
can override it in Settings is not verified here, so the listing says "Use Wi-Fi if you can" and names
no number.

Every other claim in the description is already checked line by line in `store-listing.md`
("Claim-by-claim check"). Those rows hold on iOS **except** the three the table above replaces; when
`store-listing.md` changes, this file is re-checked in the same pass.

## Keywords — 99 / 100 characters, 99 / 100 bytes

```text
summarize,shorten,simplify,draft,letter,notes,study,teacher,private,no internet,local ai,plain text
```

Terms: summarize · shorten · simplify · draft · letter · notes · study · teacher · private ·
no internet · local ai · plain text

- **Nothing here repeats the name, subtitle or category** (arivu, offline, writing, helper, explain,
  summarise, rewrite, productivity), because Apple already indexes those.
- **No competitor names, no trademarks, no "best"/"#1"** — `store-listing.md` rule 5 and 7, and
  Apple's own: "Improper use of keywords is a common reason for App Store rejections."
- **"grammar" and "proofread" are deliberately absent.** Both imply a quality outcome we have refused
  to claim until the D-017 eval (`store-listing.md`, must-not-claim 4). They go in only if the eval
  supports them.
- **"chatbot", "ai assistant", "ask anything" are absent** on purpose. They sell the oracle we are not.
- 1 character spare. If a term has to be added, "plain text" is the one to drop.

## Support URL, Marketing URL, Privacy Policy URL

| Field | Value | Note |
|---|---|---|
| Support URL (**required**) | `https://brettleehari.github.io/arivu/support.html` — a page at the privacy-policy host | Apple requires it to "lead to actual contact information". A repository README does not qualify for a non-technical reader. Must carry the D-010 mailbox, how to delete your data, how to report a reply, and the three limits. **Deliverable W-GTM-i6** |
| Marketing URL (optional) | `https://github.com/brettleehari/arivu` or the hosted tour | Optional; use the repo until a site exists |
| Privacy Policy URL (**required**) | `https://brettleehari.github.io/arivu/privacy.html` → `privacy-policy.html` | Same single policy as Play, now covering both platforms |
| Copyright | `2026 Hariprasad Sudharshan` | |

## Age rating

**Verified:** Apple's tiers are now **4+, 9+, 13+, 16+, 18+** (plus Unrated, which cannot ship).
12+ and 17+ survive only for older OS versions and regional mappings. Since September 2026 the
questionnaire's social-media questions are required for new apps.

What the questionnaire does **not** force on us, read against Apple's own definitions:

- **Not user-generated content** as Apple defines it ("broad distribution of content created by users
  as a component of the app's intended user experience"). Arivu shares nothing with anyone.
- **Not social media.** No feed, no redistribution, no other users.
- **No unrestricted web access.** No web view, no browsing, no network.

What it *does* turn on: Apple states plainly that "you must consider how all app features, including
AI assistants and chatbot functionality, impact the frequency of sensitive content appearing within
your app." Our own host probe (`leaves/NOTES.md`) shows a 0.6B model that sometimes complies with a
request it should refuse. **So the honest answers are not "None" on the sensitive-content
descriptors**, and Compliance owns the wording of each answer.

**Recommendation (proposed decision D-GTM-H):** answer the questionnaire honestly on frequency, then
decide separately whether to use Apple's "Override to Higher Age Rating" so the App Store rating lines
up with the Play target-audience answer (D-024 proposes 18+). Two things to weigh: an 18+ rating
reduces discoverability and maps higher again in some regions, while a mismatch between "18+ audience
on Play" and a low rating on Apple is a consistency problem a reviewer can see. Do not decide it in
this file. Compliance + Hari.

## Screenshots required today

**Verified** against ASC Help, *Screenshot specifications*, 2026-09-15.

| Size | Accepted pixel sizes (portrait) | Required? |
|---|---|---|
| **6.9" iPhone** | **1290 × 2796**, 1320 × 2868, 1260 × 2736 | This is the set to upload. The 6.5" row is required only "if screenshots for 6.9" display aren't provided" |
| 6.5" iPhone | 1284 × 2778, 1242 × 2688 | Alternative to 6.9", not needed as well as it |
| 6.3" / 6.1" / 5.5" / 4.7" and smaller | 1179 × 2556, 1206 × 2622 / 1170 × 2532, 1125 × 2436, 1080 × 2340 / 1242 × 2208 / 750 × 1334 | Optional. Apple scales the 6.9" set down when a row is missing |
| iPad (13") | — | **Not required**: required only "if app runs on iPad". Arivu is iPhone-only at launch |

- 1 to 10 per size; JPEG or PNG; **no alpha channel or transparency**.
- Guideline 2.3.3: must show the app in use — not the title art, login page or splash screen.
- Guideline 2.3.8: screenshots must suit a **4+** rating whatever the app's rating is.
- Apple's page adds a new "iPhone Duo" entry (1398 × 2034 outer / 2007 × 2853 inner) and notes that
  uploading assets for it "will be available later this year" — nothing to do now.

**So: one 6.9" set, 4 to 6 shots, portrait, 1290 × 2796.**

Content comes from `screenshot-shotlist.md`, recaptured on an iPhone (W-GTM-i4). The Android captures
cannot be reused — different status bar, different type, and one shot is wrong on iOS:

| Play shot | On iOS |
|---|---|
| 1 · empty state, airplane mode | Same, recaptured. Airplane Mode is even more the point here, since it is the privacy proof (§7) |
| 2 · explain a formal paragraph | Same |
| 3 · context divider | Same |
| 4 · About: good at / not good at | Same, plus the iOS privacy wording |
| 5 · incompatible device | **Changed.** No "Uninstall Arivu" button exists on iOS. Recapture, or drop the shot |
| — | Consider the Report sheet shot (Play candidate 8) — it is the clearest evidence for "nothing is sent unless you send it" |

## What's New — not applicable to version 1.0

**Verified:** the field "isn't available for the first version of the app but required for all
subsequent versions." So there is no what's-new text at launch, and anyone asking for one is asking
for a field App Store Connect will not show. Guideline 2.3.12 then requires real content in every
later version: "Simple bug fixes, security updates, and performance improvements may rely on a
generic description, but more significant changes must be listed in the notes."

Template for version 1.0.1 and later — 299 / 4000:

```text
What is new in this version:
• [One plain sentence per real change, in the same words the app uses.]
• [If a change came from something a tester or reviewer told us, say so.]

Arivu still works with no internet, still keeps your conversation on your iPhone, and still has no account and no settings.
```

Rules for whoever writes the real one: no speed claims, no accuracy claims, no beta or test language
(Guideline 2.2), no other platform (2.3.10), and nothing that is not in the build.

## Notes for App Review (not public)

Guideline 2.3.1(a) requires new features to "be described with specificity in the Notes for Review
section… (generic descriptions will be rejected)". Draft:

```text
Arivu runs a small language model entirely on the device. It has no accounts, no sign-in and no server, and it makes no network requests of any kind, so no test credentials are needed and no part of the app requires connectivity.

To verify: launch the app, turn on Airplane Mode, type "Explain this in simple words:" followed by any paragraph, and tap Send. The reply is generated on the device.

The model is Qwen3-1.7B-Q4_K_M (Apache 2.0), bundled in the app, running under llama.cpp (MIT). Output is shown only to the person using the app; nothing is shared with other users and there is no feed, no messaging and no web access.

The About screen states what the model is good and bad at, and every reply has a Report button, which opens the system mail composer, pre-filled, addressed to arivu.ai.org@gmail.com. Nothing is sent unless the user sends it.

Full source: https://github.com/brettleehari/arivu
```

## What we must NOT claim

Everything in `store-listing.md`'s "What we must NOT claim" list (items 1–12) applies here word for
word: no speed or memory numbers, no accuracy claims, no health/legal/exam claims, no
rewrite-quality promise, no translation promise, no superlatives, no invented testimonials, no
keyword stuffing, no privacy overreach, no sharing promise, no emoji or ALL CAPS, no endorsement.

Added by Apple and by C11:

13. **Never say Arivu "cannot" use the internet on iOS.** It does not; iOS will not prove it for us.
    The ban is on *cannot* attached to Arivu reaching the network — not on the word itself. "An app
    cannot prove this by giving up a permission" and "if your iPhone cannot run Arivu well" are both
    correct and both stay. See `positioning.md` §7 for the banned sentences and the precise rule.
14. **Never name another mobile platform or app marketplace** anywhere in this listing, its
    screenshots, or the app itself (Guideline 2.3.10). The word "Android" does not appear in this file's
    listing text for that reason, and the Play listing likewise does not mention iPhone.
15. **No prices, price terms or "free"** in name, subtitle, description or screenshots (2.3.7, and
    Apple's advice to keep prices out of descriptions).
16. **No beta, test, trial, early access or preview wording** (Guideline 2.2).
17. **No device-profile feature claims.** Never "on newer iPhones you also get…". The only public
    sentence about the ceiling is that how much text Arivu can hold depends on the phone (C11,
    `positioning.md` §5, `use-cases.md`).
18. **No implication that Apple verified our privacy claim.** The App Privacy card is our own
    declaration. Say what it says; never "Apple-verified", "Apple-approved privacy" or similar.

## Before submission — checklist

1. `1039 MB`, `17.0`, `3.5 GB` filled from measurements, not estimates (W-GTM-i2).
2. Support page live and carrying real contact information (W-GTM-i6); privacy policy URL live, with
   the iOS blocks in `privacy-policy.html` verified against the shipped app (W-GTM-i3).
3. App Privacy questionnaire answered so the card reads **Data Not Collected**; read it side by side
   with the privacy policy, the description and the Play Data safety form (W-GTM-i5). Four documents,
   one meaning.
4. Age rating questionnaire answered honestly; the override decision made (D-GTM-H).
5. Screenshots: one 6.9" set, no alpha, app in use, 4+ appropriate, captured on a real iPhone.
6. Read the description once more looking only for two things: the name of any other platform
   (must be absent), and every occurrence of "cannot" (each must be about the device or about what
   iOS can prove — never about Arivu reaching the network).
7. Two App Store Connect declarations Play has no equivalent for — [U] the exact question wording is
   not verified here; Compliance to confirm in the Console:
   - **Export compliance / encryption.** Arivu implements no cryptography of its own and makes no
     network connections, so the honest answer is the non-exempt-encryption "no" path. This mirrors
     `leaves/compliance/play-policy-checklist.md` §11 and needs the same legal reading, not a
     different one.
   - **Content rights.** The app contains third-party content: Qwen3 weights (Apache 2.0) and
     llama.cpp (MIT), both redistributable, both listed on the in-app licences screen (C4).
8. A last consistency read of the two listings side by side. Same name, same verbs, same honesty
   paragraph, same limits. Every sentence that differs must point at a platform difference that
   exists in the code (`positioning.md` §3).
