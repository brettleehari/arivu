---
spine_version: 0.2
leaf: compliance
platform: android (§1–§6) + ios (§7)
checked_on: 2026-09-15
reconciled_on: 2026-09-15
reconciled_note: >
  Spine 0.2 puts iOS in scope. §1–§6 are an audit of the shipped AAB and remain Android-only as
  written. §7 is the iOS delta: what leaves the binary, what stays, what could newly enter, and
  what the in-app licences screen must show. No iOS bundle exists yet, so §7 is derived from the
  source tree and the upstream licences, not from a built artifact.
artifact: android/app/build/outputs/bundle/release/app-release.aab
llama_cpp: 38a5b42d9a3e82e0a586bcd1caed121f36c87a73 + tools/llama/patches/0001
model: unsloth/Qwen3-0.6B-GGUF Qwen3-0.6B-Q4_K_M.gguf sha256 ac2d9771…524a (tools/fetch_model.sh)
---

# Licence audit of the shipped bundle — Compliance Leaf (C4)

**§1–§6: the Android AAB. §7: what changes for an iOS bundle.**

Method: `unzip -l` of the release AAB; `bundletool dump manifest`; `strings`/ELF inspection of the merged native
libs; grep of the llama.cpp sources that the CMake configuration actually compiles
(`android/llama/src/main/cpp/CMakeLists.txt`: `LLAMA_BUILD_COMMON/TOOLS/SERVER OFF`, `GGML_LLAMAFILE OFF`,
`GGML_CPU_KLEIDIAI OFF`); Hugging Face API for the model repos; upstream GitHub for Kotlin NOTICE files.
`BUNDLE-METADATA/` (R8 mapping, debug symbols) is not delivered to devices and is out of scope.

## 1. What ships to a device

| Path in AAB | Size (B) | Component | Licence | Obligation |
|---|---|---|---|---|
| `modelpack/assets/model/qwen3-0.6b-q4_k_m.gguf.so` | 396,705,472 | Qwen3-0.6B weights (Alibaba Cloud), Q4_K_M quantization by Unsloth, renamed `.gguf.so` (D-013) | Apache-2.0 | §4(a) licence copy; §4(b) state modifications; §4(c) retain notices; §4(d) NOTICE — upstream has none |
| `base/lib/arm64-v8a/libllama.so` | 3,265,440 | llama.cpp (+ Arivu patch 0001) | MIT (ggml authors) + embedded third-party, §3 | MIT notice in all copies |
| `base/lib/arm64-v8a/libggml.so`, `libggml-base.so` | 58,400 / 767,032 | ggml | MIT | MIT notice |
| `base/lib/arm64-v8a/libggml-cpu-android_armv{8.0_1,8.2_1,8.2_2,8.6_1,9.0_1,9.2_1,9.2_2}.so` | ~0.87–0.90 MB each | ggml CPU backend variants | MIT + embedded YaRN code, §3 | MIT notices |
| `base/lib/arm64-v8a/libarivu_llama.so` | 57,512 | Arivu JNI bridge | Apache-2.0 (Arivu) | own |
| `base/lib/arm64-v8a/libc++_shared.so` | 1,374,336 | LLVM libc++/libc++abi (NDK r29) | Apache-2.0 WITH LLVM-exception | Whole shared library shipped, so the exception (for *embedded portions*) does not remove §4(a); licence text present |
| `base/lib/arm64-v8a/libandroidx.graphics.path.so` | 10,096 | AndroidX graphics-path | Apache-2.0 | licence text |
| `base/dex/classes.dex` | 2,074,328 | Arivu, Kotlin stdlib, kotlinx.coroutines, kotlinx.serialization, AndroidX (activity, annotation, arch-core, autofill, collection, compose ui/foundation/material3/runtime/animation, core, customview, emoji2, graphics-path, interpolator, lifecycle, navigationevent, profileinstaller, savedstate, startup, tracing, versionedparcelable, window) | Apache-2.0 (Kotlin stdlib also carries BSD-3/Apache/Boost-derived code, §4) | licence text; NOTICE text where upstream has one |
| `base/root/DebugProbesKt.bin`, `kotlin/**/*.kotlin_builtins` | small | kotlinx.coroutines / Kotlin | Apache-2.0 | as above |
| `base/root/META-INF/androidx/{annotation,collection,collection-ktx}/LICENSE.txt` | 10,175 each | AndroidX licence copies | Apache-2.0 | — |
| `base/assets/licenses/{index.txt,Apache-2.0.txt,llama.cpp-MIT.txt,qwen3-Apache-2.0.txt}` | | In-app licences screen data | — | the compliance surface |
| `base/root/META-INF/version-control-info.textproto` | 46 | AGP build metadata (`NO_SUPPORTED_VCS_FOUND`) | — | none |

