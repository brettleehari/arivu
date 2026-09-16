---
spine_version: 0.2
leaf: design
owner: Design
audience: Android and iOS engineers, Compliance, GTM, translators
---

# Copy catalogue — one text, two platforms

This file is the **source** for every user-facing string in Arivu. `strings.xml` (Android) and the iOS
String Catalog are renderings of it. Neither platform file is authoritative, and no user-facing string
is authored in Kotlin or Swift.

Proposed as decision **D-039**. Proposed parity check: **W68** (`tools/check_copy.py`) fails a build
when a key is present on one platform and absent on the other without an explicit `platforms:` marker,
or when a shared string's text differs between the two files.

## Rules

1. Plain words, short sentences. Many readers use English as a second language.
2. One idea per string. **Never build a sentence by joining strings in code.** A state that needs
   different words gets a different key (see `state_starting` → `state_starting_long`).
3. Positional placeholders (`%1$s`, `%1$d`) with a comment saying what each one is.
4. British spelling, consistently (summarise, licences, maths). UI language is D-014.
5. Typographic apostrophes and quotes (’ “ ”).
6. No jargon: never "token", "context", "model" where avoidable, never "foreground service", "jetsam",
   "mmap", "buffer".
7. Tell the user what they can do next.
8. **"Phone", not "iPhone"** in shared sentences (D-044). A platform noun appears only where the user
   must do something platform-shaped: Home Screen, Mail, the App Store, a Settings path.
9. `platforms:` on an entry means it is rendered only there. `ios:` on an entry means the same key
   carries different text on iOS; the key, its meaning and its placement are still shared.
10. A string may diverge **only** for a platform noun or a platform fact. Never for tone, never for
    structure, and never for a claim.

## Status of the privacy text

The `privacy_*` bodies are owned by **Compliance** (D-022, W43), not Design, and still carry
placeholders. Their current Android text lives in `strings.xml` and in
`leaves/gtm/privacy-policy.html`. This catalogue records **which of them must diverge on iOS and how** —
the final words are Compliance's to write, in both platform renderings at once.

---

## The catalogue

