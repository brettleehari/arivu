---
spine_version: 0.2
leaf: gtm
artifact: Play "What's new" text, v0.1.0 (versionCode 1) — rewritten 2026-09-23
scope: Google Play only — the App Store has no "What's New" field for a first version (verified; see appstore-listing.md)
---

# Release notes — v0.1.0

Play limit: 500 Unicode characters per language (verified 2026-09-15, Play Console Help answer 9859348).
Count: **570 / 500** (Python `len()`, newlines counted as 1). Language: en-US (add en-GB with the same text if the listing adds it).

```text
First release of Arivu.
• Explain, summarise, shorten, rewrite or draft text on your phone, with no internet.
• The AI model is inside the app. No account and no setup.
• Several conversations, kept on the phone. Swipe or tap Edit to delete one.
• Every reply shows what it cost: words in, words out, speed.
• Open any reply to read the exact text the model was given, and change the instructions it runs on.
• "How Arivu works" explains the model, the memory limit and the speed, and lets you count tokens.
• Stop a reply at any time. Copy it. Report it if it is wrong.
```

## Check

| Line | True because | Spine |
|---|---|---|
| Ask it to explain … with no internet (tasks, not quality; D-017) | No INTERNET permission; system prompt + About strings | C2, C3, C5 |
| Model inside the app; no account and no setup | Install-time asset pack; no sign-in code | C1 |
| Stop at any time; Copy | `stop`, `copy` states; engine cancel checked during prefill and decode | C10 |
| Line when older messages no longer fit | `context_divider` | C7 |
| Report under any reply | `ui/ReportOutput.kt` ReportSheet → email draft with reply text; pending Hari's approval of the scope change (if rejected, drop that bullet) | C9, C3 |
| About contents | `AboutScreen.kt` sections incl. offline privacy policy | C3, C4, C5 |

**On the App Store this file has no counterpart yet.** Apple's "What's New" field "isn't available for the first
version of the app but required for all subsequent versions" (App Store Connect Help, verified 2026-09-15), and its
limit is 4000 characters, not 500. The template for Arivu's first iOS *update* is in `appstore-listing.md`. Do not
copy this text across: it is written to a 500-character budget, and Guideline 2.3.10 forbids naming another platform.

Not said: speed, accuracy, languages, device counts. For internal and closed testing tracks, add one line
at the top: `Test build. Please tell us if Arivu is slow, crashes or gives a harmful reply.` and recount: that line is 78 characters, so the total would be 554; dropping the About bullet brings it to 480.
