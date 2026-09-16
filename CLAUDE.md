# CLAUDE.md

## How this repo is run — Spine and Leaf

- **`SPINE.md` is the single source of truth**: the user's problem, the persona, the direction,
  commitments C1–C10, metrics M1–M6, refusals R1–R8. This file (below the line) is the settled
  *engineering brief* that the Spine was derived from; it is not the Spine.
- **Leaves** (all versioned, stamped with `spine_version`):
  `leaves/architecture.md` · `leaves/engineering.md` (+ `android/`, the working prototype) ·
  `leaves/design.md` · `leaves/gtm/tour.html` · `leaves/compliance/TRACEABILITY.md` (generated) ·
  `leaves/sequencing/` (work items, generated Ready-Now + critical path) · `leaves/decisions.yml`.
- **Every feature and test carries a `spine: C<n>` tag.** Untagged work is scope creep or a missing Spine update.
- **Open calls go in `leaves/decisions.yml`**, never silently into code. Where this brief contradicts
  itself or a measurement, a decision entry records it (D-002, D-003, D-004, D-008, D-012, D-013).
- **On any Spine change** run the propagation discipline: bump version + changelog, then
  `tools/propagate.py` lists stale Leaves in order and regenerates Compliance and Sequencing.
- Before finishing any change: `tools/host/run_smoke.sh`, `./gradlew :app:testDebugUnitTest :app:bundleRelease`,
  `tools/check_manifest.sh`, `tools/trace.py`.

---

Project spine. Read this fully before writing code. Decisions below are settled —
do not relitigate them unless a measurement on real hardware contradicts them.

---

## What this is

A free, open-source, fully offline LLM chat app for Android. One APK, model
bundled, no network permission. Targeted at users in Africa, South East Asia,
and South America where data costs and API pricing are the barrier.

**Positioning: an offline writing and comprehension assistant. Not an offline oracle.**
The model is small. It is good at operating on text the user provides. It is bad
at open-domain factual recall. Every product decision follows from that sentence.

## Goals

1. Publish on Google Play. One tap to install, then it works — no account, no
   setup, no model download, no configuration.
2. Run on a 4GB-RAM Android phone with no internet, ever.
3. Be verifiably private: no `INTERNET` permission in the manifest.
4. Be forkable: permissive licenses throughout, including model weights.

**This is an opinionated app.** The model and the harness around it are fixed
and shipped. The user gets no model picker, no quantization choice, no runtime
parameters, no provider settings. Download and use. Every decision that could
have been a setting has already been made in this document.

Corollary: the app must not install on a device it cannot run well on. See
"Device compatibility gate" below.

## Non-goals (iteration-1)

- Peer-to-peer APK sharing and off-Play distribution — **deferred to iteration-2**
- Agent loops, tool calling, file system access
- Model manager, model picker, or any multi-model support
- RAG, bundled corpora, document import
- Settings screens, personas, themes
- Voice, images, multimodality
- iOS

---

## Settled decisions

| Area | Decision | Rationale |
|---|---|---|
| Model | Qwen3 0.6B, Q4_K_M GGUF | Apache-2.0, ~400MB, fits 4GB devices |
| Fallback model | Qwen3 1.7B Q4_K_M | Only if benchmarks show ≥8 tok/s on the test phone |
| Rejected | Gemma 3 1B | Better multilingual, but Gemma terms are not OSI-open; we redistribute weights |
| Runtime | llama.cpp via JNI | mmap, GBNF, quantized KV, no Play Services |
| ABI | `arm64-v8a` only | 32-bit cannot address enough memory |
| minSdk | 30 | ~87% of measured device base |
| targetSdk | 36 | Required for new Play submissions as of 2026-08-31 |
| NDK | r27 or later | 16KB page-size alignment is mandatory |
| UI | Kotlin + Jetpack Compose | Single screen; React Native buys nothing |
| Persistence | Flat JSON via kotlinx.serialization | Room is overkill for one conversation list |
| Permissions | None. Explicitly no `INTERNET` | This is the product's core claim |
| App license | Apache-2.0 | Explicit patent grant; safe for corporate forks |
| Package name | `io.github.brettleehari.arivu` | **Resolved 2026-09-15 (D-001)**: every `arivu` domain worth having was already registered; the GitHub namespace is one Hari controls |

## Build artifact

