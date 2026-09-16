---
spine_version: 0.2
leaf: gtm
artifact: Google Play phone screenshots, v0.1.0 (for Engineering to capture, W20) + the iPhone set (W-GTM-i4)
---

# Screenshot shot list — Arivu v0.1.0

Seven phone screenshots were planned: six core, one optional. States come from `leaves/design.md`, and every
visible string is from `strings.xml`. Engineering captured them on 2026-09-15 into `screenshots/`
(see `screenshots/CAPTURE-LOG.md`). **The upload decision is directly below**; the per-shot specs further down
are kept for recapture.

## Upload decision — v0.1.0 (GTM, after reviewing every captured image)

Upload these, in this order. Four is Play's recommended minimum, and every one shows real, unedited output.

| # on listing | File | Shows | Spine | Note |
|---|---|---|---|---|
| 1 | `screenshots/shot-1-empty.png` | Works with no internet, what it is bad at, airplane mode | C1, C2, C3, C5 | Clean |
| 2 | `screenshots/shot-3-explain.png` | Explain a formal paragraph in simple words; Report and Copy under the reply | C5, C9 | The reply is correct. It is a plain paraphrase more than a simplification, which is honest for 0.6B |
| 3 | `screenshots/shot-5-context-divider.png` | "Arivu can no longer see the messages above this line" | C7 | The visible summary merges two points ("Teachers and parents must adjust lesson plans and request late arrival"). That is a mild real error, and the shot is about the divider. Acceptable |
| 4 | `screenshots/shot-6-about.png` | Good at / **Not good at** / Private by design / Privacy policy / Report | C5, C3, C9 | Report button just below the fold; fine |
| 5 (optional) | `screenshots/shot-7-incompatible-debug.png` | Will not start on a weak phone; one Uninstall button | C6 | Shows "needs at least 3.5 GB". **Recapture if D-009 moves the floor.** Include it only if the team agrees it reassures more than it worries |

**Do not upload:**
- `shot-2-REVIEW-misread.png` and `evidence/shot2-*`. The polite rewrite failed 6/6 (echoed the input, or
  reversed who was late). A polite-rewrite shot would show a better model than we ship. There is **no rewrite
  screenshot** in the v0.1.0 set. This is the D-017 quality risk, flagged in `store-listing.md`; do not
  work around it by trying more inputs until one looks good.
- `shot-4-stop-streaming.png` and `shot-4-stopped.png`. Stop itself works, but both frames show the partial summary
  "for the next two school terms" when the circular says one term. A listing image that teaches a wrong summary
  works against C5. **Recapture requested:** same input, tap Stop as soon as the *first* bullet has finished
  (before the "two school terms" clause, or on a run that gets it right), and keep the Streaming variant with
  **Stop** in the slot. If the recapture is clean, insert it as listing #3 and move the divider to #4.

**Known cosmetic issue in all captures:** the emulator's developer-options icon (◈) sits next to the clock.
It would not appear on a phone with USB debugging off. Acceptable for a first listing; prefer a recapture on
the physical test phone once W21 runs.

**Candidate new shot (after Hari approves the per-reply Report scope change):**
**8. Report sheet.** From shot 3's state, tap **Report** under the reply. Do not pick a reason, and leave the note empty.
Capture the sheet showing "Report this reply", the four reason chips, the note field and `report_sheet_privacy`
("…your email app sends the report. It will include this reply and your note…"). Spine C9, C3. This is the
most direct evidence for the AI-content reporting policy and for "nothing is sent until you send it".

## The iPhone set (Spine 0.2, C11) — a separate capture, not a re-export

The Android captures cannot be reused for the App Store. Different status bar, different type metrics,
and one shot is simply wrong on iOS.

**Required today (verified 2026-09-15, App Store Connect Help, "Screenshot specifications"):** one
**6.9-inch iPhone** set at **1290 × 2796** portrait (1320 × 2868 and 1260 × 2736 also accepted). 1–10
images, JPEG or PNG, **no alpha channel**. Apple scales that set down for smaller displays, so no other
size is needed. iPad screenshots are required only if the app runs on iPad — Arivu is iPhone-only.
Guideline 2.3.3: show the app in use, not a splash screen. Guideline 2.3.8: the images must suit a 4+
rating whatever the app is rated.

| Play shot | iPhone version |
|---|---|
| 1 · empty state in airplane mode | Recapture. Airplane Mode matters *more* here: on iOS it is part of the privacy proof (`positioning.md` §7) |
| 2 · explain a formal paragraph, Report and Copy visible | Recapture, same input |
| 3 · context divider | Recapture, same conversation |
| 4 · About: good at / not good at | Recapture **with the iOS privacy wording**, not the Android sentence |
| 5 · incompatible device (optional) | **Changed.** There is no "Uninstall Arivu" button: an iPhone app cannot offer to uninstall itself. Either recapture the explain-and-stop screen or drop the shot |
| 8 · Report sheet (candidate) | Strongest evidence for "nothing is sent unless you send it". Worth capturing on iOS first |

Same rules as below apply to content: real unedited output only, no polite-rewrite shot until D-017,
no speed or accuracy claims in any caption band.