```yaml
# ---------------------------------------------------------------------------
# Product
# ---------------------------------------------------------------------------
app_name:
  text: "Arivu"
  translatable: false

# ---------------------------------------------------------------------------
# Chat — controls
# ---------------------------------------------------------------------------
input_hint:   { text: "Type or paste your text" }
send:         { text: "Send" }
stop:         { text: "Stop" }
copy:         { text: "Copy" }
copied:
  text: "Copied"
  note: >
    Two uses, same word. (a) the Copy button's own label for 2 s where the OS confirms nothing
    (Android <= 12, all iOS — design.md §4); (b) the screen-reader announcement, on both platforms.
ok:           { text: "OK" }
back:
  text: "Back"
  platforms: [android]
  note: Android's About back control is the word. iOS uses the native back control, which carries the parent title.
about:        { text: "About" }
cancel:       { text: "Cancel" }
report:       { text: "Report" }
reported:     { text: "Reported" }

# ---------------------------------------------------------------------------
# Chat — empty state (an honesty statement: identical on both platforms)
# ---------------------------------------------------------------------------
empty_title:  { text: "Works with no internet" }
empty_body:
  text: |
    Arivu helps with text you give it. It can rewrite, shorten, explain, summarise and draft.

    It runs only on this phone. It is not good at facts, news or numbers, so check anything important.
empty_examples_label: { text: "For example, you can write:" }
empty_example_1: { text: "Rewrite this to sound polite: …" }
empty_example_2: { text: "Explain this paragraph in simple words: …" }
empty_example_3: { text: "Write a short letter to parents about …" }

# ---------------------------------------------------------------------------
# Chat — engine states
# ---------------------------------------------------------------------------
state_starting:
  text: "Starting Arivu. This can take a few seconds…"
state_starting_first_run:            # NEW in 0.2 — design.md §5.2
  text: "Starting Arivu for the first time. This is the slowest it will ever be. Keep Arivu open."
  note: >
    First send after install only, on either platform. Fires on iOS in practice, because the 400 MB
    model file is read cold from the bundle with nothing in the page cache.
state_starting_long:                 # NEW in 0.2 — design.md §5.2
  text: "Still starting Arivu. Keep Arivu open."
  note: Replaces the line after 15 s. Replaces — never appended to it (rule 2).
state_reading:
  text: "Reading…"

# ---------------------------------------------------------------------------
# Chat — why a reply ended. Same words, same slot, same colour role, both platforms.
# ---------------------------------------------------------------------------
stopped_by_user:
  text: "Stopped"
  note: Also the label for a reply lost to process death. The app cannot know why it was killed, so it does not guess.
stopped_context_full:
  text: "Cut off: this conversation is now too long for Arivu to hold. Its next reply will leave out the oldest messages."
stopped_max_tokens:
  text: "This reply reached its length limit. Send “continue” to get more."
stopped_error:
  text: "Something went wrong while writing this reply. Try sending again."
stopped_low_memory:                  # NEW in 0.2 — design.md §7
  text: "Stopped: your phone ran low on memory. Close other apps, then send “continue” to get the rest."
  note: >
    Shown only when memory pressure interrupts a reply in flight. Silent when the context is freed with
    nothing in flight — nothing of the user's was lost, so there is nothing to tell them.
    RECONCILE: the Android Leaf landed this key in parallel as "Stopped because your phone is low on
    memory. Close some other apps, then try again." Please take the text above instead. Two changes,
    both deliberate: it opens with the word "Stopped:" so it reads in the same shape as "Cut off:" in
    the slot beside it, and it says send "continue" rather than "try again" — the partial reply is
    still on screen, so "try again" leaves the user guessing whether to re-send their own message.
stopped_backgrounded:                # NEW in 0.2 — design.md §5.1
  text: "Stopped: Arivu cannot keep writing while you are in another app. Send “continue” to get the rest."
  platforms: [ios]
  note: >
    Not iOS-only by policy — it fires wherever the background allowance runs out before the reply ends.
    Android's ~3 min service window means it does not fire there today. Ship the string on both if the
    Android window ever shortens; no wording change needed (C11).

# ---------------------------------------------------------------------------
# Chat — notices above the input
# ---------------------------------------------------------------------------
message_too_long:
  text: "This message is too long for Arivu to read at once. Try sending a part about %1$d%% as long."
  placeholders: { "%1$d": "how long a shorter part should be, as a percentage of this message (1–99)" }
load_failed:
  text: "Arivu could not start on this phone. Close Arivu fully, then open it again."
  ios:  "Arivu could not start on this phone. Close Arivu from the app switcher, then open it again."
  note: Diverges only because the two systems are closed by different gestures.
load_failed_low_memory:              # NEW in 0.2 — design.md §7
  text: "Arivu could not start: your phone is low on memory. Close other apps, then send your message again."
  note: >
    Replaces the generic load_failed when the cause is memory. A generic message for a specific,
    actionable cause sends the user to a remedy that will not help.
    RECONCILE: the Android Leaf landed a key named `low_memory` in parallel, with the text "Arivu
    stopped because your phone is low on memory. Close some other apps, then try again." If that is
    the notice-bar string for a load that failed on memory, please rename it `load_failed_low_memory`
    and take the text above — "stopped" is the wrong verb for something that never started, and the
    name should say which of the two moments it belongs to.

# ---------------------------------------------------------------------------
# Chat — the edge of the model's memory (C7). Identical by policy.
# ---------------------------------------------------------------------------
context_divider:
  text: "Arivu can no longer see the messages above this line"

# ---------------------------------------------------------------------------
# Background generation — Android only (iOS posts nothing; design.md §5.1, D-041)
# ---------------------------------------------------------------------------
notification_channel: { text: "Writing replies", platforms: [android] }
notification_writing: { text: "Arivu is writing a reply", platforms: [android] }

# ---------------------------------------------------------------------------
# Screen readers — TalkBack and VoiceOver read the same sentences
# ---------------------------------------------------------------------------
a11y_from_user:
  text: "You wrote: %1$s"
  placeholders: { "%1$s": "the message text the user wrote" }
a11y_from_arivu:
  text: "Arivu wrote: %1$s"
  placeholders: { "%1$s": "the reply text Arivu wrote" }
a11y_writing:        { text: "Arivu is writing" }
a11y_reply_done:     { text: "Reply finished" }
a11y_copy_message:   { text: "Copy this message" }
a11y_report_reply:   { text: "Report this reply" }
a11y_stop:           { text: "Stop writing the reply" }
a11y_expanded:       { text: "Open" }
a11y_collapsed:      { text: "Closed" }

# ---------------------------------------------------------------------------
# Report a reply
# ---------------------------------------------------------------------------
report_sheet_title:  { text: "Report this reply" }
report_sheet_body:   { text: "Tell us what is wrong with this reply. It helps us make Arivu safer." }
report_reason_label: { text: "What is wrong?" }
report_reason_offensive:       { text: "Offensive" }
report_reason_harmful:         { text: "Harmful" }
report_reason_wrong_dangerous: { text: "Wrong in a dangerous way" }
report_reason_other:           { text: "Something else" }
report_note_label:   { text: "Anything to add? (optional)" }
report_sheet_privacy:
  text: "Arivu cannot use the internet, so your email app sends the report. It will include this reply and your note. Nothing is sent until you press send there."
  ios:  "Arivu cannot use the internet, so your Mail app sends the report. The message opens here, already written, with this reply and your note in it. Nothing is sent until you press send."
  note: >
    Diverges on a platform fact: on iOS the composer is presented inside Arivu, so "your email app
    opens" would describe something the user does not see.
report_send:
  text: "Open email"
  ios:  "Write the email"
  note: The iOS button does not leave the app, so "Open email" would promise the wrong thing.
report_no_note: { text: "(none)" }
report_reply_template:
  text: |
    Reason: %2$s

    My note: %3$s

    The reply Arivu wrote:
    %4$s

    App version: %1$s
  placeholders:
    "%1$s": app version
    "%2$s": reason
    "%3$s": the user's note
    "%4$s": the reply text
report_share_prefix:
  text: |
    To: %1$s

    %2$s
  placeholders: { "%1$s": report address, "%2$s": report text }
  note: Fallback when there is no email app (Android) / no Mail account (iOS). Same shape on both.

# ---------------------------------------------------------------------------
# About
# ---------------------------------------------------------------------------
about_title:      { text: "About Arivu" }
about_what_title: { text: "What Arivu is" }
about_what_body:
  text: "A helper for writing and understanding text, with no internet. A small language model (Qwen3 0.6B) runs fully on this phone."
about_good_title: { text: "Good at" }
about_good_body:
  text: "Rewriting, shortening, explaining, summarising and drafting text you give it."
about_bad_title:  { text: "Not good at" }
about_bad_body:
  text: "Facts, news, dates, numbers, maths, and medical or legal answers. It can sound sure and still be wrong."
  note: >
    Honesty statement (C5). Identical on both platforms, word for word, and identical to the store
    listing's version of the same sentence.
about_private_title: { text: "Private by design" }
about_private_body:
  text: "Arivu has no permission to use the internet. Your messages stay only on this phone and are not backed up."
  ios:  "Arivu has no code that can reach the internet — you can check that, because Arivu is open source. Your messages stay only on this phone and are not backed up."
  note: >
    The one divergence that changes a claim, not a noun (design.md §1, D-038). Android's sentence is
    enforced by the OS and checked in every build; iOS has no permission to withhold. Compliance owns
    the final iOS wording. The iOS sentence's "not backed up" is only true once the conversation file
    is excluded from iCloud backup and device transfer — request 4 to the iOS Leaf.
about_report_title: { text: "Report a harmful reply" }
about_report_body:
  text: "If Arivu wrote something offensive or harmful, tap Report under that reply. You can also send a general report here. Both open your email or messaging app. Nothing is sent until you send it."
  ios:  "If Arivu wrote something offensive or harmful, tap Report under that reply. You can also send a general report here. Both open a message in your Mail app, already written. Nothing is sent until you send it."
about_report_button:  { text: "Report a reply" }
about_report_subject: { text: "Arivu: report of harmful output" }
about_report_template:
  text: |
    Paste the reply here:


    What was wrong with it:


    App version: %1$s
  placeholders: { "%1$s": app version }
about_licenses_title: { text: "Open-source licences" }
about_license_entry:
  text: "%1$s · %2$s"
  translatable: false
  placeholders: { "%1$s": component name, "%2$s": "licence id such as MIT" }
about_version:
  text: "Version %1$s"
  placeholders: { "%1$s": app version }
  note: Once both platforms ship, this row also shows the shared core version (MULTIPLATFORM.md).

# ---------------------------------------------------------------------------
# Privacy policy, readable offline.
# Text owned by Compliance (D-022 / W43). This catalogue records the divergences only.
# ---------------------------------------------------------------------------
about_privacy_policy: { text: "Privacy policy" }
privacy_intro:
  text: "Privacy policy for Arivu on Android, version %1$s."
  ios:  "Privacy policy for Arivu on iPhone, version %1$s."
  placeholders: { "%1$s": app version }
privacy_short_title: { text: "The short version" }
privacy_short_body:
  source: strings.xml
  ios_diverges: true
  ios_change: >
    First sentence only. Android: "Arivu has no permission to use the internet. Android does not let it
    send anything anywhere." iOS: no permission exists to withhold — say instead that Arivu contains no
    networking code, that it is open source so anyone can check, and that the App Store privacy label
    says Data Not Collected. Everything after that first sentence is unchanged.
privacy_internet_title:
  text: "Arivu cannot connect to the internet"
  ios:  "Arivu has no way to reach the internet"
privacy_internet_body:
  source: strings.xml
  ios_diverges: true
  ios_change: >
    Full rewrite. The Android text enumerates the Android permissions Arivu asks for and the one it
    does not. iOS has no such list. The iOS text says: no networking code and no network libraries are
    linked; the source is public and the build is reproducible, so the claim is checkable rather than
    granted; the App Store privacy label says Data Not Collected. Plain words, same length, no
    hedging. Compliance owns the final sentence (D-038).
privacy_stored_title: { text: "What is stored on your phone" }
privacy_stored_body:
  source: strings.xml
  ios_diverges: true
  ios_change: >
    Same content, different mechanisms. Android: app sandbox, backup and transfer turned off for all of
    Arivu's storage, file not encrypted by Arivu itself. iOS: app-private storage with Data Protection,
    encrypted at rest by the system, excluded from iCloud backup and device transfer. Both keep the
    closing sentence: anyone who can unlock the phone and open Arivu can read the conversation.
privacy_collect_title: { text: "What we collect" }
privacy_collect_body:  { source: strings.xml, ios_diverges: false }
privacy_report_title:  { text: "Reporting a reply" }
privacy_report_body:
  source: strings.xml
  ios_diverges: true
  ios_change: >
    Names Mail and the share options instead of "your own email app (or Android's share menu)", and says
    the message opens inside Arivu. The substance — only that reply, never the rest of the conversation;
    nothing sent until the user sends it; what we do with a report — is unchanged.
privacy_copy_title: { text: "Copying text and your keyboard" }
privacy_copy_body:
  text: "Copy puts text on your phone’s clipboard, like any copied text. Arivu asks your keyboard app not to learn from what you type here, but Arivu cannot see or control what your keyboard app does. Other apps work under their own privacy policies."
  ios:  "Copy puts text on your phone’s clipboard, like any copied text. Your keyboard learns from what you type in every app, and iPhone gives Arivu no way to turn that off. Other apps work under their own privacy policies."
  note: >
    A platform fact, and an uncomfortable one: Android has IME_FLAG_NO_PERSONALIZED_LEARNING and iOS has
    no equivalent. Saying so is cheaper than implying a protection we cannot provide.
privacy_play_title:
  text: "Google Play"
  ios:  "The App Store"
privacy_play_body:
  source: strings.xml
  ios_diverges: true
  ios_change: >
    Same three facts with the store's name swapped: you install and update through the store, which has
    its own privacy policy and gives developers summary statistics; installing uses data; once
    installed, Arivu itself uses none.
privacy_children_title: { text: "Children" }
privacy_children_body:  { source: strings.xml, ios_diverges: false }
privacy_choices_title:  { text: "Your choices" }
privacy_choices_body:
  source: strings.xml
  ios_diverges: true
  ios_change: >
    Android tells the user they can clear storage from Settings. iOS has no way to clear one app's
    storage, so the iOS text says: "To delete your conversation, delete Arivu: touch and hold its icon
    on the Home Screen, then choose Delete App. iPhone has no way to clear one app’s storage without
    deleting the app." The rest — open source, and rights over a report already sent — is unchanged.
privacy_changes_title: { text: "Changes" }
privacy_changes_body:  { source: strings.xml, ios_diverges: false }
privacy_contact_title: { text: "Contact" }
privacy_contact_body:
  text: "%1$s"
  placeholders: { "%1$s": privacy and report contact address }

# ---------------------------------------------------------------------------
# Device gate (C6, R8). Same sentences; different endings, because iOS cannot uninstall itself.
# ---------------------------------------------------------------------------
incompatible_title: { text: "Arivu can’t run well on this phone" }
incompatible_body:
  text: "Arivu runs a language model on the phone itself. That needs more than this phone has. Rather than run slowly or crash, Arivu will not start."
  note: Identical on both platforms. True of an iPhone as written.
incompatible_uninstall:
  text: "Uninstall Arivu"
  platforms: [android]
incompatible_remove_ios:             # NEW in 0.2 — design.md §5.4
  text: "To remove Arivu: touch and hold its icon on the Home Screen, then choose Delete App."
  platforms: [ios]
  note: >
    A line of text, not a button. iOS gives an app no way to delete itself, and exit() reads as a crash.
    A dead button would be worse than a true sentence.
gate_abi:
  text: "This phone’s processor is not a 64-bit ARM processor (arm64-v8a)."
  platforms: [android]
  note: No supported iPhone can fail this check, so iOS does not run it.
gate_low_ram:
  text: "This phone is set up as a low-memory device."
  platforms: [android]
  note: No iOS equivalent flag.
gate_total_ram:
  text: "This phone has %1$s of memory. Arivu needs at least %2$s."
  placeholders: { "%1$s": "this phone's memory", "%2$s": "memory Arivu needs" }
  note: >
    Both platforms. Android reads MemoryInfo.totalMem; iOS reads ProcessInfo.physicalMemory. Sizes are
    formatted by the platform (Android's SI units make the 3.3 GiB floor read "3.5 GB").
gate_storage:
  text: "This phone has %1$s of free storage. Arivu needs at least %2$s."
  placeholders: { "%1$s": free storage now, "%2$s": storage Arivu needs }
```

