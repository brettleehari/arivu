---
spine_version: 0.1
leaf: gtm
artifact: Play "What's new" text, v0.1.0 (versionCode 1)
---

# Release notes — v0.1.0

Play limit: 500 Unicode characters per language (verified 2026-09-15, Play Console Help answer 9859348).
Count: **475 / 500** (Python `len()`, newlines counted as 1). Language: en-US (add en-GB with the same text if the listing adds it).

```text
First release of Arivu.
• Ask it to explain, summarise, shorten, rewrite or draft text on your phone, with no internet.
• The AI model is inside the app. No account and no setup.
• Stop a reply at any time. Copy it into another app.
• Arivu shows a line when older messages no longer fit in its memory.
• Report under any reply: opens your email app with that reply. Nothing is sent until you send it.
• About: what Arivu is good and bad at, the privacy policy, and licences.
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

Not said: speed, accuracy, languages, device counts. For internal and closed testing tracks, add one line
at the top: `Test build. Please tell us if Arivu is slow, crashes or gives a harmful reply.` and recount: that line is 78 characters, so the total would be 554; dropping the About bullet brings it to 480.