Not shipped (verified): llama.cpp `vendor/` (nlohmann json, stb, miniaudio, cpp-httplib, sheredom, hash) — no
include from `src/` or `ggml/src/`; `third_party/llama.cpp/licenses/LICENSE-jsonhpp` therefore does **not** apply.
llamafile `sgemm.cpp` (Mozilla, MIT) — `GGML_LLAMAFILE OFF`; only the `ggml_cpu_has_llamafile` query symbol is in
the binaries. KleidiAI (Arm, MIT) — `GGML_CPU_KLEIDIAI OFF`, no symbols.

## 2. Model weights

- `Qwen/Qwen3-0.6B` files: `.gitattributes, LICENSE, README.md, config.json, generation_config.json, merges.txt,
  model.safetensors, tokenizer.json, tokenizer_config.json, vocab.json` — **no NOTICE file**; card front matter
  `license: apache-2.0`; no acceptable-use policy or extra terms; citation block optional. [V: HF API + README, 2026-09-15]
- `unsloth/Qwen3-0.6B-GGUF` (repo sha 50968a44…): `license: apache-2.0`, `base_model: Qwen/Qwen3-0.6B`, no NOTICE,
  no extra terms. The GGUF metadata names `general.quantized_by = Unsloth`. [V]
- In-app: `qwen3-Apache-2.0.txt` is the Apache-2.0 text with the appendix filled as "Copyright 2024 Alibaba Cloud",
  matching the upstream LICENSE. Listed in `index.txt` line 2. **§4(a) met; §4(d) not triggered.**
- **§4(b) gap (low):** the shipped file is a derivative (quantized by a third party, renamed). Neither `NOTICE` nor the
  licences screen says who quantized it or that it was renamed.

## 3. llama.cpp / ggml — code with its own notices compiled into shipped libs

| Location | Ends up in | Notice required | Covered today? |
|---|---|---|---|
| `LICENSE` — "Copyright (c) 2023-2026 The ggml authors" | all llama/ggml libs | MIT text + copyright | **yes** (`llama.cpp-MIT.txt`) |
| `ggml/src/ggml-cpu/ops.cpp:5956-5957` — YaRN RoPE "MIT licensed. Copyright (c) 2023 Jeffrey Quesnelle and Bowen Peng." | every `libggml-cpu-android_*.so` | MIT copyright + permission notice | **no** |
| `src/llama-vocab.cpp:243` — "adapted from https://github.com/cmp-nct/ggllm.cpp [MIT License]" | `libllama.so` | MIT notice, "Copyright (c) 2023 https://github.com/cmp-nct" | **no**  |
| `src/unicode-data.cpp` — tables generated from the Unicode Character Database (`scripts/gen-unicode-data.py`) | `libllama.so` | Unicode License v3 asks the copyright + permission notice to accompany copies of Data Files or derived software [U: whether generated tables are "copies"] | **no** (conservative add) |
| Arivu patch `0001-load-model-from-fd-window.patch` | `libllama.so` | none under MIT | — (good practice: say "modified") |

## 4. Kotlin / JetBrains NOTICE files (Apache-2.0 §4(d))

