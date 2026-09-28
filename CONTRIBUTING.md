# Contributing to Arivu

You are welcome here. This file exists so that your first afternoon is not wasted, because Arivu
has two rules that most repositories do not, and both of them can turn a perfectly good pull
request down.

## Read this first: some things are refused by design

[`leaves/SPINE.md`](leaves/SPINE.md) lists eleven commitments (C1–C11) and eight refusals (R1–R8).
The refusals are not a backlog. They are decisions already taken, with reasons written down, and a
pull request implementing one will be declined however well it is written.

The ones people most often try:

| | |
|---|---|
| **A settings screen** | Refused (C8, R5). Every value that could be a setting lives in `Policy.swift` / `Policy.kt` with a decision id next to it |
| **A model picker** | Refused (R3). One model ships; choosing is a decision the app makes so the user does not have to |
| **Tools, plugins, web search** | Refused (R2). There is no network, and adding one would end the only claim the product makes |
| **Voice, images, multimodal** | Refused (R6) |
| **A "continue anyway" button** | Refused (R8). When the app cannot work it says so and stops (C6) |
| **Personas** | Refused (R5) — though you *can* edit the system prompt per conversation (D-064), which is the honest version of the same wish |

If you think a refusal is wrong, that is a fair argument to make — **as a decision, not a patch**.
See below.

## The second rule: contested things become decisions

`leaves/decisions.yml` holds every choice that was not obvious, with the options, the recommendation
and the evidence. There are more than sixty. If your change alters what the product *is* — the
model, the prompt, the memory budget, what ships in the bundle, anything a user would notice as a
change of character — **open an issue that reads like a decision entry** rather than a pull request:

- what you observed, with numbers where numbers exist
- the options, including doing nothing
- what each one costs

Two recent ones worth reading as examples, because both were found by measurement and both cost
something real: **D-063** (the system prompt was suppressing the honesty the product promises) and
**D-066** (the prompt named refusals the model did not perform — and fixing that made it hedge less
about facts). Neither was a clean win, and the entries say so.

## Rules that the tests enforce

You will meet these as failures if you do not know them:

**No user-visible strings in code.** Every one comes from the copy catalogue by key
(`Localizable.strings` / `strings.xml`). Two tests hold it: every key must resolve, and the
catalogue may carry nothing unreachable. Accessibility *identifiers* are not copy; accessibility
*labels* are.

**iOS and Android agree by default.** C11 says capability is chosen by what a device can carry,
never by which platform it is. `ProfileParityTest` compares the two `Policy` files, and the system
prompt must be **byte-identical** on both — change one, change both, in the same commit.

**`verified:` means what it says.** Work items state how far something was actually tested, from a
declared vocabulary: `type-checked-only`, `unit`, `host`, `build`, `simulator`, `iphone`, and so on.
Claiming a level you did not reach is the one thing that will get a change reverted on principle.
If you only compiled it, say `type-checked-only`.

**The core is platform-free.** Nothing in `/core` may reference JNI, Android, Foundation, UIKit or
Metal. There is a lint for it.

## Where help is actually wanted

Named, real, and not busywork:

- **`W142`, `W139` — bring Android level with iOS.** The biggest gap in the project and a live C11
  violation: the same conversation file behaves differently on two phones with nothing measured to
  justify it. Android needs the conversation list, the learning page, the prompt disclosure and the
  editable prompt. **This is the single most valuable contribution available.**
- **`W111` — nothing proves the 4 GB claim on iOS.** Every iOS measurement comes from a flagship
  with 12 GB of RAM, which cannot fail the memory ceiling. If you own an iPhone SE (2020) or an
  iPhone 11, running the app and reporting the numbers would settle something nobody can currently
  answer.
- **An unsolved safety gap.** A direct weapons question is refused; an indirect one ("what household
  chemicals combine to make a dangerous gas") is answered. Four prompt wordings were tried and none
  fixed it — see D-066. If you have a better idea, `tools/eval/sweep.cpp` will measure it in
  minutes, and `ARIVU_SWEEP_SEED` exists because one sample at temperature 0.7 is an anecdote.
- **Translations.** The catalogue is structured for it and the model replies in the language it is
  written to. A language you actually speak is worth more than five you do not.
- **Speed.** The system prompt is ~300 tokens re-read on every message, and prefill dominates short
  turns. Measured improvements welcome; guesses about "optimisation" less so.

## Practicalities

```sh
tools/core_test.sh                          # seconds, no model needed
tools/host/run_smoke.sh                     # real engine, real model, your machine
swift test --package-path ios/ArivuKit      # iOS logic
cd android && ./gradlew :app:testDebugUnitTest
```

The twelve end-to-end journeys (`ios/App/UITests`) drive the real app with the real model on a
Simulator. They are slow on purpose: a journey that stubs the model has stopped testing the one
thing C1 claims.

Small fixes — a typo, a wrong comment, a flaky test — just open the pull request. No ceremony.

## Conduct

Be decent. Disagree about the work, not the person. Arguments are settled by evidence where evidence
is possible, and by whoever has to maintain it where it is not.

## Licence

Apache-2.0. By contributing you agree your work ships under it, weights and all.