One artifact: an **AAB for Google Play**, model shipped in an install-time
Play Asset Delivery pack (combined install-time limit is 1GB).

Keep the model-loading code behind an interface with two implementations —
PAD asset path, and `assets/`-embedded via `AssetManager.openFd()`. Iteration-1
only wires up the first, but iteration-2's universal APK needs the second, and
retrofitting it later is worse than stubbing it now.

Guard the signing key carefully from day one: iteration-2's shareable APK must
carry the same package name and the same key, or it cannot update a Play
install.

---

## Hard technical constraints

### Memory budget, 4GB device

| Allocation | Size | Reclaimable |
|---|---|---|
| Weights (mmap'd, file-backed) | ~400MB | Yes — kernel evicts clean pages |
| KV cache @2048 ctx, `q8_0` | ~115MB | No — must be freed explicitly |
| Compute / scratch buffers | ~80MB | No |
| App + JVM + Compose | ~150MB | No |
| **Peak RSS target** | **≤800MB** | |

### Lifecycle — load only during operation

`llama_model` and `llama_context` have opposite memory behavior. Split them.

- `llama_model`: mmap'd, file-backed, clean pages. The kernel reclaims it for
  free under pressure. Reload is a page-cache hit. **Never call `mlock`** — it
  pins exactly the pages we want evictable.
- `llama_context`: anonymous heap, unreclaimable, holds the KV cache. This is
  what we manage.

Required behavior:
- Create the context lazily on first message. Never at app start.
- Free the context after ~30s idle, and immediately in `onStop`.
- Implement `ComponentCallbacks2.onTrimMemory`: free context at `UI_HIDDEN`,
  free model at `TRIM_MEMORY_COMPLETE`.
- Foreground service starts when generation begins, stops on the last token.
- Thread count = performance core count (usually 4), not `availableProcessors()`.
  Saturating all cores on a budget SoC is slower and hotter.

### Context

Cap at 2048 tokens with `--cache-type-k q8_0 --cache-type-v q8_0`. At f16,
Qwen3 0.6B costs ~112KB/token; 4096 tokens would be ~460MB of KV alone.
Truncate explicitly and visibly. Never overflow silently.

### APK packaging

- Mark the GGUF `noCompress` in Gradle and mmap it directly from the APK via
  `AssetManager.openFd()` → fd + offset + length into llama.cpp.
- Without this, Android extracts a second full copy of the model to internal
  storage: 2GB used instead of 1GB on a 32GB phone.
- Verify page alignment of the asset offset; mmap fails on misaligned offsets.

### Device compatibility gate

An Android app cannot run code at install time and cannot abort its own
installation. There is no install hook. Compatibility is enforced in three
layers, and all three are required.

**Layer 1 — manifest filtering (Play hides the listing):**
- `minSdk 30`
- `arm64-v8a` ABI only (no other ABI in the bundle)
- `<uses-feature android:name="android.hardware.ram.normal" android:required="true"/>`
  — excludes Android Go / low-RAM devices. Coarse; does not enforce a 4GB floor.

**Layer 2 — Play Console device exclusion rules (the real RAM floor):**
Configure a minimum-RAM exclusion in the Play Console device catalog. Console
configuration, not code, but it is the layer that actually keeps the app off
underpowered devices and keeps 1-star "it's so slow" reviews off the listing.
Set the threshold from the benchmark results in step 1, not from a guess.
Record the chosen value in NOTES.md.

**Layer 3 — runtime gate on first launch (safety net for mis-catalogued devices):**

Check, in order:
| Check | Source | Fail condition |
|---|---|---|
| ABI | `Build.SUPPORTED_ABIS` | no `arm64-v8a` |
| Low-RAM flag | `ActivityManager.isLowRamDevice()` | true |
| Total RAM | `ActivityManager.MemoryInfo.totalMem` | below threshold from step 1 |
| Free storage | `StatFs` on internal storage | insufficient for model + KV |

On failure: show one plain screen explaining which check failed and why the app
will not work on this device, with a single button firing `ACTION_DELETE` for
the app's own package. Do not offer a "continue anyway" option — that defeats
the opinionated design and generates the reviews this gate exists to prevent.
Do not crash, and do not call `System.exit()`; both read as a broken app.

Run this check before any model load, and cache the result so it costs nothing
on subsequent launches.

### Distribution

- Google developer verification enforcement began 2026-09-30 in Brazil,
  Indonesia, Singapore, Thailand — three of our target markets. Global in 2027.
  The developer account must be verified. Play auto-registers Play-distributed
  packages, so iteration-1 is covered by completing account verification.
  Iteration-2's off-Play APK must be registered manually via Play Console.
- Play policy: AI-generated content rules require an in-app mechanism to report
  offensive model output. With no `INTERNET` permission this must be a share or
  email intent, not an API call.
- Data safety form: declare no data collection, no data sharing. This is the
  cheapest credibility the app will ever get — fill it in precisely.

---

## Software BOM

| Component | License | Approx size |
|---|---|---|
| llama.cpp | MIT | ~3MB (.so) |
| Qwen3 0.6B Q4_K_M | Apache-2.0 | ~400MB |
| Kotlin stdlib + coroutines | Apache-2.0 | ~2MB |
| Compose + Material3 | Apache-2.0 | ~4MB |
| AndroidX core / lifecycle / FileProvider | Apache-2.0 | ~3MB |
| kotlinx.serialization | Apache-2.0 | <1MB |

All permissive. No copyleft. Apache-2.0 requires propagating NOTICE files —
ship an in-app licenses screen covering llama.cpp and the model weights.

---

## Scope of the single screen

Message list. Input box. Send. Stop. Copy message. That is all.

Plus two secondary screens: **About** (licenses, what this model is and is not
good at, report-offensive-output intent), and the **incompatible-device** screen
from the compatibility gate, which most users will never see.

---

## Build order

1. **Benchmark harness first.** JNI + llama.cpp, no UI. Load the GGUF, run a
   fixed prompt set, report prefill tok/s, decode tok/s, peak RSS, thermal
   throttle onset. Run on the physical test phone. This decides 0.6B vs 1.7B
   *and* the RAM threshold used by layers 2 and 3 of the compatibility gate.
2. Model loading behind an interface; PAD asset path implemented, `assets/`
   + `openFd()` path stubbed for iteration-2.
3. Streaming generation + cancel, wired to a foreground service.
4. The lifecycle rules above. Verify with `adb shell dumpsys meminfo` that idle
   RSS returns to roughly the Compose baseline after 30s.
5. Compatibility gate, all three layers. Test layer 3 by faking a low totalMem.
6. Single-screen Compose UI.
7. JSON persistence.
8. About screen + licenses + report-output intent.
9. AAB with PAD install-time pack; Play Console listing, data safety form,
   device exclusion rules.

Nothing after step 4 matters if steps 1–4 don't hold on the physical device.

---

## Iteration-2 (do not build now)

- **Single shareable universal APK.** Model embedded in `assets/`, marked
  `noCompress`, mmap'd from the APK via `AssetManager.openFd()` (fd + offset +
  length) so Android does not extract a second full copy to internal storage.
  Verify page alignment of the asset offset.
