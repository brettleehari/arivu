---
spine_version: 0.2
leaf: engineering-ios
audience: engineers
platform: ios
---

# Engineering Leaf — iOS

The working prototype **is** `ios/`. This Leaf is the map, the sequence flows the code does not show
visually, and an honest account of what has and has not been proven.

## Leaf changelog

- **2026-09-15** — First Leaf. `ios/ArivuKit` (SwiftPM, 94 tests passing on macOS), `ios/App`
  (SwiftUI, **never compiled**), `ios/project.yml`, `tools/ios/`. Spine 0.2.

---

## The one thing to read first

**No part of the iOS app has been built.** The machine this port was written on has Command Line
Tools and no Xcode, so there is no iOS SDK, no Simulator, no `xcodebuild` and no CMake. Everything
SwiftUI- or UIKit-shaped in `ios/App` is careful, commented, unverified Swift.

What *is* verified is the part that was deliberately pushed below the UI: **94 tests compile and pass
on macOS**, in Swift 6 language mode, covering prompt building and truncation, the conversation file
format, the device gate, profiles, stop-reason mapping, the copy catalogue, the report payload, the
engine wrapper (against a fake core) and the whole chat state machine. That is the resolution an
engineer can open and run *today*, on a Mac with nothing installed.

The verified-to table at the bottom says exactly which is which, line by line.

---

## Map

| Path | What |
|---|---|
| `ios/ArivuKit/Package.swift` | Four targets. `ArivuCore` is pure Swift and needs no native library; `CArivuCore` is a header-only module map over `core/include/arivu/arivu.h` with **no `link` directive**, so the wrapper type-checks with nothing built; `ArivuEngine` is the wrapper; `ArivuChat` is the lifecycle and the state machine. `CArivuStub` is a fake core in C, in no product. |
| `ArivuCore/Policy.swift` | Every would-be setting, the same values as `android/app/.../Policy.kt`, each tied to a decision. The system prompt is byte-identical (659 characters, compared string by string). |
| `ArivuCore/PromptBuilder.swift` | Qwen3 ChatML, whole-turn truncation, `TooLong`. A line-for-line port of the Kotlin builder, tested against the same cases as `PromptBuilderTest.kt`. |
| `ArivuCore/Conversation.swift`, `ChatRepository.swift` | The cross-platform conversation file: same field names, same enum spellings, `stop: null` and `reported: false` always written, temp-file-then-rename, damaged files set aside with only the newest kept. Plus two iOS-only things — excluded from iCloud backup, and Data Protection. |
| `ArivuCore/DeviceGate.swift` | One evaluator for both platforms (C11). iOS reports `arm64 == true` and `lowRamFlagged == false`, so only two of the four checks can fire here — which is why the iOS gate screen carries two sentences. |
| `ArivuCore/Profile.swift` | The device tier as a config object (MULTIPLATFORM appendix). Mirrors the core's new `arivu_profile`. |
| `ArivuCore/Strings.swift`, `Resources/en.lproj/Localizable.strings` | The copy catalogue, rendered from `leaves/design/copy.md`. `StringKey` makes "author no string in Swift" a compiler error; a test walks every case. |
| `ArivuEngine/ArivuEngine.swift` | The wrapper. One serial queue for every call but `cancel`; the handle owned by a class whose only job is to free it in `deinit`; generation as an `AsyncStream` whose termination handler cancels. |
| `ArivuEngine/ModelSource.swift` | The bundle file as **fd + offset 0 + whole length**. `arivu_load_model_path` exists and is deliberately unused, so both platforms exercise one loading path in the core. |
| `ArivuEngine/DeviceMemory.swift` | `phys_footprint` (what jetsam charges), `os_proc_available_memory()` (iOS only), performance-core count, and a log line that labels a Simulator reading as non-representative. |
| `ArivuEngine/CoreParity.swift` | Thin bindings to the core's own profile/prompt/UTF-8 rules, so the Swift copies are *compared* rather than trusted. Skipped against the fake core. |
| `ArivuChat/InferenceController.swift` | The lifecycle. **Not a port of the Android one** — see §"What is deliberately different". Plus `CancelBox`, which is why Stop works during the cold model map. |
| `ArivuChat/ChatSession.swift` | The state machine: every state in `leaves/design.md` §3, with no SwiftUI in sight, which is why they are all testable here. |
| `ios/App/Sources/` | SwiftUI. `ChatView`, `AboutView`, `ReportSheet`, `IncompatibleView`, `Theme`, and `ArivuApp` with the `UIApplicationDelegate` that owns the memory warning and the background assertion. **Unverified.** |
| `ios/App/Support/` | `Info.plist` (nothing declared that is not used), `Arivu.entitlements` (one entitlement, with the argument for it written down). |
| `ios/App/Resources/` | `PrivacyInfo.xcprivacy` (no tracking, no collection, no required-reason APIs), the licences, the asset catalogue. |
| `ios/project.yml` | XcodeGen spec. The `.xcodeproj` is generated and never committed. |
| `tools/ios/` | `build_core.sh` (XCFramework), `generate_project.sh`, `copy_model.sh`, `sync_licences.sh`, `verify_macos.sh`, and `check_release.sh` — a thin build-phase guard that hands over to **`tools/ios_release_check.sh`**, the Compliance Leaf's full App Store gate. |