## Play rules these must meet (verified 2026-09-15, Play Console Help "preview assets")

- 2–8 phone screenshots; at least 4 recommended.
- JPEG or 24-bit PNG, **no alpha**. Each side 320–3840 px. **Longest side no more than twice the shortest.**
- For high-visibility placements: portrait **9:16, at least 1080 × 1920**.
- Must show the actual in-app experience. No hands or people holding the phone, no "Download now"
  calls to action, no time-limited content, and any caption band must take **no more than 20%** of the image.

A typical modern emulator (1080 × 2400, 20:9) breaks the 2:1 rule. Use the AVD below.

## Capture setup (Engineering)

1. **AVD**: arm64-v8a system image (the app ships arm64-v8a only), API 36, **1080 × 1920, 420 dpi**
   (hardware profile "Pixel 2" or a custom 1080 × 1920 profile), **RAM 6 GB** so `totalMem` clears the
   3.3 GiB gate floor, internal storage 8 GB. Emulator speed is not a claim anywhere; it only has to finish.
2. **Build**: release-signed bundle installed like Play does (`tools/install_bundle.sh`), version 0.1.0.
   Shot 7 alone uses the debug build (see there).
3. **System**: light theme, English (US or UK), font size and display size default, gesture navigation.
4. **Airplane mode on for real** before launching the app, and leave it on for every shot:
   `adb shell cmd connectivity airplane-mode enable`. The airplane icon in the status bar is part of the claim.
5. **Clean status bar** (clock and battery only; do not fake network icons):
   ```sh
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 85 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```
   If demo mode hides the real airplane icon, skip demo mode: an honest status bar beats a tidy one.
6. **Fresh state** for shot 1: `adb shell pm clear io.github.brettleehari.arivu` (or the final package from D-001).
7. **Capture**: `adb exec-out screencap -p > shot-N.png`, then remove alpha:
   `python3 -c "from PIL import Image; Image.open('shot-N.png').convert('RGB').save('shot-N.png')"`.
   Check each file is 1080 × 1920 RGB.
8. Type inputs with the keyboard hidden before capture (press Back once), unless the shot says otherwise.
   To paste long text: `adb shell input text` breaks on spaces and punctuation, so put the text on the
   emulator clipboard (emulator Extended controls → or `adb shell cmd clipboard set` where available)
   and long-press → Paste in the input.

### Honesty rule for model output

Replies in the screenshots must be **real, unedited output** from the shipped model on this build.
Do not retouch, retype or compose a reply. If a reply is poor (D-017 shows 0.6B can misread a task), you may
send the same input again up to **three** times and keep the best real reply; if none is usable, use the
listed backup input and record that in the capture log. A screenshot that shows a better model than we
ship is a false listing. Keep a log (`shot`, input, attempt number, date, build) next to the PNGs.

## The shots

### 1. Works with no internet — Empty state

| | |
|---|---|
| **State** | design.md "Empty". Fresh install, gate passed, no messages, airplane mode on. |
| **Steps** | Launch Arivu. Do not type. |
| **Visible** | `empty_title` "Works with no internet", `empty_body`, "For example, you can write:" and the three example chips, input hint "Type or paste your text", Send disabled, "About" top right, airplane icon in status bar. |
| **Optional caption** | Works with no internet |
| **Spine** | C1 (no setup screen before chat), C2, C3, C5 (limits said before the first word) |

### 2. Make it polite — Done state with Copy — **FAILED 2026-09-15, not uploaded (D-017)**

