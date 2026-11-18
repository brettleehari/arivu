---
spine_version: 0.2
leaf: architecture
artifact: Does Qwen3-1.7B-Q4_K_M scale past two threads? Measured 2026-11-17
---

# Thread scaling

## Why this was asked

`DeviceMemory.performanceCoreCount()` reads `hw.perflevel0.logicalcpu` — performance cores only —
and clamps to `[2, 4]`. The clamp came from an Android cpufreq heuristic and was copied to iOS for
C11 symmetry: the same number of threads on comparable hardware. That reasoning is about PARITY.
Nobody had checked whether it was also about SPEED.

On an A19 Pro (2 performance + 4 efficiency cores) it resolves to **2 threads**. PocketPal's
heuristic, `floor(allCores * 0.8)`, resolves to **4** on the same phone.

## What was measured

Host (macOS, 5 performance + 10 efficiency cores), the shipped model, quantisation and prompt, one
fixed prompt, 93 generated tokens every time. `tools/eval/sweep.cpp` with `ARIVU_THREADS`.

| threads | tok/s | vs 1 thread |
|---|---|---|
| 1 | 25.7 | 1.00x |
| 2 | 43.3 | 1.69x |
| 3 | 59.1 | 2.30x |
| 4 | 71.5 | 2.78x |
| 6 | 87.1 | 3.39x |
| 8 | 95.6 | 3.72x |

**No plateau at two.** Two to four is +65%, and it is still climbing at eight. The clamp's implicit
premise — that two threads saturates this model — is not supported.

## What this proves, and what it does not

**Transfers: the shape.** Scaling at a given model and quantisation is a property of the work, not
of the machine. A model that saturated at two threads here would saturate at two anywhere, and the
clamp would be fine. This one does not.

**Does not transfer: the number.** A phone has fewer, slower cores and a thermal budget a laptop
does not, and 2 -> 4 on an A19 Pro adds EFFICIENCY cores, not performance ones. The gain will be
smaller than +65%. It is unlikely to be zero.

**Not measured at all: sustained behaviour.** One short generation says nothing about a warm phone,
and a thread count that wins for twenty seconds can lose over five minutes. That is a device
measurement, and `ios/App/UITests/Experiment.swift` is where it belongs.

## What follows

The honest change is NOT "use four threads". It is to pick the count from a measurement on the
device, the way the memory ceiling already calibrates itself rather than trusting a constant
(D-059). C11 asks for capability by device; two platforms sharing the same ARITHMETIC satisfies
that better than two platforms sharing the same NUMBER.

Blocked on a handset that stays connected long enough to run the 2x2.