---

## Build it

### On this machine, today (no Xcode)

```sh
tools/ios/verify_macos.sh          # compiles every ArivuKit target and runs 94 tests. ~25 s.
ARIVU_REAL_CORE=1 tools/ios/verify_macos.sh   # same, linked against the real core (parity suite)
```

### On a Mac with Xcode

```sh
tools/llama/fetch_llama.sh         # pinned llama.cpp + patches → third_party/
tools/fetch_model.sh               # Qwen3-0.6B Q4_K_M, sha256-verified → models/ (~400 MB)
tools/ios/build_core.sh            # /core + llama.cpp → build/ios/ArivuCore.xcframework
tools/ios/sync_licences.sh         # licence texts + the iOS index → ios/App/Resources/licenses/
ARIVU_REPORT_EMAIL=you@example.com tools/ios/generate_project.sh
open ios/Arivu.xcodeproj

cd ios/ArivuKit && swift test --no-parallel --build-system native   # the same 94 tests, the normal way
```

`--no-parallel` is not optional: the fake core has process-wide knobs (script, delays, forced
failures), so two suites running at once set each other's.

---

## `swift test`, and why the custom runner still exists

**Resolved 2026-09-16.** SwiftPM here could not load *any* package manifest, including an empty one:
the Command Line Tools ship `PackageDescription.swiftmodule` (May 2025) beside
`libPackageDescription.dylib` (December 2024), and the manifest fails to link with
`type metadata accessor for PackageDescription.SwiftVersion`. A second CLT defect made **any**
`import Foundation` fail, because `usr/include/swift` defines `SwiftBridging` twice.

The fix was a Swift 6.4 toolchain from swift.org, which needs no Apple ID and installs into the home
directory without sudo:

```sh
curl -LO https://download.swift.org/swift-6.4.0-release/xcode/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-osx.pkg
installer -pkg swift-6.4.0-RELEASE-osx.pkg -target CurrentUserHomeDirectory
export TOOLCHAINS=swift-6.4.0-RELEASE
cd ios/ArivuKit && swift test --no-parallel --build-system native   # 94 tests pass
```

`--build-system native` is required: the default build system fails on a duplicate toolchain
registration from the `swift-latest` symlink the installer creates.

`tools/ios/verify_macos.sh` is kept for two reasons, not one. It still works on a machine with only
the Command Line Tools, and it is the only way to run the tests against a **real core** rather than
the C stub:

```sh
tools/ios/build_core_macos.sh                 # /core + llama.cpp as static libs for this Mac
ARIVU_REAL_CORE=1 tools/ios/verify_macos.sh   # links them; runs the parity suite for real
```

The behaviour tests drive the stub through knobs the real core does not have, so the two cannot link
together; the real-core mode supplies those knobs as no-ops and filters to `CoreParityTests`. That
turns the two tests which used to skip into two that pass: **the shipped profile matches the core's
field for field, and Swift and C agree on which devices fit.** A macOS result is not evidence about
an iPhone — it is evidence that Swift and C agree, which is the thing that would otherwise drift.

---

## What is deliberately different from Android

Not a port where the platform makes the port wrong. Five things, and the reason for each.

**1. The lifecycle is proactive, because jetsam gives no warning.**
Android's `onTrimMemory` arrives before the low-memory killer does, so the Android controller can
wait to be told. Jetsam does not call first. So on iOS the context is freed after 30 s idle and
*immediately* on backgrounding, and `didReceiveMemoryWarning` is handled only as a bonus. Nothing in
the lifecycle rules depends on that warning arriving.

