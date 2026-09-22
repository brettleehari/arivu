---
spine_version: 0.2
leaf: design
audience: product designers, UX research, Android and iOS engineers
platforms: [android, ios]
---

# Design Leaf — interaction states and trust signals

Three screens, on two platforms, one product. Trust signals below are product decisions, not
decoration: they are the difference between a tool the user trusts and a tool the user tolerates.

## Leaf changelog

- **0.2 — 2026-09-15** — Re-stamped for Spine 0.2 (C11). The state catalogue is now written as
  product behaviour, with a platform column only where the OS forces a difference. Adds the iOS-only
  states (background suspension mid-reply, first-run model map, the gate with no uninstall button),
  the shared low-memory message, one copy catalogue (`leaves/design/copy.md`), and accessibility
  commitments covering VoiceOver and Dynamic Type alongside TalkBack and font scaling.
- **0.1 — 2026-09-15** — First Leaf, Android only.

## How to read this file

**The centre column is the product.** Every "What the user sees" cell describes behaviour that must be
true on both platforms. The "Where the platform forces a difference" column is short on purpose: a
difference belongs there only when the OS makes the shared behaviour impossible, never when a platform
merely has a different habit. Five things qualify today, and they are the five in
`MULTIPLATFORM.md`'s table: background execution, memory pressure, device gating, the report hand-off,
and packaging. Everything else is identical by policy (§2).

**Copy lives in one catalogue**, `leaves/design/copy.md`. String keys are quoted here so a copy change
is one edit in one place. Android reads it as `android/app/src/main/res/values/strings.xml`; iOS reads
it as a String Catalog with the same keys. Neither file is the source.

**C11 in this Leaf's terms:** nothing in the UI branches on "am I on iOS". It branches on what the
device profile can carry, or on a named OS capability (`can the process keep working while hidden?`,
`does the system confirm a clipboard write?`). Written that way, an 8 GB Android phone and an 8 GB
iPhone get the same screens without a second code path.

---

## 1. Verification model (product decision, not visual)

A 0.6B model cannot be made trustworthy about facts. The design does not pretend it can. The user is
invited to verify by **what the app refuses to imply**:

1. It never shows confidence scores, sources, or citations: it has none, and fake ones would be worse.
2. It says what it is bad at in three places: empty state, About, and the model's own system prompt (C5).
3. It shows the edge of its memory (context divider) and why a reply ended (stop labels) (C7).
4. It shows privacy by absence: nothing to sign in to, nothing to configure, no network toggle (C3, C8).
5. Its icon promises help with *your words* (a speech bubble holding lines of text), not an oracle (C5).

### The one place the two platforms are not equally honest (C3)

On Android, "it cannot reach the internet" is a fact the OS enforces: there is no `INTERNET` permission
in the manifest, and `tools/check_manifest.sh` proves it on every build. **iOS has no permission to
withhold.** The strongest true sentence on iOS is different, and the design must not copy the Android
one across and quietly weaken it.

| | Android | iOS |
|---|---|---|
| The claim | "Arivu has no permission to use the internet." | "Arivu has no code that can reach the internet." |
| What backs it | the OS, and a check in every build | public source, a reproducible build, and the App Store privacy label |
| Where it is said | empty state, About, privacy policy, listing | the same four places, in the iOS wording |

This is the single largest copy divergence in the product and the only one that changes a *claim*
rather than a noun. It is proposed as a decision (§10, D-038) because Compliance and GTM own the final
sentence; Design owns only the requirement that the sentence be different and be plain.

Everything else about privacy is identical: no account, no settings, no analytics, no model picker,
nothing to switch off — on both platforms the proof is that there is nothing there.

---

## 2. What is the same, and what is native

**The rule: the same words everywhere; the platform's own furniture around them.** A user who is shown
both apps should be unable to find a sentence that differs, and should never be surprised by how a
control behaves on their own phone.

### Identical by policy — a difference here is a bug, not a platform choice

- **Every user-facing sentence.** One catalogue, one English text (§6).
- **The honesty statements**: `empty_body`, `about_bad_title` / `about_bad_body` ("Not good at"),
  `about_good_body`, and the system prompt's own statement of limits. Byte-identical.
- **The context divider**: the same sentence, the same rule-with-text form, placed immediately above
  the first message the model could still see (C7).
- **Every stop label and its meaning**: `stopped_by_user`, `stopped_context_full`, `stopped_max_tokens`,
  `stopped_error`, `stopped_low_memory`. Same words, same place (under the partial reply), same colour
  role (error colour for the ones that mean something went wrong).
- **The report sheet**: same title, same four reasons in the same order, same privacy sentence, same
  "nothing is sent until you send it".
- **The device-gate sentences**: the failure line, the explanation paragraph.
- **The absences**: no settings screen, no model picker, no themes, no sign-in, no typing animation, no
  fake delay, no confidence score, no citation (C8).
- **Send and Stop occupy one slot** that is never empty, at the same minimum size.
- **Report then Copy**, in that order, as words.
- **The mark**: same geometry, same brand colours, same meaning.
- **The contrast floors** in §9, and the rule that no system accent or dynamic colour leaks in.
- **Behaviour under load**: follow-but-don't-yank, text selection on messages, partial replies always
  kept, saves every ~2 s while streaming.

### Native to each platform — copying the other platform here is the bug

