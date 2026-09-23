# iPhone screenshots — v0.1.0

Captured 2026-09-23 by `tools/ios/capture_screenshots.sh`, on **iPhone 18 Pro Max (Simulator)**,
**1320 × 2868** — Apple's 6.9" requirement exactly, so nothing is resized or padded.

Every image is the app answering for real, on the shipped Qwen3-1.7B, from build `0.1.0 (1)`.
Nothing is composited, framed or captioned. Apple allows a marketing mock-up here and most apps
ship one; Arivu's claim is that it does what it says on a phone with nothing behind it, and a
mocked-up screenshot is the first place that claim would quietly stop being true.

| File | Shows | Spine |
|---|---|---|
| `01-welcome.png` | What this is, in the first thing anyone sees | C1, C5 |
| `02-empty.png` | One screen. Nothing to configure, no account | C1, C8 |
| `03-rewrite.png` | The work it is FOR — a real rewrite, with what it cost underneath | C5 |
| `04-hedges.png` | **The important one.** Asked for a fact, it says it may be wrong and to check a source, instead of inventing a score | C5 |
| `05-prompt-disclosure.png` | The literal text the model was given, safety instructions and `<think>` block included | C5, C7 |
| `06-learn.png` | The model card, read live from the GGUF | C4, C5 |
| `07-try-it.png` | Counting tokens with the real tokenizer, against the real context budget | C5 |

## Suggested listing order

`04`, `03`, `05`, `01`, `06`. Lead with the hedge: it is the one claim no competitor makes and the
one a reviewer can verify in ten seconds. `07` and `02` are spares.

## Two things that went wrong, so they do not go wrong again

**The keyboard ate the frame.** It stays up after typing and covered half of `05`, cutting the
prompt off at the fold — twice, because the first fix tapped the navigation bar and SwiftUI does
not resign first responder on a tap. It dismisses on a DRAG
(`.scrollDismissesKeyboard(.interactively)`), and the chat shots are now taken after a relaunch, so
they photograph a conversation nobody has just typed into.

**Predictive text wrote into a listing image.** One capture shipped
*"The Who won the 2019 Cricket World Cup"* — the keyboard's suggestion bar, not the app. The
capture script turns the assists off, and because that does not always take effect, the test also
checks the field and retypes. A typo here is seen by everyone who opens the App Store page, and
nobody proofreads screenshots.

## Recapture when

Any of: the model changes, the system prompt changes (D-063 wording is visible in `05`), the icon
or palette changes, or the chat gains or loses a control. It is one command.