**2. The number that matters is `phys_footprint`, not RSS.**
Jetsam charges `phys_footprint`, which excludes clean file-backed pages, so the ~396 MB of mmap'd
weights is very nearly free against the limit while the KV cache and compute buffer are charged in
full. Reading RSS would say Arivu uses 750 MB where jetsam thinks 200, and every decision taken from
that number would be wrong. Two consequences are enforced in code rather than in a comment: the
weights are never mlock'd and `repackWeights` stays false (repacked weights are dirty), and
`GGML_METAL=OFF` in `build_core.sh` keeps `n_gpu_layers` at 0 — Metal buffers are dirty memory, so
offloading would convert ~373 MB of uncharged clean pages into charged memory and delete the property
the whole budget rests on.

**3. `os_proc_available_memory()` gates a load attempt, never a device.**
It is a reading of this second. A transient low value must not condemn a phone permanently, so it
produces `load_failed_low_memory` and the user can try again. `physicalMemory` is a tier signal only,
re-read on every cold start.

**4. A reply that cannot finish in the background stops cleanly and says so.**
iOS gives ~30 s of background assertion against Android's ~3 minutes of foreground service. The
expiration handler routes into the **same** cancel path as the Stop button, so the partial reply is
saved by the same throttled save and labelled `stopped_backgrounded`. No notification, no alert, no
badge: a local notification needs a permission prompt, and an app whose pitch is that it asks for
nothing does not open with a permission dialog (D-041).

**5. The gate screen has no button.**
iOS gives an app no way to delete itself, and `exit()` reads as a crash. One line of removal
instructions instead of a dead button (D-042). And because the App Store has no device-exclusion
catalogue, more iOS users will see this screen than Android users ever do.

The things that are **not** different, on purpose: every number in `Policy`, the system prompt, the
chat template, the truncation rule, the conversation file format, the four report reasons, every stop
label, the honesty statements, the 48 pt/dp touch target floor, and the contrast table.

---

## Sequence diagrams

### First message, cold

```
User        ChatView        ChatSession      InferenceController     ArivuEngine        core (C)
 |  type       |                 |                    |                   |                |
 |  Send ----->|                 |                    |                   |                |
 |             |  send(text) --->|                    |                   |                |
 |             |                 |- append user msg   |                   |                |
 |             |                 |- append EMPTY reply msg  <-- both bubbles, same instant  |
 |             |                 |- generating = true |                   |                |
 |             |                 |- startingPhase = firstRun (first send after install)     |
 |             |<-- @Published --|                    |                   |                |
 |  "Starting Arivu for the first time…" + spinner    |                   |                |
 |  [Stop is live from here]     |                    |                   |                |
 |             |                 |  build(turns) ---->|                   |                |
 |             |                 |                    | ensureModel()     |                |
 |             |                 |                    |  state=.starting  |                |
 |             |                 |                    | open() -> fd      |                |
 |             |                 |                    |  loadModel(fd,0,len) -------------->|
 |             |                 |                    |                   |  mmap 396 MB   |
 |             |                 |                    |<--------------------- ok ----------|
 |             |                 |                    |  state=.ready     |                |
 |             |                 |                    | countTokens(...) ----------------->|
 |             |                 |<-- promptTokens ---|                   |                |
 |             |                 |                    |                   |                |
 |             |                 | generate(prompt) ->|                   |                |
 |             |                 |                    | hasRoomForContext()?  (os_proc_available_memory)
 |             |                 |                    | ensureContext() ------------------->|
 |             |                 |                    |  state=.generating|   KV ~115 MB    |
 |  "Reading…" |<----------------|                    |                   |                |
 |             |                 |                    | cancelBox.isRequested? --> no      |
 |             |                 |                    | generate() ----------------------->|
 |             |                 |<-- .text("Dear") --|<------------------ piece ----------|
 |  text grows |<----------------|  (save every ~2 s) |                   |                |
 |             |                 |<-- .done(stats) ---|<------------------ stats ----------|
 |             |                 |- stop = resolveStop(reason, cancelBox.cause)             |
 |             |                 |- generating = false, persist()         |                |
 |             |                 |                    | scheduleIdleFree(30 s)             |
 |  Report/Copy appear           |                    |                   |                |
```

### Stop, at any moment