| | Android | iOS |
|---|---|---|
| Navigation | Compose `Scaffold`, Material top app bar, "About" as a text action; system Back and back gesture | `NavigationStack`, inline title "Arivu", "About" as a trailing text button; About is pushed, with the standard back control and interactive swipe-back |
| Type | Material 3 type ramp, `sp`, honours font scale and display size | SF with Dynamic Type text styles, honours the user's text size up to AX5 |
| Controls | Material buttons, chips, `ModalBottomSheet` | SwiftUI buttons, a grouped single-select list for the report reasons, `.sheet` with `.medium`/`.large` detents |
| Single-select reasons | four chips that wrap | four list rows with a checkmark — the iOS idiom, and it survives AX5 text where a chip row cannot |
| Keyboard | `adjustResize` + `imePadding`; Enter inserts a newline; Ctrl+Enter sends | SwiftUI keyboard avoidance; Return inserts a newline; ⌘Return sends |
| Dismissing a sheet | Back, scrim tap, or Cancel | swipe down, or Cancel |
| Launch | Android 12+ splash API: the mark on brand green | `UILaunchScreen`: the mark on brand green, static, no spinner, no wordmark |
| Icon packaging | adaptive foreground + background + monochrome | one 1024×1024 opaque square; the system rounds it |
| Clipboard confirmation | the system's, on 13+ | Arivu's own (§4) — iOS shows nothing |

