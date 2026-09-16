---
spine_version: 0.1
leaf: gtm/screenshots
captured_by: Engineering Leaf, 2026-09-15
---

# Capture log — Play phone screenshots v0.1.0

All images are real, unedited `adb exec-out screencap` output, converted RGBA → RGB (no other change),
1080 × 1920 (9:16). **Emulator, not a phone**: AVD `arivu_4gb` (API 36 google_apis arm64-v8a, 4 GB RAM,
`MemTotal` 4,014,920 kB), display overridden with `wm size 1080x1920` + `wm density 420`, light theme,
airplane mode really on (`cmd connectivity airplane-mode enable`). Emulator speed is not a claim anywhere.

**Build**: release AAB 0.1.0, signed with a throwaway test key (`CN=THROWAWAY NOT FOR UPLOAD`) and installed with
`bundletool build-apks --connected-device --local-testing` + `install-apks` (base + arm64 split + install-time model
pack). Shots 1–6 were taken on the build immediately before the final one; the only later code change is the
throttled save of a streaming reply (`ChatViewModel.STREAM_SAVE_MILLIS`), which changes nothing on screen. Shot 7 is
the debug bundle (the fake-memory extra is debug-only); it looks identical to release on that screen (no banner).

**Status bar**: demo mode hid the real airplane icon (tried with `network -e airplane show` too), so per the shot
list it was **not** used. The real bar shows the clock, airplane and battery icons, plus the emulator's ongoing
"developer" system notification icon (◈, from `android`, cannot be dismissed while adb is attached). On a phone
with USB debugging off it would not appear. Recapture on a phone if that icon is unacceptable.

| File | Shot | Input (exact) | Attempt | Result | Use? |
|---|---|---|---|---|---|
| `shot-1-empty.png` | 1 Empty | none (after `pm clear`) | 1 | as specified | **yes** |
| `evidence/shot2-primary-a{1,2,3}.png` | 2 | `Rewrite this to sound polite: Parents must pay the trip money by Friday or the child stays home.` | 1–3 | model echoed the sentence unchanged (a1, a2) or near-unchanged ("…will stay home.", a3). Not polite. Also echoed 3/3 on the earlier build and on host with the pre-safeguard system prompt (leaves/NOTES.md) | no |
| `evidence/shot2-backup-a{1,2,3}.png` | 2 backup | `Rewrite this to sound polite: Send me the lesson notes today. You are late again.` | 1–3 | "Please find the lesson notes today. I apologize for being late again." / "…for my tardiness." / "…I'm late again." — polite tone, but flips who is late and who sends | no |
| `shot-2-REVIEW-misread.png` | 2 | backup input | 1 | copy of backup-a1, kept only so GTM can see the best real output | **no — do not upload**; GTM to pick a different Done example (shot 3's task works) or wait for D-017 |
| `shot-3-explain.png` | 3 Explain | `Explain this paragraph in simple words:` ⏎ + the timetable paragraph from the shot list | 1 | "Here's a simple explanation: After reviewing the timetable, the first period will start at 8:15 a.m. from the second term. Students should be seated before the start of assembly, and any latecomers will be noted." | **yes** |
| `shot-4-stop-streaming.png` | 4 (stronger alternative) | `Summarise this circular in three points:` ⏎ + Circular text | 1 | captured during streaming, **Stop** in the input slot | **yes** (caption "Stop at any time") |
| `shot-4-stopped.png` | 4 Stopped | same, Stop tapped ~2.4 s after Send | 1 | partial reply + "Stopped". Note the partial reply says "for the next two school terms" (the circular says a one-term trial): a real 0.6B error, visible in the image | GTM decide; prefer the streaming shot |
| `shot-5-context-divider.png` | 5 Divider | 6 rounds of circular summary + `Now make it shorter.` | 1 | divider appeared in round 5 (logcat: prompt 1373, reused 141 — history dropped); scrolled so the divider is in the upper third | **yes** |
| `shot-6-about.png` | 6 About | tap About, no scroll | 1 | What / Good at / Not good at / Private by design / Privacy policy row / Report heading; the Report button is just below the fold | **yes** |
| `shot-7-incompatible-debug.png` | 7 (optional) | debug build, `am start … --el arivu.fakeTotalMem 2000000000` | 1 | "This phone has 2.0 GB of memory. Arivu needs at least 3.5 GB." (Android formats 3,543,348,019 B in SI units: 3.5 GB, not the 3.3 GiB design.md quotes) | optional |

Typing used `adb shell input text` (spaces as `%s`) with `KEYCODE_ENTER` for the new line, keyboard hidden with Back
before capture. Commands: `build/emu/attempt.sh`, `ui.py`, `type.py` (scratch, not shipped).