Upstream repositories carry NOTICE files, although the Maven jars in the Gradle cache contain none [V]:
- `Kotlin/kotlinx.coroutines/license/NOTICE.txt` — "kotlinx.coroutines library. Copyright 2016-2025 JetBrains s.r.o and contributors"
- `Kotlin/kotlinx.serialization/license/NOTICE.txt` — "kotlinx.serialization library. Copyright 2017-2019 JetBrains s.r.o and respective authors and developers"
- `JetBrains/kotlin/license/README.md` lists third-party code inside the stdlib, including
  `libraries/stdlib/src/kotlin/time` — **3-clause BSD** (ThreeTen-BP, "Copyright (c) 2007-present, Stephen Colebourne &
  Michael Nascimento Santos"); `kotlin/collections` — Apache-2.0 derived from GWT; `UnsignedJVM.kt` — Apache-2.0
  from Guava; `MathJVM.kt` — Boost (R8 removed it: `kotlin.math.MathKt__MathJVMKt -> R8$$REMOVED$$CLASS`).
  R8 mapping shows `kotlin.time.Duration`, `kotlin.UnsignedKt`, `kotlin.collections.AbstractList` **are shipped**.
  BSD-3 requires the copyright notice and licence in documentation for binary redistribution → **gap**.

Since the jars ship no NOTICE, §4(d) is arguably not triggered for the binaries; including the two JetBrains
NOTICE lines costs nothing and removes the argument.

## 5. The in-app licences screen and root NOTICE — completeness

`android/app/src/main/assets/licenses/index.txt` (8 entries) and `NOTICE` (repo root) against §1–4:

| # | Gap | Severity | Fix (owner) |
|---|---|---|---|
| L1 | **Root `NOTICE` is not in the app.** The bundle contains no NOTICE text; Apache §4(d) permits "a display generated by the Derivative Works", i.e. the licences screen — but nothing is displayed. Arivu's own NOTICE should also travel with the binary. | medium | Add `assets/licenses/NOTICE.txt` (copy of root NOTICE, extended per L2–L6) and an index line `Notices|—|NOTICE.txt` at the top (Engineering/Design — assets not owned by Compliance). Extend `LicensesTest` or a new test to assert root `NOTICE` == asset copy. |
| L2 | YaRN MIT notice (Quesnelle & Peng) missing | medium (MIT condition) | Append to `llama.cpp-MIT.txt` or add `third-party-MIT.txt` |
| L3 | ggllm.cpp MIT notice missing | medium | same; holder is "Copyright (c) 2023 https://github.com/cmp-nct" [V] |
| L4 | ThreeTen-BP BSD-3 notice (Kotlin stdlib `kotlin.time`) missing | medium (BSD condition) | add `kotlin-stdlib-third-party.txt` with BSD-3 text + holders; mention GWT/Guava Apache derivations |
| L5 | Unicode License v3 notice for UCD-derived tables | low [U] | add Unicode License v3 text |
| L6 | Model §4(b): quantizer and rename not stated | low | NOTICE line: "Q4_K_M GGUF quantization by Unsloth (huggingface.co/unsloth/Qwen3-0.6B-GGUF), file renamed to qwen3-0.6b-q4_k_m.gguf.so for packaging; weights otherwise unmodified by Arivu." |
| L7 | JetBrains NOTICE lines not reproduced verbatim | low | put the two lines from §4 in NOTICE |
| L8 | `index.txt` names "AndroidX Core, Activity, Lifecycle" but ~20 AndroidX artifacts ship, one as native code (`libandroidx.graphics.path.so`) | low | rename entry "AndroidX libraries (core, activity, lifecycle, emoji2, startup, profileinstaller, savedstate, window, graphics-path, …)" |
| L9 | llama.cpp entry does not say Arivu modified it | cosmetic | "llama.cpp and ggml (The ggml authors), with Arivu's fd-loading patch" |
| L10 | `LicensesTest` checks presence of names only; no test ties shipped `.so` files to index entries | process | Proposed test: every `lib*.so` produced by `mergeReleaseNativeLibs` maps to an index entry via a small allowlist (`libggml*`/`libllama` → llama.cpp, `libc++_shared` → libc++, `libandroidx.*` → AndroidX, `libarivu_llama` → Arivu). |

No copyleft component found. Every shipped component is Apache-2.0, MIT, BSD-3 (stdlib-embedded) or
Apache-2.0 WITH LLVM-exception — consistent with C4 and the leaves/BRIEF.md BOM. The BOM should add "LLVM libc++" and
the embedded third-party notices above.

## 6. Proposed `NOTICE` additions (for the owner to apply to root `NOTICE` and the asset copy)

```
This product bundles the Qwen3-0.6B model weights, Copyright 2024 Alibaba Cloud, Apache License 2.0,
as the Q4_K_M GGUF quantization published by Unsloth (huggingface.co/unsloth/Qwen3-0.6B-GGUF), renamed
qwen3-0.6b-q4_k_m.gguf.so for packaging and otherwise unmodified by Arivu.

llama.cpp and ggml, Copyright (c) 2023-2026 The ggml authors, MIT License, with modifications by Arivu
(tools/llama/patches). They contain:
  - YaRN RoPE scaling, Copyright (c) 2023 Jeffrey Quesnelle and Bowen Peng, MIT License
  - code adapted from ggllm.cpp (github.com/cmp-nct/ggllm.cpp), Copyright (c) 2023 https://github.com/cmp-nct, MIT License
  - tables derived from the Unicode Character Database, Copyright Unicode, Inc., Unicode License v3

kotlinx.coroutines library. Copyright 2016-2025 JetBrains s.r.o and contributors (Apache License 2.0)
kotlinx.serialization library. Copyright 2017-2019 JetBrains s.r.o and respective authors and developers (Apache License 2.0)
The Kotlin standard library contains code derived from ThreeTen-BP, Copyright (c) 2007-present, Stephen Colebourne
& Michael Nascimento Santos (BSD 3-Clause License), and from GWT and Guava (Apache License 2.0).
```

---

## 7. The iOS bundle — what changes (Spine 0.2)

No iOS bundle exists yet (`/ios` is being built in this session; there is no Xcode on this machine).
This section is derived from `ios/ArivuKit/`, the upstream licences, and Apple's own documentation.
It is enforced, when a bundle exists, by the licence block in `tools/ios_release_check.sh`.

**The one-line answer to "does anything new enter the binary?": no.** Nothing enters under a licence
Arivu does not already ship. Two artifacts *could* appear that are not in the AAB, and both are
covered by licences already in the index. Five components leave, and with them three of the ten gaps
in §5 disappear.

### 7.1 What leaves the binary

| Component in the AAB | Why it is absent on iOS | Obligation on iOS |
|---|---|---|
| `libc++_shared.so` — LLVM libc++/libc++abi, Apache-2.0 WITH LLVM-exception | Apple platforms link `/usr/lib/libc++.1.dylib` from the OS. The library is **not redistributed**, so the §1 reasoning (whole shared library shipped ⇒ §4(a) still applies) has nothing to attach to | **None.** Remove the "libc++ (LLVM)" entry from the iOS index. |
| Kotlin stdlib, kotlinx.coroutines, kotlinx.serialization | Replaced by Swift + Foundation + `Codable` | **None.** With them go **L4** (ThreeTen-BP BSD-3 in `kotlin.time`) and **L7** (the two JetBrains NOTICE lines). The BSD-3 notice is Android-only. |
| ~20 AndroidX artifacts, incl. `libandroidx.graphics.path.so`, Compose, Material3 | Replaced by SwiftUI/UIKit, Apple system frameworks | **None.** **L8** (the index under-names the AndroidX set) is Android-only. |
| `DebugProbesKt.bin`, `*.kotlin_builtins`, `META-INF/androidx/*/LICENSE.txt` | Kotlin/AndroidX packaging artifacts | None. |
| The `.gguf.so` rename (D-013) | An iOS app bundle is a directory, not a zip: the GGUF is a plain file at a plain path | **The §2 §4(b) gap narrows.** The iOS NOTICE must still say Unsloth quantized the weights; it must **not** say the file was renamed, because on iOS it is not. |

### 7.2 What stays, byte for byte the same obligation

| Component | Licence | Obligation |
|---|---|---|
| Qwen3-0.6B Q4_K_M weights (Alibaba Cloud; quantization by Unsloth) | Apache-2.0 | §4(a) licence copy, §4(b) state modifications (quantized by a third party), §4(c) retain notices. §4(d) not triggered — upstream has no NOTICE. |
| llama.cpp + ggml, with Arivu's patches (`tools/llama/patches`) | MIT, "Copyright (c) 2023-2026 The ggml authors" | MIT notice in all copies. Say "modified by Arivu" — true on both platforms even though the fd-window patch is not *needed* on iOS, because the same patched tree is compiled. |
| YaRN RoPE — `ggml/src/ggml-cpu/ops.cpp`, "Copyright (c) 2023 Jeffrey Quesnelle and Bowen Peng" | MIT | Compiled into the app executable on iOS exactly as into `libggml-cpu-*.so` on Android. **L2 applies unchanged.** |
| ggllm.cpp-derived code — `src/llama-vocab.cpp`, "Copyright (c) 2023 https://github.com/cmp-nct" | MIT | **L3 applies unchanged.** |
| Unicode Character Database tables — `src/unicode-data.cpp` | Unicode License v3 | **L5 applies unchanged** [U, as on Android: whether generated tables are "copies"]. |
| Arivu's own code (`/core`, `/ios`, the JNI bridge's Swift counterpart) | Apache-2.0 | Own. |

