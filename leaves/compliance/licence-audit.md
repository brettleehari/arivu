---
spine_version: 0.1
leaf: compliance
checked_on: 2026-09-15
artifact: android/app/build/outputs/bundle/release/app-release.aab
llama_cpp: 38a5b42d9a3e82e0a586bcd1caed121f36c87a73 + tools/llama/patches/0001
model: unsloth/Qwen3-0.6B-GGUF Qwen3-0.6B-Q4_K_M.gguf sha256 ac2d9771…524a (tools/fetch_model.sh)
---

# Licence audit of the shipped bundle — Compliance Leaf (C4)

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