| | |
|---|---|
| **State** | design.md "Done". |
| **Steps** | From shot 1, type exactly: `Rewrite this to sound polite: Parents must pay the trip money by Friday or the child stays home.` Tap Send. Wait for the reply to finish (Copy appears). Hide the keyboard. |
| **Backup input** | `Rewrite this to sound polite: Send me the lesson notes today. You are late again.` |
| **Visible** | User bubble, full reply, **Copy** under the reply, Send (not Stop) in the input slot. |
| **Optional caption** | Make your message polite |
| **Spine** | C5 (good at the user's own text) |

### 3. Explain in simple words

| | |
|---|---|
| **State** | design.md "Done". Clear state first (`pm clear`) so this reads as one task. |
| **Steps** | Type `Explain this paragraph in simple words:` then a new line, then paste exactly: `Following the review of the timetable, the commencement of the first period shall be adjusted to 8:15 a.m. with effect from the second term. Pupils are expected to be seated prior to the commencement of assembly, and latecomers shall be recorded accordingly.` Send, wait for Done. |
| **Backup input** | `Explain this in simple words: The tenant shall give not less than one calendar month's notice in writing prior to vacating the premises.` |
| **Visible** | The full user bubble and the reply with Copy. If the reply is long, scroll so the top of the reply and Copy are both visible; if they cannot both fit, keep the start of the reply. |
| **Optional caption** | Understand a notice in simple words |
| **Spine** | C5 |

### 4. Stop means stop — Stopped state

| | |
|---|---|
| **State** | design.md "Stopped". |
| **Steps** | Clear state. Type `Summarise this circular in three points:` then a new line, and paste the **Circular text** below. Send. When 2–3 lines of the reply have appeared, tap **Stop**. Wait until the label "Stopped" shows. |
| **Visible** | Partial reply kept, label "Stopped" under it, Send back in the input slot. |
| **Alternative (stronger, harder)** | Capture *during* streaming, with **Stop** in the input slot (design.md "Streaming"). Use `adb exec-out screencap` from the host while text is arriving. If you get it, use it instead and caption "Stop at any time". |
| **Optional caption** | Stop a reply at any time |
| **Spine** | C10 |

**Circular text** (fictional, about 180 words; reuse in shot 5):

```text
The school board has reviewed the proposal to change the start of the school day. From the second term, the first period will begin at 8:15 a.m. instead of 7:45 a.m. Two schools in the district will try the new time for one term before a final decision is made. Teachers are asked to adjust their lesson plans so that the first period is not shortened. Pupils who travel more than five kilometres may ask for permission to arrive late, but a parent must write to the head teacher before the end of this term. The morning assembly will move to Wednesdays and Fridays only. On other days, class teachers will take attendance in the classroom. Lunch will stay at the same time, so the morning will be thirty minutes shorter. Parents who have concerns may attend a meeting in the school hall on the last Thursday of this month at 4 p.m. Minutes of the meeting will be shared with all class teachers. A final decision will be announced before the end of the trial term.
```

### 5. It shows what it has forgotten — Context divider

| | |
|---|---|
| **State** | design.md "Context divider" (and possibly "Cut off"). |
| **Steps** | Clear state. Repeat this pair until the divider appears (usually 3–5 rounds; the prompt budget is about 1,400 tokens after the 512-token reply reserve in `Policy.kt`): send `Summarise this circular in three points:` + new line + **Circular text**, wait for Done; then send `Now make it shorter.`, wait for Done. As soon as the rule "Arivu can no longer see the messages above this line" is present, scroll so the divider sits in the upper third of the screen with the next user message and its reply below it. |
| **Visible** | The divider line and its text, at least one message above it (cut by the top edge is fine), at least one full user message and reply below it. If a reply ended with the "Cut off: …" label, keep it in frame: it is a true state and supports the same commitment. |
| **Optional caption** | Shows you when older messages no longer fit |
| **Spine** | C7 |

### 6. Honest about its limits — About screen

| | |
|---|---|
| **State** | design.md "About screen". |
| **Steps** | Tap **About**. Do not scroll. |
| **Visible** | "About Arivu" title, "What Arivu is", "Good at", **"Not good at"**, "Private by design", the "Privacy policy" row, and ideally "Report a harmful reply" with its button. If the button is below the fold at 1080 × 1920, keep the top of the screen: "Not good at" and "Private by design" matter more. |
| **Optional caption** | Says plainly what it is not good at |
| **Spine** | C5, C3, C9 |

### 7. (Optional) Won't limp along on a weak phone — Incompatible-device screen

| | |
|---|---|
| **State** | design.md "Incompatible-device screen", total RAM failure. |
| **Steps** | Install the **debug** build (the fake-memory extra is debug-only), then: `adb shell am start -n io.github.brettleehari.arivu/io.github.brettleehari.arivu.app.MainActivity --el arivu.fakeTotalMem 2000000000`. |
| **Visible** | "Arivu can't run well on this phone", the RAM sentence (as the app formats it for 2,000,000,000 bytes), explanation, one button "Uninstall Arivu". Nothing else. |
| **Check before use** | The debug build must look identical to release on this screen (no debug banner, same version string is not shown here). If it differs, drop this shot. |
| **Optional caption** | Tells you if your phone cannot run it well |
| **Spine** | C6 |

Use shot 7 only if the listing has room after shots 1–6 and the team agrees it reassures rather than
worries. It is the most distinctive trust signal we have, and the least conventional.

## Captions: to overlay or not

Recommendation for v0.1.0: **upload shots 1–6 raw, with no overlay.** Reasons: the in-app text already
says the claim (shots 1 and 6 are the listing's best copy), overlays take design time, and every overlay
word is another claim to keep true. If Design adds captions later, use the "Optional caption" lines
exactly, in a top band no taller than 384 px (20% of 1920), on `#F5F1E6` with `#1F5C4A` text, and do not
cover app content.

## Not in this set, on purpose

- **Another language.** A Yoruba, Portuguese or Tagalog reply would be a strong image, but D-014 (UI is
  English) and D-017 (no non-English eval yet) mean we cannot show it honestly. Revisit after W04.
- **Speed.** No timer, no "replied in 3 seconds".
- **Tappable example chips.** They are not tappable in v1 (design.md).

## Feature graphic render

`feature-graphic.html` → `feature-graphic.png` (1024 × 500, RGB):

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1024,500 --force-device-scale-factor=1 \
  --screenshot=fg_raw.png "file://$PWD/leaves/gtm/feature-graphic.html"   # Chrome may not exit after writing the PNG; kill it once fg_raw.png exists
python3 -c "from PIL import Image; Image.open('fg_raw.png').convert('RGB').save('leaves/gtm/feature-graphic.png')"
```