---

## Keys that are new in 0.2

| Key | Platforms | Where it appears |
|---|---|---|
| `stopped_low_memory` | both | stop label under a partial reply (design.md §7) |
| `load_failed_low_memory` | both | notice bar above the input (§7) |
| `stopped_backgrounded` | iOS today | stop label under a partial reply (§5.1) |
| `state_starting_first_run` | both, fires on iOS | the Starting bubble, first send after install (§5.2) |
| `state_starting_long` | both | the Starting bubble, after 15 s (§5.2) |
| `incompatible_remove_ios` | iOS | device gate, in place of the button (§5.4) |

## Keys that carry a different iOS text

`about_private_body` · `about_report_body` · `report_sheet_privacy` · `report_send` · `load_failed` ·
`privacy_intro` · `privacy_internet_title` · `privacy_internet_body` · `privacy_short_body` ·
`privacy_stored_body` · `privacy_report_body` · `privacy_copy_body` · `privacy_play_title` ·
`privacy_play_body` · `privacy_choices_body`

Fifteen strings out of roughly ninety. Ten of them are the privacy policy, one is the claim underneath
it (D-038), and the remaining four are a mail composer, an app switcher and a Home Screen. Everything
the product says about **what it is, what it is bad at, and why a reply ended** is identical, which is
the point.
