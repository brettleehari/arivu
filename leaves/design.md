---
spine_version: 0.1
leaf: design
audience: product designers, UX research
---

# Design Leaf — interaction states and trust signals

Three screens. Copy lives in `android/app/src/main/res/values/strings.xml`; string keys are quoted here
so a copy change is one edit. Trust signals below are product decisions, not decoration: they are the
difference between a tool the user trusts and a tool the user tolerates.

## Verification model (product decision, not visual)

A 0.6B model cannot be made trustworthy about facts. The design does not pretend it can.
The user is invited to verify by **what the app refuses to imply**:

1. It never shows confidence scores, sources, or citations: it has none, and fake ones would be worse.
2. It says what it is bad at in three places: empty state, About, and the model's own system prompt (C5).
3. It shows the edge of its memory (context divider) and why a reply ended (stop labels) (C7).
4. It shows privacy by absence: there is nothing to sign in to, nothing to configure, no network toggle (C3, C8).
5. Its icon promises help with *your words* (a speech bubble holding lines of text), not an oracle (C5).

## Chat screen states

| State | Trigger | What the user sees | Keys | Spine |
|---|---|---|---|---|
| **Loading history** | app opened, conversation not yet read from disk | Nothing in the list area (no empty-state flash); Send disabled | — | C7 |
| **Empty** | no messages | Title "Works with no internet", what it's for, what it's bad at, "For example, you can write:" and 3 examples (plain text, not tappable). Scrolls if it does not fit | `empty_title`, `empty_body`, `empty_examples_label`, `empty_example_*` | C5 |
| **Composing** | typing | Send enabled only when input is non-blank; input grows to 6 lines (3 on screens under 480dp tall) | `input_hint`, `send` | |
| **Starting** | first send after launch or after model freed | Reply bubble appears at once (same moment as the user's bubble) with spinner "Starting Arivu. This can take a few seconds…" | `state_starting` | C1 |
| **Reading** | prefill in progress | Spinner "Reading…" — long pastes can take seconds | `state_reading` | C2 |
| **Streaming** | tokens arriving | Text grows in place; list follows the newest line *while the user is at the bottom*; Send becomes **Stop** | `stop` | C10 |
| **Done** | end of turn | No label; **Report** and **Copy** appear under the reply (Copy only, on the user's own messages) | `copy`, `report` | C9 |
| **Report sheet** *(provisional, pending Hari: Spine scope "Send, Stop, Copy, Report")* | Report tapped on a reply | Bottom sheet: title "Report this reply", one line why, "What is wrong?" + four single-select chips (Offensive · Harmful · Wrong in a dangerous way · Something else), optional note field, a line saying the email app sends it and that it includes the reply and note; **Cancel** / **Open email** (enabled once a reason is chosen) | `report_sheet_*`, `report_reason_*`, `report_note_label`, `report_send`, `cancel` | C9, C3 |
| **Reported** | Open email tapped | Label "Reported" under the reply (kept on the phone, survives restart); Report stays available to send again. The user's email app opens pre-filled (reply text, reason, note, version); without an email app, the share sheet opens with "To: address" in the text | `reported`, `report_reply_template`, `report_share_prefix` | C9 |
| **Stopped** | user tapped Stop (also while "Starting" or "Reading") | Partial text kept; label "Stopped". Stopped before any text: label only, no empty line | `stopped_by_user` | C10 |
| **Cut off** | context full mid-reply | Partial text kept; label in error colour: the next reply will leave out the oldest messages | `stopped_context_full` | C7 |
| **Reply limit** | max reply tokens | Label telling the user to send "continue" | `stopped_max_tokens` | |
| **Error** | decode failure | Label in error colour, "Try sending again" | `stopped_error` | |
| **Message too long** | newest message alone exceeds the context | Notice bar above input: "Try sending a part about N% as long" (no token counts: users don't know tokens, they know "half"). Message stays so it can be copied and shortened; the reply bubble that appeared is removed; nothing sent | `message_too_long` | C7 |
| **Load failed** | model could not load | Notice bar; no crash | `load_failed` | C6 |
| **Context divider** | oldest turns dropped from the prompt | Rule + "Arivu can no longer see the messages above this line" above the first message it saw | `context_divider` | C7 |
| **Process death mid-reply** | killed while streaming | On relaunch the partial reply (saved every ~2 s while streaming) is kept and labelled "Stopped" | `stopped_by_user` | C7 |
| **Backgrounded mid-reply** | user switches app | Reply keeps writing (foreground service; low-importance notification with `ic_stat_writing`) | `notification_writing` | C10 |

### Micro-patterns

- **Send ↔ Stop** occupy the same slot at the same minimum size (88×56dp), so the text field never
  jumps. There is never a moment with neither.
- **Report** and **Copy** are text buttons side by side at the end of a reply (Report first, so Copy keeps its place at
  the edge). Screen readers hear "Report this reply" / "Copy this message".
- **Copy** is a text button, not an icon: icon literacy varies; words don't. Shown on the user's own
  messages too (so a too-long message can be copied and shortened).
- **Back** on About is the word "Back", not an arrow, for the same reason.
- **Text selection** is enabled on messages (select part of a rewrite).
- **Clipboard confirmation**: Android 13+ shows the system confirmation; below 13 a short toast.
- **No typing animation, no fake delay.** Speed is what the phone does.
- **Follow, but don't yank**: while a reply streams the list stays on its last line. If the user scrolls
  up to read, following stops; scrolling back to the end or sending resumes it.
- **Keyboard**: the input asks the keyboard not to learn from what is typed (`IME_FLAG_NO_PERSONALIZED_LEARNING`;
  honoured by Gboard, not guaranteed elsewhere). `adjustResize` + `imePadding`; the input never hides behind the keyboard. Enter makes a
  new line (pasted text has paragraphs); Ctrl+Enter sends on a hardware keyboard. Sentence capitalisation.
- **User bubbles** sit at the end side with a 40dp start inset; replies at the start side with a 24dp end
  inset. Start/end, never left/right, so RTL mirrors.

## About screen

Sections in order: What Arivu is → Good at → **Not good at** → Private by design → **Privacy policy** (expand in
place) → Report a harmful reply (button) → Open-source licences (expand in place, "Notices (read first)" on top) → Version.

- **Privacy policy** *(provisional text)*: the full policy readable with no network, as headed sections (`privacy_*`),
  derived from `leaves/gtm/privacy-policy.html` and updated for per-reply reports (the report now includes the reply
  text). Same 48dp expand row as licences. Contact line shows the report address. The hosted page must say the same.

- **Report**: the general report (no specific reply); opens the user's email app pre-filled; falls back to the share sheet. Copy states that
  nothing is sent until the user sends it (C3, C9).
- **Licences**: every shipped component, including the model weights and libc++ (C4). Each row is a
  full-width 48dp touch target with a +/− marker and an Open/Closed state for screen readers.

## Incompatible-device screen (gate layer 3)

| Failure | Sentence shown | Key |
|---|---|---|
| No arm64-v8a | "This phone's processor is not a 64-bit ARM processor (arm64-v8a)." | `gate_abi` |
| Low-RAM device | "This phone is set up as a low-memory device." | `gate_low_ram` |
| Total RAM | "This phone has 2.0 GB of memory. Arivu needs at least 3.5 GB." (Android formats sizes in SI units: the 3.3 GiB floor reads 3.5 GB) | `gate_total_ram` |
| Storage | "This phone has 180 MB of free storage. Arivu needs at least 256 MB." | `gate_storage` |

Then one explanation paragraph and **one** full-width button: "Uninstall Arivu". No "continue anyway"
(R8), no close button, no crash, no `System.exit()`. Content stays clear of system bars and scrolls.

## Icon system

One mark, drawn once on a 108-unit grid, reused everywhere. **Concept:** a speech bubble holding three
lines of the user's text (the last one short, like a draft in progress) and a marigold spark: *help with
your words*. Not a brain, not a globe, not a chip — nothing that implies knowledge or a network.

| Asset | File | Notes |
|---|---|---|
| Palette | `res/values/colors.xml` | `brand_green` #1F5C4A, `brand_paper` #F5F1E6, `brand_amber` #D98E04 |
| Adaptive foreground | `res/drawable/ic_launcher_foreground.xml` | All geometry inside the 66dp safe circle (r 33 around 54,54) — survives circle, squircle and teardrop masks |
| Adaptive background | `res/drawable/ic_launcher_background.xml` | Brand green, faint diagonal gradient #2A6E5A → #1A4F40 |
| Themed icon (Android 13+) | `res/drawable/ic_launcher_monochrome.xml` | Single silhouette; lines and spark cut out (evenOdd) |
| Adaptive icon | `res/mipmap-anydpi-v26/ic_launcher.xml` | background + foreground + monochrome. (`-v26` kept: renaming to `mipmap-anydpi` failed resource linking in an incremental AGP 9.4 build, not yet investigated; lint ObsoleteSdkInt warning accepted) |
| Notification small icon | `res/drawable/ic_stat_writing.xml` | 24dp, white on transparent, bubble + three cut-out lines; spark dropped (unreadable at 24dp) |
| Splash (Android 12+) | `res/values-v31/themes.xml`, `values-night-v31` | Mark on brand green in both light and dark: the first screen looks like the icon that was tapped |
| Window background | `res/values/colors.xml`, `values-night/colors.xml` | Matches Compose `surface` — no white flash in dark mode |
| Play Store icon | `leaves/design/store-icon.svg` → `store-icon-512.png` | 512×512 RGBA PNG, full-bleed square (Play applies mask and shadow). Rendered with headless Chrome from the SVG; re-render after any geometry change |

Rules: the Android vectors and the SVG share path data verbatim — change one, change all. No text in
the icon (no wordmark to translate). No dynamic colour in-app: brand and contrast must hold on every
OEM skin.

## Accessibility commitments

Commitments, not aspirations. Each is checked on the test phone before a release (see W-proposals).

| Commitment | How the UI meets it |
|---|---|
| Touch targets ≥ 48dp | Material buttons enforce 48dp minimum interactive size; Send/Stop 56dp tall; licence and privacy rows 48dp min; report chips and sheet buttons 48dp min |
| Screen reader: who said what | Each message is read as "You wrote: …" / "Arivu wrote: …" (`a11y_from_user`, `a11y_from_arivu`) |
| Screen reader: reply progress | One persistent polite live region announces "Arivu is writing", then how it ended ("Reply finished", "Stopped", "Cut off…"). Tokens are **not** live (would read every word). Streaming bubble carries state "Arivu is writing" |
| Screen reader: buttons | Stop reads "Stop writing the reply"; Copy reads "Copy this message"; spinners are silent (the text beside them speaks) |
| Notices | Notice bar is a polite live region |
| Headings & panes | Empty title, About section titles, privacy policy section titles, licences title, report sheet title and gate title are headings; About and the report sheet set pane titles; reason chips are a selectable group read as radio buttons |
| Text scaling to 200% | Every screen scrolls (empty state, About, gate); no fixed-height text containers; top-bar titles ellipsize rather than clip |
| RTL | `supportsRtl`; start/end paddings and alignments only; user text direction follows its content |
| Edge-to-edge | `enableEdgeToEdge`. Chat and About: Scaffold with system bars ∪ display cutout, top bar handles top + horizontal, IME added after consuming Scaffold padding (never double-counted). Gate: `safeDrawingPadding` |
| Contrast (WCAG 2.1 AA) | See table below. All text pairs ≥ 4.5:1 in both themes |
| Long messages | Bubbles cap at 560dp wide and wrap; list follows the last line, not the top, of a long reply; input scrolls internally past 6 lines |

### Colour and contrast (computed, WCAG relative luminance)

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
| error / surfaceVariant (Cut off, Error labels) | 5.5 | 8.3 |
| onErrorContainer / errorContainer (notice bar + OK) | 12.8 | 7.2 |
| outline / surface (input border, divider) | 4.4 | 5.8 |

All colour roles used by our components are set explicitly in `ui/Theme.kt` so no Material baseline
purple leaks in.

## Copy

Rules (also at the top of `strings.xml`):

- Plain words, short sentences; many readers use English as a second language. No "tokens", "context",
  "comprehension". Tell the user what to do next.
- One idea per string. No concatenation in code; positional placeholders (`%1$s`, `%1$d`) with a
  translator comment saying what each is.
- `translatable="false"` for the product name and pure-format strings (`app_name`, `about_license_entry`).
- British spelling, consistently (summarise, licences, maths). UI language itself is D-014.
- Typographic apostrophes and quotes (’ “ ”) rather than escaped ASCII.

## Open design questions

- Example chips tappable (prefill input)? Small, but a scope question — D-011's sibling. Proposed as a decision.
- UI language for target markets — D-014.
- Store screenshots and feature graphic — requested from Engineering/GTM (states listed in the hand-off).
- ~~Empty state flashes while history loads~~ — done: `ChatUiState.loaded` (Engineering, 2026-09-15).
- Report sheet reasons and copy were written by Engineering to the Compliance recommendation; Design to review wording
  and whether "Reported" should also be announced by the live region.