**Explicitly not adopted from iOS convention:** no settings gear, no SF Symbol in place of a word
(Copy, Report, Stop, Back, About stay words — icon literacy varies, words don't), no share glyph for
Report, no tab bar, no pull-to-refresh, no haptics. Speed and state are what the phone does; the app
does not decorate them.

**Where the platform's convention is at least as clear as ours, take it.** The iOS back control is a
chevron *plus the parent title* — words are present, so the icon-literacy objection that made Android's
back control the word "Back" does not apply, and the native control wins.

---

## 3. Chat screen states

The centre column is the product behaviour, required on both platforms. Read "—" in the platform
column as "no difference; build the same thing".

| State | Trigger | What the user sees | Where the platform forces a difference | Keys / Spine |
|---|---|---|---|---|
| **Launch screen** | app opened | The mark on brand green, in the app's own colours, in light and dark. No spinner, no wordmark, no version. The first screen looks like the icon that was tapped | Android: splash-screen API (12+). iOS: `UILaunchScreen`, which is static by definition — so neither platform animates | — / C1 |
| **Loading history** | conversation not yet read from disk | Nothing in the list area (no empty-state flash); Send disabled | — | — / C7 |
| **Empty** | no messages | Title "Works with no internet", what it's for, what it's bad at, "For example, you can write:" and 3 examples (plain text, not tappable). Scrolls if it does not fit | — | `empty_*` / C5 |
| **Composing** | typing | Send enabled only when input is non-blank; input grows to 6 lines (3 on short screens) | — | `input_hint`, `send` |
| **Starting** | first send after launch, or after the model was freed | The reply bubble appears at the same moment as the user's bubble, with a spinner and "Starting Arivu. This can take a few seconds…". Stop works throughout | — | `state_starting` / C1, C10 |
| **Starting, first run ever** | first send after install, before the model file has ever been read | Same bubble, different line: the first start is slower, and the user is told to keep Arivu open. See §5 | The reason it is slower differs (cold page cache after a Play install vs a cold read of a 400 MB bundle file), the screen does not | `state_starting_first_run` / C1 |
| **Starting, still going** | Starting has lasted > 15 s | The line is **replaced** (never appended) with "Still starting Arivu…". Stop still works | — | `state_starting_long` / C1, C10 |
| **Reading** | prefill in progress | Spinner "Reading…" — long pastes can take seconds | — | `state_reading` / C2 |
| **Streaming** | tokens arriving | Text grows in place; the list follows the newest line *while the user is at the bottom*; Send becomes **Stop** | — | `stop` / C10 |
| **Done** | end of turn | No label; **Report** and **Copy** appear under the reply (Copy only, on the user's own messages) | — | `copy`, `report` / C9 |
| **Copied** | Copy tapped | The text is on the clipboard and the user is told once, in one word | Android 13+: the system's own confirmation, and Arivu adds nothing. Everywhere else (Android ≤ 12, all iOS): the Copy button's label becomes "Copied" for 2 s, then reverts. See §4 | `copied` / — |
| **Report sheet** *(provisional, pending D-021)* | Report tapped on a reply | Title "Report this reply", one line why, "What is wrong?" and four single-select reasons (Offensive · Harmful · Wrong in a dangerous way · Something else), an optional note, a line saying the mail app sends it and that it includes the reply and note; **Cancel** / send button, enabled once a reason is chosen | Android: bottom sheet, chips, "Open email" hands off to another app. iOS: `.sheet`, list rows, and the mail composer appears **inside Arivu** — so the sentence and the button label change (§6) | `report_sheet_*`, `report_reason_*`, `report_note_label`, `report_send`, `cancel` / C9, C3 |
| **Reported** | the report was handed to the mail app | Label "Reported" under the reply, kept on the phone, surviving restart; Report stays available to send again. Nothing has been sent by Arivu | Android: the user's email app opens, pre-filled; with no email app, the share sheet opens with "To: address" in the text. iOS: `MFMailComposeViewController` opens in place; with no mail account, `UIActivityViewController` with the same "To: address" text | `reported`, `report_reply_template`, `report_share_prefix` / C9 |
| **Stopped** | user tapped Stop (also while Starting or Reading) | Partial text kept; label "Stopped". Stopped before any text: label only, no empty line | — | `stopped_by_user` / C10 |
| **Cut off** | context full mid-reply | Partial text kept; label in error colour: the next reply will leave out the oldest messages | — | `stopped_context_full` / C7 |
| **Reply limit** | max reply tokens | Label telling the user to send "continue" | — | `stopped_max_tokens` / — |
| **Low on memory** | the OS signals memory pressure while a reply is being written | Partial text kept; label in error colour naming what happened and what to do. See §5 | The signal differs (`onTrimMemory` vs `didReceiveMemoryWarning`); the screen does not | `stopped_low_memory` / C2, C7, C10 |
| **Error** | decode failure | Label in error colour, "Try sending again" | — | `stopped_error` / — |
| **Message too long** | newest message alone exceeds the context | Notice bar above the input: "Try sending a part about N% as long" (no token counts: users don't know tokens, they know "half"). The message stays so it can be copied and shortened; the reply bubble is removed; nothing sent | — | `message_too_long` / C7 |
| **Load failed** | model could not load | Notice bar; no crash | The recovery sentence names the platform's own way to close an app (§6) | `load_failed` / C6 |
| **Load failed, low memory** | the model could not load because the phone is short of memory | Notice bar, saying so plainly and what to do. Never the generic failure text: a memory problem the user can act on must not be dressed as a mystery | — | `load_failed_low_memory` / C2, C6 |
| **Context divider** | oldest turns dropped from the prompt | Rule + "Arivu can no longer see the messages above this line", above the first message it saw | — | `context_divider` / C7 |
| **Process death mid-reply** | the OS killed the app while streaming | On relaunch the partial reply (saved every ~2 s while streaming) is kept and labelled "Stopped" — not "Cut off", not "your phone ran low on memory". The app cannot know why it died, and a guess would be a lie | iOS is killed by jetsam far more readily and with no callback; the screen and the label are the same | `stopped_by_user` / C7 |
| **Backgrounded mid-reply** | the user switches app or goes Home | The reply keeps being written for as long as the OS allows; if it finishes, it is waiting when the user comes back, complete | **Android:** a foreground service keeps it writing for ~3 min — long enough that almost every reply finishes. A low-importance notification says "Arivu is writing a reply", because the OS requires one. **iOS:** a background assertion gives ~30 s, and Arivu posts no notification (it would need a permission prompt we refuse to ask for). See §5 | `notification_*` (Android only) / C10 |
| **Stopped in the background** *(iOS only today)* | the background allowance ran out before the reply finished | Generation is stopped cleanly before the OS suspends the app; partial text kept and saved; label under it says the app stopped because it was not on screen, and to send "continue". The user meets this on their next visit to the app — nothing interrupts them while they are elsewhere | Cannot occur on Android within the ~3 min service window; the state exists on both platforms and only fires where the allowance is short. See §5 | `stopped_backgrounded` / C10 |

### Micro-patterns

- **Send ↔ Stop** occupy the same slot at the same minimum size (88×56 dp on Android, 88×56 pt on iOS)
  so the text field never jumps. There is never a moment with neither.
- **Report** and **Copy** are text buttons side by side at the end of a reply (Report first, so Copy
  keeps its place at the edge). Screen readers hear "Report this reply" / "Copy this message".
- **Copy** is a text button, not an icon: icon literacy varies; words don't. Shown on the user's own
  messages too, so a too-long message can be copied and shortened.
- **Back** on About is the word "Back" on Android; on iOS it is the platform's back control, which
  carries the parent title as words (§2).
- **Text selection** is enabled on messages (select part of a rewrite).
- **No typing animation, no fake delay, no haptics.** Speed is what the phone does.
- **Follow, but don't yank**: while a reply streams, the list stays on its last line. If the user scrolls
  up to read, following stops; scrolling back to the end, or sending, resumes it.
- **Keyboard**: the input never hides behind the keyboard. Enter/Return makes a new line (pasted text
  has paragraphs); Ctrl+Enter (Android) or ⌘Return (iOS) sends. Sentence capitalisation. On Android the
  input asks the keyboard not to learn from what is typed (`IME_FLAG_NO_PERSONALIZED_LEARNING`;
  honoured by Gboard, not guaranteed elsewhere). **iOS has no equivalent request**, and the privacy text
  says so rather than implying we made one (§6).
- **User bubbles** sit at the end side with a 40 dp/pt start inset; replies at the start side with a
  24 dp/pt end inset. Start/end, never left/right, so RTL mirrors on both platforms.

---

## 4. Clipboard confirmation — one pattern, two triggers

Copying is the most-used action in a rewriting app, and a copy the user is not sure happened gets done
twice. The product rule: **the user is told once, in one word, in the place they tapped.**

- Where the OS already confirms (Android 13+ system overlay), Arivu adds nothing. Two confirmations
  read as a bug.
- Where the OS confirms nothing (Android 12 and below, and **every** iOS version), Arivu confirms
  itself: the Copy button's own label becomes "Copied" for 2 seconds, then reverts. Same word, same
  place, no toast, no banner, no overlay of our own.
- Screen readers announce "Copied" on both platforms, once.

This replaces the Android toast on API 30–32, so that there is one Arivu pattern rather than a toast on
old Android, nothing on iOS, and a system overlay in the middle. Request to the Android Leaf in §12.

---

## 5. The states the platforms genuinely force apart

### 5.1 A reply that cannot finish while the app is hidden (iOS)

Android's foreground service gives ~3 minutes: in practice every reply finishes, and C10's "survives a
brief app switch" is simply true. iOS gives roughly 30 seconds of background assertion, which a long
reply will outlive.

**The design decision: stop cleanly and say so. Never truncate silently, never resume by surprise.**

1. When the expiration handler fires, generation is cancelled the same way the Stop button cancels it —
   the same code path, so the partial text is saved by the same throttled save.
2. The partial reply is labelled `stopped_backgrounded`.
3. **No notification, no alert, no badge.** iOS would require a permission prompt for a local
   notification, and an app whose whole claim is "nothing leaves this phone, nothing asks you for
   anything" does not open with a permission dialog. The user finds out when they come back, which is
   the only moment the information is useful.
4. **No pre-emptive warning before the user leaves.** Warning someone that leaving will cost them is a
   way of asking them not to leave. Arivu does not do that.
5. Recovery is the same lever as every other short reply: send "continue".

> `stopped_backgrounded` — **"Stopped: Arivu cannot keep writing while you are in another app. Send
> “continue” to get the rest."**

This is a capability behaviour, not a platform behaviour: it fires wherever the background allowance
runs out before the reply ends. If a future Android profile loses its service window, the same state
fires there with the same words, unchanged (C11).

### 5.2 First launch, while a 400 MB model is mapped for the first time (iOS)

Arivu has no loading screen and does not touch the model at app start — the context is created lazily,
on the first send (BRIEF, lifecycle rules). So **first launch shows the empty chat immediately, on both
platforms.** That is the C1 promise and it does not change.

What changes is the first *send*. On iOS the model is a plain 400 MB file in the app bundle, read cold
from flash with nothing in the page cache, on a device that has just finished installing. That first
map can take tens of seconds where a warm start takes a few. The user must not read that as a hang.

- The **Starting** bubble appears at the same instant as their own message, as always, and **Stop works
  throughout** — a first run is exactly when someone wants to be able to back out (C10).
- On the first send after install, the line is `state_starting_first_run`, not `state_starting`.
- If Starting lasts longer than 15 seconds, on either platform and on any send, the line is **replaced**
  by `state_starting_long`. Replaced, never appended: one idea per string, no sentence built by joining
  strings in code.
- There is no progress bar and no percentage. We do not know how far through a page-fault storm we are,
  and an invented bar is exactly the kind of fake confidence §1 refuses.

> `state_starting_first_run` — **"Starting Arivu for the first time. This is the slowest it will ever
> be. Keep Arivu open."**
>
> `state_starting_long` — **"Still starting Arivu. Keep Arivu open."**

"Keep Arivu open" is the load-bearing sentence on iOS: leaving during the first map means suspension and
a lost map. It is harmless and true on Android, so it is one string on both.

### 5.3 Memory pressure

Housekeeping is silent; interruption is not.

- **Not generating**: the context is freed on memory pressure with **no message at all**. The user did
  not ask for a memory report, nothing of theirs was lost, and narrating housekeeping makes an app feel
  fragile. The only visible consequence is that the next send shows "Starting" again — which is already
  a state with an honest explanation.
- **While generating**: the reply stops, the partial text is kept, and the label says what happened and
  what to do — §7.
- **Killed outright** (Android LMK, iOS jetsam): no callback, so on relaunch the partial reply is
  labelled "Stopped". We do not guess at a cause we cannot know.

### 5.4 The device gate, where one platform cannot offer to uninstall

Android runs three checks (ABI, low-RAM flag, total RAM, free storage) and ends with one full-width
button: **Uninstall Arivu**. iOS has no API by which an app can delete itself, and `exit()` reads as a
crash and is refused by review.

**On iOS the screen has no button.** It has one extra line of plain instructions instead. A dead button,
a "Close" that does nothing useful, or a link into Settings that lands nowhere relevant would all be
worse than a sentence that tells the truth.

| | Android | iOS |
|---|---|---|
| Checks, in order | ABI (`SUPPORTED_ABIS`) → low-RAM flag (`isLowRamDevice()`) → total RAM (`MemoryInfo.totalMem`) → free storage (`StatFs`) | total RAM (`ProcessInfo.physicalMemory`) → free storage (`volumeAvailableCapacityForImportantUsage`) |
| Checks that do not exist | — | ABI (every supported iPhone is arm64) and the low-RAM flag (no equivalent) |
| Moment-to-moment memory budget | not a gate | **not a gate either.** `os_proc_available_memory()` is a reading of this second; a transient low value must never condemn a phone permanently. It is used at load time, where it produces `load_failed_low_memory` and the user can try again |
| The action | one full-width button, "Uninstall Arivu" | no button; one line saying how to remove it |
| Caching | result cached after the first launch | same |
| "Continue anyway" | never (R8) | never (R8) |

> `incompatible_remove_ios` — **"To remove Arivu: touch and hold its icon on the Home Screen, then
> choose Delete App."**

Everything else on the screen is identical: the title, the failure sentence, the explanation paragraph,
no close button, no crash, content clear of system bars, scrolls at the largest text size.

One consequence to design for rather than discover: the App Store has no device-exclusion catalogue
(`leaves/architecture/ios-port.md`), so **more iOS users will reach this screen than Android users
ever do**, some of them straight after paying attention to a listing. The screen is therefore not an
edge case on iOS; it is a first impression, and it is written as one. GTM request in §12.

---

## 6. Copy

**The rule.** One catalogue, `leaves/design/copy.md`, owned by Design. Every user-facing string in both
apps comes from it, with the same key. A platform file (`strings.xml`, String Catalog) is a rendering of
the catalogue, never a source. A string diverges **only** when the platform noun or the platform fact
differs — the object the user touches (Home Screen, Mail, the App Store, a Settings path), or a
capability that exists on one OS and not the other. Tone, structure and claims never diverge.

Rules for the text itself (also at the top of each platform file):

- Plain words, short sentences; many readers use English as a second language. No "tokens", "context",
  "comprehension", "foreground service", "jetsam". Tell the user what to do next.
- One idea per string. No concatenation in code; positional placeholders (`%1$s`, `%1$d`) with a
  translator comment saying what each is.
- Not translatable: the product name and pure-format strings.
- British spelling, consistently (summarise, licences, maths). UI language itself is D-014.
- Typographic apostrophes and quotes (’ “ ”) rather than escaped ASCII.
- **No platform name inside a sentence unless the sentence is about that platform.** "This phone"
  covers an iPhone; "iPhone" appears only where the user must do something iPhone-shaped.

### Android strings that need a different iOS wording

Full text for each is in `leaves/design/copy.md`. Summary of what changes and why:

| Key | Why it cannot be shared | iOS wording |
|---|---|---|
| `about_private_body` | The Android claim rests on a withheld permission that does not exist on iOS (§1) | "Arivu has no code that can reach the internet — you can check that in the source, because Arivu is open source. Your messages stay only on this phone." |
| `privacy_internet_title` | Same | "Arivu has no way to reach the internet" |
| `privacy_internet_body` | Enumerates Android permissions | Describes instead: no networking code, no network libraries, open source, a build anyone can reproduce, and an App Store privacy label that says Data Not Collected. Final text with Compliance (D-038) |
| `privacy_intro` | Names the platform | "Privacy policy for Arivu on iPhone, version %1$s." |
| `privacy_stored_body` | Android sandbox and Android backup rules | Same content: app-private storage, protected by iPhone's own encryption and passcode, excluded from iCloud backup and device transfer, kept until Arivu is deleted |
| `privacy_copy_body` | Android asks the keyboard not to learn; **iOS offers no such request** | "Copy puts text on your phone’s clipboard, like any copied text. Your keyboard learns from what you type in every app, and iPhone gives Arivu no way to turn that off. Other apps work under their own privacy policies." |
| `privacy_play_title` / `privacy_play_body` | Google Play vs the App Store | "The App Store", with the same shape: installing uses data, the store sees the install, the app itself uses no data afterwards |
| `privacy_choices_body` | There is no "clear storage" for one app on iOS | "To delete your conversation, delete Arivu: touch and hold its icon on the Home Screen, then choose Delete App. iPhone has no way to clear one app’s storage without deleting the app." |
| `about_report_body` | "your email or messaging app" | "Both open a message in your Mail app, already written. Nothing is sent until you send it." |
| `report_sheet_privacy` | On iOS the composer opens **inside Arivu**, so "your email app opens" is wrong | "Arivu cannot use the internet, so your Mail app sends the report. The message opens here, already written, with this reply and your note in it. Nothing is sent until you press send." |
| `report_send` | The button no longer leaves the app | "Write the email" |
| `load_failed` | "Close Arivu fully" names an Android gesture | "Arivu could not start on this phone. Close Arivu from the app switcher, then open it again." |
| `incompatible_uninstall` | iOS cannot uninstall itself (§5.4) | Not shown; replaced by `incompatible_remove_ios` |
| `gate_abi`, `gate_low_ram` | Checks that do not exist on iOS | Not shown |
| `notification_channel`, `notification_writing` | iOS posts no notification (§5.1) | Not shown |

**Everything not in that table is identical on both platforms**, including all four honesty
statements, every stop label, the context divider, the empty state, the report reasons, the gate's
failure and explanation text, and the new strings in §5 and §7.

---

## 7. The low-memory message

Wording and placement, for the Android Leaf to implement now and the iOS Leaf to implement with the
same key. One string, one meaning, both platforms.

> `stopped_low_memory` — **"Stopped: your phone ran low on memory. Close other apps, then send
> “continue” to get the rest."**

- **Where:** as a stop label under the partial reply, in the same slot and the same error colour as
  "Cut off". Not a notice bar, not a dialog, not a toast: the notice bar is for things that stop the
  user sending, and this does not.
- **When:** the OS signals memory pressure while a reply is being written, and Arivu frees the context
  to stay alive (`onTrimMemory` on Android, `didReceiveMemoryWarning` on iOS).
- **What is kept:** all text written so far, saved before the label appears. Copy and Report are
  available on it like any other reply.
- **What it never says:** not "out of memory", not an error code, not a number of megabytes, and never
  the word "context". It names what happened in the user's world and gives one action.
- **Not shown** when memory is reclaimed with no reply in flight (§5.3) — nothing of the user's was
  lost, so there is nothing to tell them.
- **Screen readers:** the live region announces the same sentence when the reply ends this way.

Second string, for the same cause at a different moment — the model cannot be loaded at all because the
phone is short of memory:

> `load_failed_low_memory` — **"Arivu could not start: your phone is low on memory. Close other apps,
> then send your message again."**

- **Where:** the notice bar above the input, the same place as `load_failed`.
- **Why it is separate:** `load_failed` ("Close Arivu fully, then open it again") sends the user to a
  remedy that will not help, for a problem they can actually fix. A generic failure message for a
  specific, actionable cause is the kind of small dishonesty that makes an app feel untrustworthy.

### Reconciliation with what Android landed in parallel

`strings.xml` now carries `stopped_low_memory` ("Stopped because your phone is low on memory. Close
some other apps, then try again.") and `low_memory` ("Arivu stopped because your phone is low on
memory…"). Two changes, both deliberate, both small:

1. **Take the wording above.** It opens with "Stopped:" so it reads in the same shape as "Cut off:" in
   the slot beside it, and it says send "continue" rather than "try again". The partial reply is still
   on screen; "try again" leaves the user guessing whether they are meant to re-send their own message,
   and the one thing that actually recovers the rest of the reply is the word "continue" — the same
   lever `stopped_max_tokens` already teaches them.
2. **Rename `low_memory` to `load_failed_low_memory`** if, as its placement suggests, it is the notice
   bar for a load that failed on memory. "Stopped" is the wrong verb for something that never started,
   and the key should name which of the two moments it belongs to. Both moments exist; both need words;
   they are not the same sentence.

---

## 8. About screen

Sections in order, identical on both platforms: What Arivu is → Good at → **Not good at** → Private by
design → **Privacy policy** (expand in place) → Report a harmful reply (button) → Open-source licences
(expand in place, "Notices (read first)" on top) → Version.

- **Privacy policy** *(provisional text)*: the full policy readable with no network, as headed sections
  (`privacy_*`). The Android text derives from `leaves/gtm/privacy-policy.html`; the iOS text is the
  same document with the divergences in §6. Both hosted pages must say the same as their app.
- **Report**: the general report (no specific reply). Android opens the user's email app, falling back
  to the share sheet; iOS opens the mail composer in place, falling back to the activity sheet. Copy
  states, on both, that nothing is sent until the user sends it (C3, C9).
- **Licences**: every shipped component, including the model weights (C4). Android also lists libc++;
  iOS lists what it actually links instead — the list is generated from the build, not copied across.
  Each row is a full-width 48 dp/pt target with an open/closed state for screen readers.
- **Version** shows the app version and, once both platforms ship, the shared core version — same
  engine, different app numbers (`MULTIPLATFORM.md` versioning).

---

## 9. Icon system

One mark, drawn once on a 108-unit grid, reused everywhere. **Concept:** a speech bubble holding three
lines of the user's text (the last one short, like a draft in progress) and a marigold spark: *help with
your words*. Not a brain, not a globe, not a chip — nothing that implies knowledge or a network.

| Asset | Platform | File | Notes |
|---|---|---|---|
| Palette | both | `res/values/colors.xml`, iOS asset catalogue | `brand_green` #1F5C4A, `brand_paper` #F5F1E6, `brand_amber` #D98E04. The same three hex values on both; no system accent, no dynamic colour |
| Adaptive foreground | Android | `res/mipmap-*dpi/ic_launcher_foreground.png` | The painted mark, raster, 108dp canvas per density (108/162/216/324/432 px). The artwork's own field occupies the middle 66% — exactly the safe zone — so every OEM mask cuts only into matching colour |
| Adaptive background | Android | `res/drawable/ic_launcher_background.xml` | Flat `brand_maroon` #5D131F, sampled from the artwork rather than chosen near it, so the foreground's field and this meet with no seam under any mask |
| Themed icon (Android 13+) | Android | `res/drawable/ic_launcher_monochrome.xml` | GENERATED by `tools/android/make_monochrome.swift`. A flat அ from the font, not the painting: the system tints this to one colour and a tinted painting is a smudge |
| Adaptive icon | Android | `res/mipmap-anydpi-v26/ic_launcher.xml` | background + foreground + monochrome. (`-v26` kept: renaming failed resource linking in an incremental AGP 9.4 build; lint ObsoleteSdkInt accepted) |
| Legacy launcher icon | Android | `res/mipmap-*dpi/ic_launcher.png` | 48/72/96/144/192 px squares for launchers below API 26 |
| App icon | iOS | asset catalogue, 19 sizes + 1024 | One opaque square, no alpha, no rounding of our own — the system masks it. **No alpha channel on any of them**: Apple rejects an App Store icon that carries one (ITMS-90717). See `AppIcon.appiconset/PROVENANCE.md` |
| Notification small icon | Android | `res/drawable/ic_stat_writing.xml` | 24dp, white on transparent; spark dropped (unreadable at 24dp). No iOS equivalent — iOS posts no notification (§5.1) |
| Launch screen | both | `values-v31/themes.xml` / `UILaunchScreen` | Mark on `brand_maroon` in light and dark on both: the first screen looks like the icon that was tapped |
| Window background | both | `colors.xml`, `values-night/colors.xml`, iOS root background | Matches the app surface — no white flash in dark mode on either platform |
| Store icon | both | `leaves/gtm/assets/appstore-icon-1024.png`, `playstore-icon-512.png` | Shipped with the pack, alpha flattened. Both listings use these |

Rules: the mark is **supplied artwork**, not generated — a brush-drawn அ, the first letter of the
Tamil alphabet and of அறிவு, *arivu*. There is no SVG that all three platforms render from any more,
because the art is painted and cannot be a path. The one thing generated from a path is the Android
themed layer, which has to be flat. `leaves/design/store-icon.svg` was the old speech-bubble mark
and is deleted: a stale "source of truth" is worse than none.
No text in the icon (no wordmark to translate). Judge it at 40 points, not at 1024.

---

## 10. Accessibility commitments

Commitments, not aspirations. Each is checked on a physical device of each platform before that
platform's release.

| Commitment | Android | iOS |
|---|---|---|
| Touch targets | ≥ 48 dp; Send/Stop 56 dp tall; licence, privacy and report rows ≥ 48 dp | ≥ 48 pt — deliberately above the 44 pt HIG floor, so that one number describes both apps and the layouts stay comparable |
| Screen reader: who said what | TalkBack reads "You wrote: …" / "Arivu wrote: …" | VoiceOver reads the same two sentences from the same keys, as each message row's accessibility label |
| Screen reader: reply progress | One persistent polite live region: "Arivu is writing", then how it ended ("Reply finished", "Stopped", "Cut off…", "Stopped: your phone ran low on memory…"). Tokens are **not** live | Same sentences, posted as polite announcements; the streaming bubble carries the same "Arivu is writing" state. Tokens are **not** announced — a token-level live region reads every word aloud and is unusable |
| Screen reader: buttons | Stop reads "Stop writing the reply"; Copy reads "Copy this message"; spinners are silent | Same labels from the same keys; the spinner is `.accessibilityHidden` (the text beside it speaks) |
| Screen reader: clipboard | "Copied" announced once | "Copied" announced once (§4) |
| Notices | The notice bar is a polite live region | The notice bar is announced and is reachable in the rotor |
| Headings and panes | Empty title, About sections, privacy sections, licences title, report sheet title and gate title are headings; About and the report sheet set pane titles; reasons read as a radio group | The same elements are headings (`.accessibilityAddTraits(.isHeader)`), so the VoiceOver rotor's heading list matches TalkBack's; the reason list reads as a single-select list with a selected row |
| Largest text | Usable at 200% font scale **and** the largest display size, together | Usable at **AX5** (`accessibilityExtraExtraExtraLarge`). Dynamic Type text styles only; never a fixed point size; `ScaledMetric` for anything sized in relation to text |
| Every screen scrolls | Empty state, About, gate — no fixed-height text containers; titles ellipsize rather than clip | Same, with the same three screens tested at AX5 |
| RTL | `supportsRtl`; start/end paddings only; user text direction follows its content | Leading/trailing only; verified in a right-to-left pseudolanguage; user text direction follows its content |
| Safe areas | `enableEdgeToEdge`; system bars ∪ display cutout; IME added after consuming Scaffold padding; gate uses `safeDrawingPadding` | Safe-area insets respected on every screen including the Dynamic Island and the home indicator; the input sits above the home indicator, never under it |
| Reduce Motion | Nothing animates except system transitions | Same — the setting is effectively a no-op here, because there is no typing animation and no decorative motion to remove |
| Reduce Transparency / Increase Contrast | No blur, no translucency anywhere | Same: nothing is translucent, so nothing degrades. Increase Contrast is satisfied by the table below, which is already above AA |
| Bold Text / Button Shapes (iOS) | — | Both honoured; our controls are words, so underlining and bolding them changes nothing structural |
| Contrast (WCAG 2.1 AA) | See table below; all text pairs ≥ 4.5:1 in both themes | **The same table, the same computed ratios.** The iOS palette is defined from the same three brand values and the same role names; no system tint is used anywhere |
| Long messages | Bubbles cap at 560 dp wide and wrap; the list follows the last line of a long reply; the input scrolls internally past 6 lines | Same caps in points, same behaviours |

### Colour and contrast (computed, WCAG relative luminance)

The same pairs, the same ratios, on both platforms. Android reads them from `ui/Theme.kt`; iOS defines
the same role names in its asset catalogue. Every role used by a component is set explicitly on both, so
no Material baseline purple and no iOS system blue leaks in.

| Pair | Light | Dark |
|---|---|---|
| onSurface / surface (body text) | 16.4 | 14.1 |
| onSurfaceVariant / surface (secondary text) | 8.8 | 10.7 |
| onSurfaceVariant / surfaceVariant (reply bubble, labels) | 7.7 | 8.3 |
| onPrimaryContainer / primaryContainer (user bubble) | 12.0 | 7.8 |
| primary / surface (About, Back, licence rows) | 7.5 | 10.3 |
| primary / surfaceVariant (Copy on reply) | 6.6 | 8.0 |
| primary / primaryContainer (Copy on user message) | 6.1 | 5.6 |
| onPrimary / primary (Send) | 7.8 | 9.1 |
| error / surfaceVariant (Cut off, Error, Low memory labels) | 5.5 | 8.3 |
| onErrorContainer / errorContainer (notice bar + OK) | 12.8 | 7.2 |
| outline / surface (input border, divider) | 4.4 | 5.8 |

---

## 11. Open design questions

- Example chips tappable (prefill input)? — D-030, proposed, unchanged by 0.2 (same answer both platforms).
- UI language for target markets — D-014. Whatever is decided applies to both catalogues at once.
- Store screenshots and feature graphic — Android set exists; the iOS set needs the same states
  recaptured at iPhone aspect ratios (§12).
- Whether "Reported" should also be announced by the live region — still open, now on both platforms.
- Report sheet reasons and copy were written by Engineering to the Compliance recommendation; Design
  still to review wording.
- Whether the iOS gate screen should name the specific device model it measured. Leaning no: the
  sentence already gives the number that matters, and naming the phone invites argument with it.

## 12. Proposed decisions (for `leaves/decisions.yml` — Design does not edit that file)

Numbers are provisional; other Leaves are proposing in the same range.

- **D-038 — The iOS privacy claim.** *Spine: C3, C5.* Android proves "no internet" with a missing
  permission; iOS cannot. Options: (a) reuse the Android sentence on iOS — rejected by Design, it is
  not true; (b) the weaker, true sentence ("no code that can reach the internet", backed by public
  source, a reproducible build and a Data Not Collected label); (c) hold iOS until a stronger proof
  exists. **Recommendation: (b)**, with Compliance owning the final text and GTM the listing.
  **Blocks release: yes, for iOS only.** Shipping the Android sentence on iOS would be a false claim.
- **D-039 — One copy catalogue, owned by Design.** *Spine: C5, C11.* `leaves/design/copy.md` becomes
  the source; `strings.xml` and the iOS String Catalog are renderings, checked for parity in CI.
  Options: one catalogue with per-platform overrides (recommended) / two independent files kept in step
  by review. **Blocks release: no**, but the cost of the wrong answer compounds with every string.
- **D-040 — Clipboard confirmation is Arivu's own where the OS gives none.** *Spine: C11.* The Copy
  button becomes "Copied" for 2 s on Android ≤ 12 and on all iOS; Android 13+ keeps the system
  confirmation and Arivu adds nothing. Options: this / a toast on Android and nothing on iOS (today) /
  Arivu confirms everywhere, doubling up on Android 13+. **Recommendation: as stated. Blocks release: no.**
- **D-041 — No local notifications on iOS.** *Spine: C3, C8, C10.* A background reply that runs out of
  time is reported when the user returns, not pushed. Options: no notifications (recommended) / ask for
  notification permission at first background generation. **Blocks release: no**, but asking would be
  the first permission prompt in a product whose pitch is that it asks for nothing.
- **D-042 — The iOS gate has no button.** *Spine: C6, R8.* Options: no button plus one line of removal
  instructions (recommended) / a button that opens Settings / a "Close Arivu" button. **Blocks release:
  no**, but it is the first screen some iOS users will see.
- **D-043 — iOS exclusion is a higher minimum iOS version, not a catalogue.** *Spine: C6, C11.* Design
  input only: the higher the floor, the fewer people meet the gate screen. Owner is Architecture/GTM;
  raised here because the gate's prominence is a design consequence. **Blocks release: no.**
- **D-044 — "Phone", not "iPhone", in shared sentences.** *Spine: C5, C11.* The platform noun changes
  only where the user must do something platform-shaped (Home Screen, Mail, App Store, Settings).
  **Recommendation: as stated. Blocks release: no.**

## 13. Proposed work items (for `leaves/sequencing/workitems.yml`)

- **W67** — Write `leaves/design/copy.md` into the iOS String Catalog with the same keys; no string
  authored in Swift. *Owner: iOS Engineering. Deps: this Leaf.*
- **W68** — `tools/check_copy.py`: fail the build when a key exists in one platform file and not the
  other without an explicit `android_only` / `ios_only` marker in the catalogue, or when a shared
  string's text differs. *Owner: Engineering.* This is what makes D-039 real rather than a promise.
- **W69** — Finish `stopped_low_memory` and `load_failed_low_memory` on Android (§7): take the agreed
  wording, rename `low_memory`, and announce the sentence in the live region when a reply ends this
  way. *Owner: Android Engineering.* Partly landed already.
- **W70** — Implement the clipboard confirmation change on Android ≤ 12 (§4). *Owner: Android Engineering.*
- **W71** — iPhone accessibility pass: VoiceOver, AX5 Dynamic Type, RTL pseudolanguage, Reduce
  Motion/Transparency, on a physical device. The iOS twin of W46. *Owner: Design.*
- **W72** — Contrast verification of the iOS palette against the §10 table, computed, not eyeballed.
  *Owner: Design.*
- **W73** — iOS screenshot set: the same seven states as the Android shot list, at iPhone aspect
  ratios, plus the gate screen, which on iOS is a first impression rather than an edge case.
  *Owner: GTM, with Design.*
- **W74** — 1024×1024 App Store icon rendered from the same SVG, verified against the system corner
  mask. *Owner: Design.*

## 14. Requests to other Leaves

**To the iOS Engineering Leaf**

1. Take every string from `leaves/design/copy.md` by key. Do not author a user-facing string in Swift,
   and do not translate an Android string by eye.
2. Route the background-expiration handler into the **same** cancel path as the Stop button, so the
   partial reply is saved by the same throttled save and labelled `stopped_backgrounded` (§5.1).
3. Keep Stop live during Starting, including the first-run map. On Android this was a real bug
   (`leaves/NOTES.md`, bug 2) and the first run is the most likely moment for someone to want out.
4. Exclude the conversation file from iCloud backup and device transfer, so that the privacy text's
   "stays only on this phone" is as true on iOS as on Android.
5. No notification permission prompt, no tracking prompt, no rating prompt, no onboarding. The empty
   chat is the first screen after the launch screen (§5.2).
6. The gate screen has no button (§5.4), and the report composer's copy is the iOS wording in §6 — the
   composer opens *inside* Arivu, so "your email app opens" would be wrong.
7. Tell me the measured time of the first cold model map on the test iPhone. If it is well under 15 s,
   `state_starting_long` is enough on its own and `state_starting_first_run` can be dropped — I would
   rather delete a string than ship one that is never the right thing to say.

**To the Android Engineering Leaf**

1. The low-memory wording is fixed in §7 — two strings, two placements, one of them replacing a
   generic failure message with a specific one. You have already landed `stopped_low_memory` and
   `low_memory`: please take the §7 text for the first, and rename the second to
   `load_failed_low_memory` with the §7 text. The reasons are in §7's reconciliation note; if either
   is wrong for a reason the code knows and I don't, tell me and I'll change the catalogue rather than
   have the two files disagree.
2. Please make the clipboard confirmation change in §4 (W70) so that one pattern describes both apps.
3. When the Report sheet copy is next touched, note that `report_sheet_privacy` and `report_send` now
   have iOS variants; the Android text itself is unchanged.

**To GTM**

The iOS gate screen will be seen by a materially larger share of iOS installs than the Android one is
(no device-exclusion catalogue). The listing should carry the memory and storage floor as plainly as it
carries "install on Wi-Fi", so that the screen confirms something the user was told rather than
surprising them after a 400 MB download.

**To Compliance**

D-038 is yours to settle. Design's requirement is only this: the iOS sentence must be *different* from
the Android one and must be as plain. A weaker true sentence is fine. The same sentence in both apps is
not.