- **In-app share button.** `packageManager.getApplicationInfo().sourceDir` →
  FileProvider → `ACTION_SEND`. Works with Bluetooth, Quick Share, SHAREit,
  Xender, USB without integrating with any of them. Requires the universal APK;
  PAD split APKs cannot be shared as one file.
- **Manual package registration** with Google developer verification for the
  off-Play APK.
- **Anti-tamper**: publish signing cert SHA-256, in-app screen showing the
  running copy's own signature fingerprint, reproducible builds. A P2P-spread
  app in these markets will get repackaged with adware under its own name.
- F-Droid listing, pending their position on a large bundled model blob.

Same package name and same signing key as iteration-1, with a higher version
code, so a shared APK cleanly updates a Play install and vice versa.

## Test device

A real 4GB-RAM phone, Helio G85 or Snapdragon 680 class. Emulators misreport
thermal throttling and memory pressure, which are the two things that decide
whether this product works.

## Open questions — resolve by measurement, not by argument

- Actual decode tok/s for 0.6B and 1.7B on the test phone.
- Whether `TRIM_MEMORY_COMPLETE` fires reliably enough on low-end OEM ROMs, or
  whether we need an explicit idle timer as the primary mechanism. *(Partly answered by platform docs: not delivered on API 34+ — D-012.)*
- Asset page alignment behavior across aapt2 versions. *(Measured — D-013.)*
- F-Droid's position on a bundled multi-hundred-MB model blob.