```
User        ChatSession        CancelBox           InferenceController      ArivuEngine
 |  Stop ------->|                 |                       |                    |
 |               | request(.user) ->|                      |                    |
 |               |                 |- cause = .user        |                    |
 |               |                 |- engine?.cancel() ------------------------->| arivu_cancel
 |               |                 |                       |                    |  (thread-safe,
 |               |                 |                       |                    |   any thread,
 |               |                 |                       |                    |   mid-prefill ok)
 |               |                 |                       |                    |
 |  ---- three moments, one path ----                      |                    |
 |  (a) before the model is mapped: engine is nil, so `cause` is all that is set.
 |      The controller checks cancelBox.isRequested AFTER prepare() and emits
 |      .done(CANCELLED) without ever starting a generation.   <-- Android bug 2
 |  (b) during prefill: arivu_cancel's abort callback stops it.
 |  (c) mid-stream: the next token check stops it.
 |               |                 |                       |                    |
 |               |<-- .done(CANCELLED) -------------------------------------------|
 |               |- resolveStop(.cancelled, .user) = .cancelled                  |
 |               |- partial text kept, label "Stopped", persist()                |
```

The same three lines carry `.memoryPressure` and `.backgroundExpiring`; only the label differs. That
is the whole reason `CancelBox` holds a *cause* rather than a boolean.

### Memory pressure and backgrounding

```
OS / scene                AppDelegate        ChatSession        InferenceController
 |                            |                   |                     |
 | didReceiveMemoryWarning -->|                   |                     |
 |                            | onMemoryWarning ->|                     |
 |                            |                   |- generating?        |
 |                            |                   |   yes: cancelBox.request(.memoryPressure)
 |                            |                   |        -> partial kept, label
 |                            |                   |           "Stopped: your phone ran low…"
 |                            |                   |   no:  silent. Nothing of the user's
 |                            |                   |        was lost, so nothing is said.
 |                            |                   |- onMemoryWarning() ->| free context if idle
 |                            |                   |                     |
 | scenePhase == .background  |                   |                     |
 |--------------------------->| (SwiftUI) ------->| onBackground() ---->| free context NOW
 |                            |                   |                     |  (never waits for a warning)
 | didEnterBackground ------->|                   |                     |
 |                            |- beginBackgroundTask(~30 s)              |
 |                            |                   |                     |
 | ...30 s later, expiring--->|                   |                     |
 |                            | onBackgroundTimeExpiring()               |
 |                            |                   |- cancelBox.request(.backgroundExpiring)
 |                            |                   |   -> partial kept, label
 |                            |                   |      "Stopped: Arivu cannot keep writing
 |                            |                   |       while you are in another app…"
 |                            |- endBackgroundTask()                     |
 |                            |                   |                     |
 | scenePhase == .inactive    |  DELIBERATELY NOTHING. `inactive` is a notification-shade pull
 |                            |  or an app-switcher peek; freeing there makes every glance cost a reload.
 |                            |                   |                     |
 | jetsam kill (no callback)  |  On relaunch: the partial reply saved every ~2 s is found with
 |                            |  stop == nil and labelled "Stopped". The app cannot know why it
 |                            |  died, and a guess would be a lie.
```

---

## PocketPal — and what "single click" actually means

Hari asked what PocketPal AI does and to make Arivu single click. PocketPal (MIT, React Native +
`llama.rn`, iOS 15.1+) is the reference implementation of the opposite choice: it is a *model
runner*, and the user is the one who assembles the product.

| What PocketPal makes the user do | What Arivu does instead |
|---|---|
| **Onboarding: 7 screens** (splash, pals, offline, expectations, privacy, a topic picker, a model-tier picker) before the first chat | **No onboarding at all.** The launch screen, then the empty chat. That is the whole first run (C1) |
| **Find a model**: a remote-fetched curated list, in-app Hugging Face search, a manual GGUF URL, or a local file import | **One model, in the app.** Qwen3-0.6B Q4_K_M, in the bundle, chosen once, recorded in `leaves/BRIEF.md` (R3) |
| **Choose a quantization**: pick the GGUF file yourself from a repo's list, guided by "Memory tight" chips and a "may exceed available memory — continue?" dialog | **No quantization choice.** Q4_K_M, decided by a benchmark, not by the user (C8) |
| **Download 0.7–2.7 GB** before the first reply (the "Balanced" default is 1.07 GB) | **Nothing is downloaded, ever.** The 400 MB is inside the install, which is why the app works in airplane mode on the day it arrives (C1, C2) |
| **Per-model setup**: chat template (a dropdown of ~12, plus a raw Nunjucks editor), BOS token, EOS token, "add generation prompt", system prompt, stop words | **None of it.** The template, the tokens and the system prompt are part of the product, in `Policy.swift`, byte-identical to Android's (C8, C11) |
| **~45–50 settings**: `n_predict`, temperature, top_k, top_p, min_p, XTC, typical_p, four penalties, mirostat + tau + eta, seed, jinja; then GPU layers, flash attention, context size, batch, ubatch, threads, KV cache types, speculative decoding, draft model, mlock, mmap, weight repacking… | **Zero settings, and no settings screen to put one in.** Every one of those is a decision already made, each naming the decision that made it. A test asserts the copy catalogue does not even contain the words for one (C8, R5) |
| **Stop button + a two-stage "Stopping…" state** | Same idea, and Stop additionally works *before the first token*, during the cold 400 MB map — the moment someone most wants to back out (C10) |

