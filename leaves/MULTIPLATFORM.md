# MULTIPLATFORM.md

Brief for restructuring Arivu into a monorepo with a shared native core, ahead of
an eventual iOS app.

**Do this refactor now; do not write any Swift yet.** The only consumer today is
Android, so the blast radius is small. Once iOS exists, moving the engine becomes
a two-platform migration instead of a file move.

---

## Target layout

```
/core        C++ engine. No JNI, no Android headers, no platform types.
             engine.cpp, fd+offset loader, cancel, context lifecycle,
             prefix reuse, truncation.
/android     Gradle, JNI bridge, Compose UI.
/ios         Xcode, Swift bridge, SwiftUI.       (empty for now)
/tools       fetch_llama.sh, fetch_model.sh, host smoke, bench,
             check_manifest.sh, alignment checks.
/leaves      SPINE, BRIEF, architecture, decisions.yml, NOTES.md.
```

## The rule that makes this work

`/core` compiles and passes its tests with no Android or Apple SDK present.
`tools/host/run_smoke.sh` already proves this on macOS arm64 — that harness is
the contract. If a change to `/core` requires a platform SDK to build, the
abstraction has leaked and the change belongs in `/android` or `/ios`.

Everything platform-specific stays above the core boundary:

| Concern | Android | iOS |
|---|---|---|
| Model bytes | mmap from APK, fd + offset + length | plain file in app bundle |
| Memory pressure | `onTrimMemory`, `isLowRamDevice()` | `didReceiveMemoryWarning`, `os_proc_available_memory()` |
| Background work | foreground service (shortService) | `BGProcessingTask` / background assertion |
| Packaging | PAD install-time asset pack | On-Demand Resources or bundled |
| Device gating | manifest + Play Console exclusion rules | minimum iOS version only |

`/core` already takes the model as fd + offset + length. Keep that signature — it
covers both cases, since iOS just passes offset 0 and the full file length.

## Refactor steps

1. Move the C++ out of `/android` into `/core`. Leave only the JNI bridge behind.
2. Point the Android CMake at `../core`. The Android build must keep working with
   no behaviour change — verify with the existing unit tests and host smoke.
3. Move any llama.cpp patches and fetch scripts to `/tools`, shared by both.
4. Confirm `tools/host/run_smoke.sh` still passes from a clean checkout.
5. Create `/ios` with a README saying "not started." Nothing else.

No functional changes in this refactor. If a test result moves, something broke.

## Versioning and releases

- Independent release cadence per platform. Never hold an Android fix for App
  Store review.
- Shared core version, independent app versions: Android 1.2.0 and iOS 1.1.3 can
  both run core 1.4.0.
- Tag with platform prefixes: `core/v1.4.0`, `android/v1.2.0`, `ios/v1.1.3`.
  Makes `git log core/v1.3.0..core/v1.4.0` useful.
- Conventional commit scopes: `feat(core):`, `fix(android):`, `chore(tools):`.
  One history, per-platform changelogs generated from it.

## CI

- `core` job: host build + `run_smoke.sh` + core unit tests. Linux runner,
  seconds, runs on every commit. This is the highest-value job in the repo —
  it catches engine regressions before any device build.
- `android` job: Linux runner, `testDebugUnitTest`, `lintRelease`,
  `bundleRelease`, `check_manifest.sh`, alignment check.
- `ios` job: macOS runner. Expensive — gate it behind path filters so an
  Android-only commit doesn't trigger an Xcode build.
- Path filters on all three. Only `core` changes should fan out to both.

## Docs

One `decisions.yml`, not two. A decision like "KV cache is q8_0" is true on both
platforms and lives once. Tag genuinely platform-specific decisions with a
`platform:` field rather than forking the file.

One `leaves/NOTES.md`. Every measurement already names its device and build, so adding
iPhone rows changes nothing structurally. Keep the existing discipline: host and
simulator results are labelled non-representative; only physical devices count.

## Known iOS constraints to record now (not to act on)

- `os_proc_available_memory()` on a 4GB iPhone yields roughly 1.3–2GB before
  jetsam, which is less forgiving than Android's low-memory killer. The current
  ~750MB peak fits, with less headroom than the raw RAM figure suggests.
- App Store review applies stricter scrutiny to on-device model output than Play.
  The open safeguard question (see leaves/NOTES.md prompt probe) must be resolved before
  an iOS submission is even attempted.

---

## Appendix — what is genuinely shared, and how divergence stays clean

Model size and feature set diverge *above* the engine. The engine does not care whether it
loads 400MB or 2.5GB.

| Component | Why it is shared |
|---|---|
| Inference engine | Same llama.cpp, same cancel, same context lifecycle, same fd+offset loader |
| Prompt + chat template handling | Qwen template, system prompt, stop tokens |
| Token budgeting & truncation policy | "keep whole turns" is a product decision, not a platform one |
| Conversation schema | Same JSON, so a future export/import works across devices |
| Safety layer | Input filtering and report payload — needed twice, written once |
| Eval harness + prompt sets | Rewrite-quality set, red-team set; runs on host, scores both configs |
| Benchmark harness | Numbers are comparable across platforms only if it is the same code |
| decisions.yml, NOTES.md, NOTICE generation | One source of truth |

**The device tier is a config object, not a code fork:**

```
profile:
  model: qwen3-0.6b-q4km | qwen3-4b-q4km
  n_ctx: 2048 | 8192
  kv_type: q8_0
  threads: 4 | 6
  capabilities: [chat] | [chat, tools, longform]
```

The engine reads a profile; features gate on capability flags. Nothing is `#ifdef`'d by
platform, because the tiers will not stay platform-aligned: an 8GB Android flagship should
eventually get the same profile as an 8GB iPhone, and that must not be a rewrite. This is
Spine commitment C11.

### Three cautions on the iOS plan

1. **The memory ceiling is not what the spec sheet says.** iPhone 14 is 6GB, but an ordinary
   app is jetsammed well before that. The `com.apple.developer.kernel.increased-memory-limit`
   entitlement is how local-LLM apps ship 3B+ models. Verify it before committing to a 4B
   profile; without it the budget is roughly 2GB and the plan does not fit.
2. **A 2.5GB bundled model is legal (4GB app limit) but users will balk at the download**, and
   On-Demand Resources breaks the one-tap-and-it-works property. Decide deliberately rather
   than discovering it at submission.
3. **A 4B model with a tool harness is a different product with a different audience** than the
   offline assistant for low-income markets. Two products sharing an engine is a fine
   architecture; two products pretending to be one produces a README that cannot say what the
   app is, and a roadmap where every request must be answered twice.
