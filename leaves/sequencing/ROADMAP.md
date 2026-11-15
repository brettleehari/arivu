---
spine_version: 0.2
leaf: sequencing
artifact: Release roadmap for Arivu, written 2026-11-15 after studying how PocketPal actually ships
---

# Roadmap

## What was learned from watching a competitor ship

PocketPal publishes no roadmap. One line in its README — "tool use expansion" — and a pointer to
the issue tracker. What it publishes instead is **releases**: ten of them between 4 October and
10 November 2026.

| | | |
|---|---|---|
| v1.19.0 | 4 Oct | in-app purchase infrastructure |
| v1.20.0 | 14 Oct | QR scan, Sign in with Apple |
| v1.20.1 | 19 Oct | Arabic |
| v1.21.0 | 23 Oct | voice input via Whisper + the paid tier |
| v1.21.1 | 25 Oct | faster Whisper on Android |
| v1.21.2 | 26 Oct | iOS Metal decode performance |
| v1.21.4 | 28 Oct | voice offline stability |
| v1.22.0 | 30 Oct | new icon |
| v1.23.0 | 10 Nov | local OpenAI-compatible server |

Four things in that sequence are worth copying, and none of them is a feature.

**Infrastructure lands before the thing it carries.** The purchase system shipped in 1.19; the
subscription that needed it shipped in 1.21, three weeks later. Nobody built both at once.

**Performance is interleaved, never batched.** Android dotprod on the 25th, iOS Metal decode on
the 26th. Small, measured, shipped — not saved for a "performance release" that never comes.

**They fix forward within days.** 1.21.0, .1, .2 and .4 inside five days of shipping voice. The
alternative is holding a release until it is perfect, which is how 1.0 stops shipping at all.

**The cadence is the strategy.** Weekly-ish, small, visible. A roadmap document is what you write
when you are not shipping.

Arivu has shipped nothing. That is the gap, not the feature list.

## The ordering rule for this project

Not "what would be nice next". **What is blocked on what, and what carries the most risk if wrong.**
Arivu's Spine refuses most of what PocketPal built — tools (R2), model picker (R3), personas and
settings (R5), voice and multimodal (R6) — so copying their backlog would mean becoming them. What
transfers is the discipline, not the direction.

---

## v1.0 — ship it

**One action remains and it has been the same one since 30 September:** reply to App Review with the
recording. Everything else — listing, screenshots, age rating measured against the shipped model,
privacy label, pricing, signed build — is done and verified.

Nothing below this line matters until this ships. A roadmap for an app that has never been in
anyone's hands is fiction.

**Deadline that is real:** build 2 expires around 22 December. After that this becomes a re-archive
and a gigabyte upload before you can even answer.

## v1.0.x — learn to fix forward

The habit to build, not a feature. Whatever the first users find, ship the fix in days and not
weeks. PocketPal shipped four patches in five days after voice; that is what a live product looks
like.

Expect the first reports to be about the things already known: the slow first launch, and facts
stated with too much confidence.

## v1.1 — speed, measured

Two levers, both already instrumented and neither yet pulled:

**Metal.** D-051 refused the GPU on a memory argument that is right for a 4 GB phone and unproven
for a 12 GB one. C11 says capability by device, so "Metal where the device can afford it" is more
faithful to the Spine than a blanket refusal. `Experiment.swift` runs the 2x2 and reports
tokens/sec *and* peak charged footprint together — speed alone would answer the easy half.

**The thread clamp.** `[2, 4]` performance cores, inherited from an Android cpufreq heuristic and
copied to iOS for symmetry. On a 2P+4E phone that asks for 2 threads where PocketPal's heuristic
asks for 4. Same experiment, same run.

Neither changes the model, so neither disturbs the safety measurements. That is why this is v1.1
and the model tier is not.

## v1.2 — Android parity

The largest debt in the project and a live C11 violation: the same conversation file behaves
differently on two phones with nothing measured to justify it. Android has five screens to iOS's
twelve — no conversation list, no learning page, no prompt disclosure, no editable prompt.

**It cannot ship as it stands, and the reason is not the missing screens.** D-066 measured the
child-safety case on the model Android carries: Qwen3-0.6B writes the story in 6 of 8 samples with
the identical prompt that makes 1.7B refuse it 5 of 5. Refusal behaviour belongs to the model.
Android needs 1.7B, or a wording that works at 0.6B, before anything else about it is worth doing.

## v1.3 — a better model where the device can carry one

3B-class is now the expected default for 8 GB phones. The target iPhone has 12 GB and runs 1.7B, so
there is quality being left on the table at the top of the range. The profile system exists for
exactly this: Arivu chooses by capability, the user never browses.

**The cost is explicit.** Every safety number — D-066's refusal rates, all 25 age-rating fields —
was measured on Qwen3-1.7B. A model change invalidates the lot and means re-running the full probe
before an honest submission. That is the price of claims that mean something, and it is why this
comes after v1.1 rather than instead of it.

## Not doing, and why it is a decision rather than a backlog

| | |
|---|---|
| Model browser / downloads | R3, and it would require networking — which contradicts the claim that no networking framework is linked, the one thing `otool -L` can verify and the one no competitor makes |
| Voice, dictation, multimodal | R6 |
| Tools, web search, agentic loops | R2 |
| A paid tier | Free and open by choice. Sponsorship lives on the repository, outside the app, because Apple 3.2.2(iv) puts donations outside in-app purchase anyway |
| A settings screen | C8 |

If one of these is ever wanted, it is a Spine decision with the costs written down — not a ticket.

## What would make this roadmap wrong

Written down so it can be checked rather than defended:

- **If 1.0 is rejected a second time**, everything below moves and the only item is understanding why.
- **If the Metal experiment shows no gain**, v1.1 is empty and should be skipped rather than filled.
- **If a wording is found that makes 0.6B refuse reliably**, v1.2 becomes much cheaper and should
  move ahead of v1.1.
- **If nobody installs it**, the problem is distribution, not features, and none of this is the work.