### What we took from PocketPal

Three things, each because it removes a decision rather than adding one:

1. **Set expectations in the product, not in the listing.** PocketPal's third onboarding screen says
   "Think pocket companion, not all-knowing oracle." Arivu says the same thing in the empty state,
   where it costs no screen: *"It is not good at facts, news or numbers, so check anything
   important."* Same job, no extra tap.
2. **A memory estimate before loading, not a crash after.** PocketPal estimates from GGUF metadata
   and warns. Arivu asks `os_proc_available_memory()` before creating a context and, if there is not
   room, says `load_failed_low_memory` — a sentence the user can act on — instead of the generic
   failure.
3. **Auto-offload when backgrounded, and nothing on the transient `inactive` state.** PocketPal makes
   this a user toggle and deliberately ignores `active → inactive`. Arivu does the same thing, minus
   the toggle: it is always on, because it is right, and a setting would only let someone turn off
   the behaviour that keeps the app alive.

### What we refused, and why

- **The model picker, the HF search, the quant list, the bookmark-then-download flow.** R3. Choosing
  a model is a job the app is supposed to have already done. Offering the choice moves the blame for
  a bad answer from us to the user.
- **Every generation and runtime setting.** C8. "Temperature 0.7, top_k 20, top_p 0.8" is a decision
  (D-007), not a preference. A slider would make the app's behaviour unreproducible and every bug
  report unanswerable.
- **Per-model chat template / BOS / EOS / stop-word editors.** These are the sharpest knives in
  PocketPal's drawer and the ones a non-expert cannot possibly evaluate.
- **The onboarding carousel.** Even the good screen. Five taps before the first chat is five taps,
  and the same words fit in the empty state.
- **The in-app benchmark and the leaderboard.** The benchmark is ours to run (`tools/bench.sh`, W02),
  not the user's. A leaderboard needs the network we do not have.
- **Pals / personas, and persona-seeded prompt chips.** R5. Also: the tappable-example question is
  already open as D-030, and that is the honest version of the same idea.
- **The live memory sparkline and the per-message tokens/sec footer.** Speed is what the phone does;
  narrating it makes a slow phone feel like a broken app, and invites the user to tune something they
  cannot tune.
- **Internet search, remote servers, HF tokens, TTS.** C3. Not a settings question — a different
  product.