Everything that stays is MIT or Apache-2.0. **No copyleft, on either platform** — C4 holds.

### 7.3 What could newly enter, and why it adds no obligation

**Swift runtime and standard library — nothing to add, for two independent reasons.**

1. **The licence waives it.** Swift is Apache-2.0 **with the Runtime Library Exception**
   ([swiftlang/swift `LICENSE.txt`](https://github.com/swiftlang/swift/blob/main/LICENSE.txt), verbatim):
   > "As an exception, if you use this Software to compile your source code and portions of this
   > Software are embedded into the binary product as a result, you may redistribute such product
   > **without providing attribution as would otherwise be required by Sections 4(a), 4(b) and 4(d)**
   > of the License."

   That is precisely the situation: the compiler embeds runtime portions into Arivu's binary. No
   licence copy, no modification statement, no NOTICE.
2. **It is usually not there at all.** Since Swift 5's ABI stability the runtime and standard library
   ship **with the OS**; apps deploying to iOS 12.2 or later do not embed them
   ([swift.org, "ABI Stability and More"](https://www.swift.org/blog/abi-stability-and-more/)). Arivu's
   floor will be far above that, so `Frameworks/libswift*.dylib` should be absent. If
   `ios_release_check.sh` reports them, something in the build settings forced backward deployment —
   worth knowing, but still not a licence obligation.

**Apple system frameworks** (Foundation, SwiftUI, UIKit, Accelerate, Metal, MessageUI) are dynamically
linked from the OS, never redistributed, and covered by the Apple Developer Program License Agreement.
No notice, no index entry.

**The one real new artifact: `default.metallib`.** If the iOS build enables `GGML_METAL`, ggml compiles
`ggml-metal.metal` into a `default.metallib` **resource inside the app bundle**. That is still
llama.cpp/ggml source under the same MIT licence, so no new licence enters — but a new *shipped file*
does, and the "every shipped artifact maps to a licence entry" rule (**L10**, and its iOS counterpart in
`ios_release_check.sh`) must account for it. `leaves/architecture/ios-port.md` says the CPU path is
identical and Metal is optional; if the build is CPU-only there is no metallib and nothing changes.
Likewise `GGML_ACCELERATE` links Apple's Accelerate framework from the OS — no shipped bytes.

**`PrivacyInfo.xcprivacy`, the entitlements file, `Info.plist`** are Arivu's own, Apache-2.0.

### 7.4 What the in-app licences screen on iOS must show

The same screen, the same `index.txt` format, with the Android-only rows removed. Nothing is added.

| # | Entry | Licence text | Note |
|---|---|---|---|
| 1 | Notices | `NOTICE.txt` | An **iOS NOTICE**, not the Android one — see 7.5. |
| 2 | Qwen3-0.6B weights (Alibaba Cloud), Q4_K_M GGUF by Unsloth | `qwen3-Apache-2.0.txt` | Drop "renamed to `.gguf.so`" — untrue on iOS. |
| 3 | llama.cpp and ggml (The ggml authors), with Arivu's patches | `llama.cpp-MIT.txt` | Add ", including the Metal backend shaders" **only if** a `default.metallib` ships. |
| 4 | YaRN RoPE (Jeffrey Quesnelle and Bowen Peng) | `llama.cpp-embedded-MIT.txt` | L2. |
| 5 | ggllm.cpp (github.com/cmp-nct) | `llama.cpp-embedded-MIT.txt` | L3. |
| 6 | Unicode Character Database | `Unicode-3.0.txt` | L5. |
| 7 | Arivu | `Apache-2.0.txt` | Own. |
| ~~—~~ | ~~libc++ (LLVM, Apache-2.0 WITH LLVM-exception)~~ | — | Not shipped on iOS. |
| ~~—~~ | ~~AndroidX libraries / graphics-path / Compose~~ | — | Not shipped on iOS. |
| ~~—~~ | ~~Kotlin stdlib third-party (ThreeTen-BP BSD-3, GWT, Guava)~~ | — | Not shipped on iOS. |
| ~~—~~ | ~~kotlinx.coroutines / kotlinx.serialization NOTICE lines~~ | — | Not shipped on iOS. |
| — | Swift runtime / Apple frameworks | — | Deliberately absent: Runtime Library Exception, and OS-provided. |

The screen itself must stay reachable offline from About, as on Android (C4: "licences visible in-app").

### 7.5 One NOTICE or two — a decision, not a detail

The root `NOTICE` today names kotlinx.coroutines, kotlinx.serialization and ThreeTen-BP. Shipping it
verbatim inside an iOS bundle would assert obligations for code that is not in that binary: harmless,
but untrue, and this Leaf's whole value is that its statements are true.

`MULTIPLATFORM.md` lists "NOTICE generation" among the things that are shared, and the answer follows
from that: **one source, two generated outputs.** Proposed as **D-040** — a `tools/make_notice.py` that
emits the root `NOTICE` (the superset) plus a per-platform `NOTICE.txt` asset, with
`LicensesTest.noticeShippedInAppMatchesRootNotice` relaxed from equality to "the shipped NOTICE covers
everything in *this* binary". `tools/ios_release_check.sh` already implements the iOS half of that rule:
byte-identical passes, a subset passes if it still carries the ggml, YaRN, ggllm.cpp, Unicode and Unsloth
lines, and anything less fails.

Until D-040 is decided, shipping the root NOTICE verbatim on iOS is the safe option — over-attribution
breaches nothing.

### 7.6 Gap list for iOS

| # | Gap | Severity | Owner |
|---|---|---|---|
| I1 | No iOS licences assets or About screen yet | medium | Engineering (iOS) — reuse the Android texts verbatim; only `index.txt` changes |
| I2 | NOTICE is Android-shaped (D-040) | low | Decisions / Engineering |
| I3 | If Metal is enabled, `default.metallib` ships and entry 3 must say so | low | Engineering (iOS) |
| I4 | §2 §4(b): the iOS NOTICE must still name Unsloth, but must not claim a rename | low | whoever writes the iOS NOTICE |
| I5 | No test ties shipped iOS artifacts to index entries the way `LicensesTest` does on Android | process | covered by `tools/ios_release_check.sh` until an XCTest exists |

Nothing above is a licence **violation** risk. The iOS bundle is a strictly smaller licence surface
than the AAB.