The result, which is the actual answer to "make it single click": **on iOS there is no click at all
before the chat.** Install, open, type, Send. The one number that decides whether that is true is the
cold first-map time, and it has not been measured yet (§Remaining steps, and Design's question below).

---

## Verified-to table

Be suspicious of anything not in the first block.

### Verified: compiled and run on this machine

| Claim | How | Result |
|---|---|---|
| Every `ArivuKit` target compiles, Swift 6 language mode, macOS | `tools/ios/verify_macos.sh` | 4 targets, 0 errors |
| The same suites through SwiftPM, the normal way | `swift test --no-parallel --build-system native`, Swift 6.4 toolchain | 94 tests pass (2 skip against the stub) |
| Swift and C agree on the profile and the fit rule | `ARIVU_REAL_CORE=1 tools/ios/verify_macos.sh` | 5 parity tests pass against the real core |
| `ios/Arivu.xcodeproj` generates from `project.yml` | `tools/ios/generate_project.sh`, XcodeGen 2.46 | project written, never opened in Xcode |
| The C fake core compiles with `-Wall -Wextra -Werror` against the real `arivu.h` by relative path | same | clean |
| Truncation arithmetic matches `PromptBuilderTest.kt` case for case | `PromptBuilderTests` | pass |
| Conversation JSON round-trips, keeps `stop: null` / `reported: false` / `version`, sets damaged files aside, keeps only the newest damaged copy | `ConversationTests` (9 tests) | pass |
| Stop-reason wire names match Kotlin's `enum class Stop`, including the new `LOW_MEMORY` and `BACKGROUNDED` | `ConversationTests` | pass |
| Gate decisions, order, caching, and SI size formatting | `DeviceGateTests` (9) | pass |
| Profile fit, selection, validation, the M3 peak estimate | `ProfileTests` (6) | pass |
| Stop-reason mapping, and a cancel labelled by its cause | `StopReasonTests` (5) | pass |
| Every catalogue key resolves; no orphans; the iOS privacy claim is never Android's; Android-only keys absent; British spelling; no settings/sign-in/download words | `StringsTests` (11) | pass |
| Report payload: reply, reason, note, version, empty-note fallback, share fallback, no URLs | `ReportTests` (6) | pass |
| `Policy` matches Android's numbers; the system prompt is byte-identical (659 chars) | `PolicyTests` (4) | pass |
| The engine handle is freed on every path, including a throwing load | `EngineWrapperTests` | pass |
| `cancel()` from another thread stops a running generation; breaking the `for await` loop cancels too | same | pass |
| Load fd + offset 0 + whole length; lazy context; free context without losing the model | same | pass |
| A memory load failure is distinguishable from any other | same | pass |
| `phys_footprint` is readable; the thread count stays in the [2,4] band; a Simulator reading is labelled | `DeviceMemoryTests` | pass |
| The Swift UTF-8 boundary rule agrees with the core's `arivu_utf8_complete_prefix` over 10 inputs | `CoreParityTests` | pass |
| Stop-reason numbering agrees with the C enum; the assistant opening agrees with `arivu_assistant_open()` | same | pass |
| Every chat state in `design.md` §3: first message, Stop (including before any token), memory pressure, background expiry, reply limit, context full, message too long, both load failures, the context divider, process-death recovery, persistence, the first-run line, empty send, concurrent send | `ChatSessionTests` (15) | pass |

`94 tests passed`. Two more are skipped by design: the profile and fit parity tests, which need a
real core (they run on device, or on a Mac after `build_core.sh`).

### Type-checked only — compiled on macOS, never on iOS

| Thing | Why it is not fully verified |
|---|---|
| `DeviceMemory.availableBytes()` | The body is inside `#if os(iOS)`; `os_proc_available_memory()` is `API_UNAVAILABLE(macos)`, so the macOS build compiles the `nil` branch. The iOS branch has never been compiled. |
| `ChatRepository.protect()` | `FileProtectionType` is iOS-only; same situation. |
| `CoreParity.*` | Compiles against the real header, links against the fake core. The bindings themselves are exercised; the *answers* are the stub's. |

### Not verified at all — never compiled

Everything in `ios/App/`, `ios/project.yml`, `ios/App/Support/*`, `ios/App/Resources/PrivacyInfo.xcprivacy`,
the asset catalogue, and every script in `tools/ios/` except `verify_macos.sh` and `sync_licences.sh`
(both of which were run).

| Thing | What could be wrong |
|---|---|
| `ChatView`, `AboutView`, `ReportSheet`, `IncompatibleView`, `Theme` | Any SwiftUI API misuse. Most likely suspects: `sheet(item:)` plumbing, the `ScrollViewReader` follow behaviour, `Form` inside a `.sheet` with detents, `@FocusState`. |
| `ArivuApp` / `AppDelegate` | `@UIApplicationDelegateAdaptor` with a `@StateObject` initialised in a stored property; the `scenePhase` wiring; whether `applicationDidReceiveMemoryWarning` fires for a SwiftUI lifecycle app (it should, but this is exactly the kind of thing that is wrong). |
| `project.yml` | XcodeGen is not installed here. The framework path, the folder-reference for `licenses`, and the build-phase input/output files are all plausible and unproven. |
| `build_core.sh` | Never run: no CMake, no Xcode. The `libtool` merge and the `-create-xcframework` invocation are the risky parts. |
| `Info.plist`, entitlements, privacy manifest | Never parsed by Xcode or App Store Connect. |
| The asset catalogue | Rendered PNGs with no alpha at the right sizes, never through `actool`, never seen under the system corner mask. |
| The whole memory story | Every figure is an Android measurement or an estimate. **No iPhone number exists.** |

---

## Requests to the Core Leaf

Nothing blocking: everything needed today is in `arivu.h` as it stands, and `/core` was not touched.

1. **`arivu_version()` should be able to say it is a real build.** The fake core in
   `ios/ArivuKit/Sources/CArivuStub` returns `"stub-0"`, and the parity tests skip on that prefix.
   That works, but it is a convention invented on this side. If the core adopted a documented format
   (say `"<semver>+<llama.cpp short sha>"`), the About screen could show the shared core version the
   way `MULTIPLATFORM.md` versioning expects, and the skip condition would stop being a guess.
2. **Confirm the ownership rule for `arivu_prompt_builder_create_for_engine`.** The header says the
   engine must outlive the builder. Swift will happily arrange the opposite; a note on whether the
   builder retains anything, and whether `arivu_prompt_builder_free` is safe after
   `arivu_free_model`, would let the binding be written without a defensive lock.
3. **`arivu_profile_fits` and `available_memory_bytes == 0`.** The Swift copy treats zero as "not
   measured" and not a failure, because Android has no equivalent reading. Please confirm the C
   implementation agrees, or the parity test will fail the first time it runs on a device — which is
   the test doing its job, but it would be better to agree now.
4. **A decision, not a gap: one prompt builder or three?** The core now implements ChatML and
   whole-turn truncation in C, and Kotlin and Swift each implement it again. The Swift copy stays
   authoritative on iOS *today* only because it is the one that can be tested with no native library
   on a machine with no Xcode. Proposed below as **D-046**.

---

## Remaining manual steps, in order

Everything below needs a Mac with Xcode. Steps 1–4 are the first build; 5–9 are the first honest
numbers; 10–12 are release material.

1. **Install the toolchain.** Xcode 16 or later (Swift 6), then `brew install cmake xcodegen`.
   Confirm `xcrun --sdk iphoneos --show-sdk-path` prints something.
2. **Fetch the inputs.** `tools/llama/fetch_llama.sh`, then `tools/fetch_model.sh` (~400 MB,
   sha256-verified). Run `tools/host/run_smoke.sh` — if the core is broken, find out before Xcode is
   involved.
3. **Run the tests the normal way.** `cd ios/ArivuKit && swift test --no-parallel`. Expect the same
   94 passes and the two skips. If the manifest does not load, the CLT defect described above has
   followed you; a full Xcode install fixes it.
4. **Build the core.** `tools/ios/build_core.sh`. Expect this to need a fix — it has never run. The
   two likely failures: `libtool` complaining about duplicate members from the ggml backends, and
   CMake refusing `-G Ninja` under the iOS toolchain (use `-G Xcode` and adjust the library paths).
   Verify both slices exist: `plutil -p build/ios/ArivuCore.xcframework/Info.plist`.
5. **Generate and open the project.**
   `ARIVU_REPORT_EMAIL=<the address from D-010> tools/ios/generate_project.sh`, then
   `open ios/Arivu.xcodeproj`. Expect to fix `project.yml` once or twice.
6. **Build to the Simulator and fix the SwiftUI.** This is where the unverified app meets a
   compiler. Budget real time for it. **Label every Simulator number non-representative**, exactly as
   the Android side labels emulator results.
7. **Run `ArivuTests` on the Simulator.** It checks the model is in the bundle, the privacy manifest
   and licences shipped, the catalogue resolves from the real bundle, and the *real* core is linked
   (`coreVersion` must not start with `stub`).
8. **Put it on a physical iPhone.** An iPhone SE (2020) or iPhone 11 class handset — 3–4 GB — is the
   iOS equivalent of the Helio G85 target. A 99 USD/year developer account is needed to install on a
   device at all.
9. **Measure, on that phone, in airplane mode**, and write the numbers into `leaves/NOTES.md` beside
   the Android rows:
   - **cold first-map time** — the number Design is waiting for. If it is well under 15 s,
     `state_starting_first_run` should be deleted rather than shipped (`design.md` §14, request 7);
   - decode tok/s (M2 ≥ 8) and time to first token (M1 ≤ 15 s);
   - **`phys_footprint` at peak**, not RSS — via `DeviceMemory.summary()`, which is logged on every
     reply and every context free;
   - `os_proc_available_memory()` at launch and at peak, so the `increased-memory-limit` entitlement
     can be confirmed as insurance rather than a load-bearing assumption;
   - footprint 30 s after the last token, to prove the idle free works (M4's iOS twin).
10. **Walk the state catalogue on the device**: every row of `design.md` §3, plus the gate screen
    (temporarily lower `Policy.minTotalRamBytes` to force it), the report composer *and* its
    activity-sheet fallback with no mail account configured, and VoiceOver + AX5 Dynamic Type +
    an RTL pseudolanguage (Design's W71).
11. **Check the icon and the launch screen** under the system corner mask, in light and dark (W74).
12. **Before submission**: run `tools/ios_release_check.sh path/to/Arivu.app` (the Compliance Leaf's
    gate, against `leaves/compliance/appstore-policy-checklist.md`); re-check `PrivacyInfo.xcprivacy`
    against Apple's current required-reason API list (it grows); confirm App Privacy says "Data Not
    Collected"; and settle **D-038** — the iOS app must not ship Android's "no permission to use the
    internet" sentence. A test in `ArivuKit` already fails if it does.

Two things that are not steps but will decide the schedule: the **~400 MB download** crosses the
200 MB cellular threshold, so the listing needs the same "install on Wi-Fi" line the Play listing
carries; and App Store review applies stricter scrutiny to on-device model output than Play does, so
`leaves/NOTES.md`'s safeguard probe (D-026) should be re-read before the first submission.

---

## Proposed decisions (for `leaves/decisions.yml` — this Leaf does not edit that file)

Numbers continue from Design's D-044.

- **D-045 — Metal stays off.** *Spine: C2, C8, C11.* `GGML_METAL=OFF`, `n_gpu_layers = 0`. Metal
  buffers are dirty memory: offloading would convert ~373 MB of uncharged clean pages into charged
  memory and delete the property the memory budget rests on. It also keeps both platforms on one
  code path, so a tok/s figure means the same thing on each. Options: off (recommended) / on behind a
  measurement on a 4 GB iPhone showing footprint still under budget. `ARIVU_METAL=1` exists so the
  experiment costs one flag. **Blocks release: no.**
- **D-046 — One prompt builder, or three?** *Spine: C7, C11.* ChatML and whole-turn truncation now
  exist in C (core), Kotlin (Android) and Swift (iOS). The Swift copy is authoritative on iOS today
  only because it is the one testable with no native library. Options: (a) both platforms adopt
  `arivu_prompt_builder_*` once `CoreParityTests` has run green on hardware, and the Swift/Kotlin
  copies become test references — recommended; (b) three implementations with a parity harness
  forever; (c) status quo, which is (b) without the harness. **Blocks release: no**, but the cost of
  the wrong answer is a silent divergence in what the user's model can see.
- **D-047 — iOS deployment target 17.0.** *Spine: C6, C11; Design's D-043.* The App Store has no
  device-exclusion catalogue, so the OS floor is the only exclusion there is. 17.0 implies an A12 or
  newer. Options: 17.0 (recommended) / 16.0, more reach and more gate screens / 18.0, fewer gate
  screens and a materially smaller installed base. **Blocks release: no**, but it is irreversible
  upwards without dropping users.
- **D-048 — The licence texts and NOTICE should live once, not twice.** *Spine: C4.* Android's
  `NOTICE.txt` names Kotlin, Compose, AndroidX and the `.gguf.so` packaging name, none of which exist
  on iOS, so `tools/ios/sync_licences.sh` generates a second one by hand. Options: a shared
  `/licenses` directory with one generator per platform (recommended) / two hand-maintained files.
  **Blocks release: no**, but C4 is "licences visible in-app", not "most licences".
- **D-049 — Where the report address lives on iOS.** *Spine: C9, C3.* It is an `Info.plist` key set
  from `ARIVU_REPORT_EMAIL` at project generation, and `tools/ios/check_release.sh` refuses the
  placeholder when installing. This is the iOS twin of D-010's Gradle property. Confirm the same
  address is used on both platforms. **Blocks release: yes**, with D-010.

## Proposed work items (for `leaves/sequencing/workitems.yml`)

- **W75** — First Xcode build: fix whatever `ios/App` and `project.yml` get wrong. *Owner: iOS
  Engineering. Deps: Xcode, W76.*
- **W76** — Make `tools/ios/build_core.sh` actually produce a working XCFramework. *Owner: iOS
  Engineering.*
- **W77** — First physical-iPhone measurement: cold first map, decode tok/s, `phys_footprint` peak,
  idle footprint, `os_proc_available_memory` at peak. The iOS twin of W02. *Owner: iOS Engineering.
  Blocks: D-045, D-047, and Design's request 7.*
- **W78** — Run `CoreParityTests` against the real core and settle D-046. *Owner: iOS Engineering,
  with Core.*
- **W79** — iOS device walk-through of `design.md` §3, including the gate screen and the report
  composer's no-mail-account fallback. The iOS twin of the Android emulator run. *Owner: iOS
  Engineering, with Design.*
- **W80** — `tools/check_copy.py` (Design's W68) must also read the iOS `Localizable.strings`,
  normalising `%1$s` → `%1$@` / `%1$ld`. *Owner: Engineering.*
