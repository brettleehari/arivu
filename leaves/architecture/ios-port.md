---
spine_version: 0.1
leaf: architecture
status: analysis for decision D-037. SPINE R7 currently refuses iOS.
---

# What a simultaneous iOS launch would take

## The short version

The hard part of Arivu — a quantized model running fast and small on a phone — is already
portable. The parts that are *not* portable are the ones that carry the product's promise:
the proof that it cannot reach the network, the lifecycle rules that keep it inside a small
memory budget, and a store gate that keeps it off devices it would disappoint.

Estimate: **2.5–4 weeks of focused work to TestFlight** for someone comfortable in Swift,
assuming the Android numbers (W02) already exist. Cash cost: **$99/year** for the Apple
Developer Program, plus a cheap test device (an iPhone SE 2020 / iPhone 11 class handset —
3–4 GB RAM — is the iOS equivalent of the Helio G85 target).

## What ports for free

| Piece | Status on iOS |
|---|---|
| `engine.cpp` | Portable C++ already; the host smoke test compiles it on macOS today (`tools/host/`) |
| llama.cpp / ggml | First-class on Apple silicon; Metal backend optional, CPU path identical |
| Prompt building, ChatML, truncation policy | ~300 lines of Kotlin, mechanical to port to Swift |
| `Policy` constants, system prompt, sampling | Copy verbatim |
| Licence assets, NOTICE, privacy policy text, store copy | Reuse |
| The Spine, and every Leaf but Engineering and Design | Reuse |

**The fd-window patch is not needed on iOS.** An iOS app bundle is a directory, not a zip, so
the GGUF is a plain file with a plain path. All of D-013 — the `.gguf.so` naming, bundletool's
alignment rule, the 32-byte offset check — is Android-only complexity that simply disappears.

## What has to be rebuilt

| Piece | Android today | iOS equivalent | Note |
|---|---|---|---|
| UI | Compose, ~1.2k lines | SwiftUI | One screen, About, gate screen |
| Background generation | Foreground service, ~3 min | `beginBackgroundTask`, ~30 s | iOS is far stricter; a long reply cannot finish in the background |
| Memory pressure | `onTrimMemory` levels | `didReceiveMemoryWarning` + jetsam | Jetsam kills without a callback; budget matters more, warnings help less |
| Report a reply | Email intent / share sheet | `MFMailComposeViewController` / `UIActivityViewController` | Same design |
| Refusing a weak device | Gate + `ACTION_DELETE` | Gate screen only | **iOS apps cannot offer to uninstall themselves** |
| Persistence | JSON in app-private files | Same, with Data Protection | iOS encrypts at rest by default |

## The three constraints that actually shape the port

**1. The privacy claim gets weaker, and that is a product problem, not a technical one.**
On Android, C3 is provable by absence: no `INTERNET` permission, enforced by the OS and by
`tools/check_manifest.sh` on every build. iOS has no equivalent permission to withhold. The
strongest available claim becomes "we do not use the network", backed by open source, a
reproducible build, and App Privacy showing "Data Not Collected". That is a weaker sentence,
and the Spine's whole positioning rests on the stronger one. Decide deliberately how the iOS
listing words it rather than copying the Android copy across.

**2. There is no device-exclusion catalogue.** Play lets us exclude phones by RAM (gate layer 2).
The App Store filters by minimum iOS version and device capabilities only. The practical
equivalent is a minimum iOS version that implies a newer chip, plus the runtime gate — which
on iOS can only explain and stop, not offer to uninstall. Expect more "it's slow" reviews per
thousand installs than on Android, or set the iOS floor higher than the Android one.

**3. Download size.** The app is ~400 MB. iOS allows a 4 GB bundle, so size is not a blocker,
but **200 MB is the cellular download limit**, above which the user needs Wi-Fi or must
approve a large download. The same "install on Wi-Fi" line the Play listing carries applies.

## Sequencing — "simultaneous" is the wrong target

Android production is gated by Play's closed test: **12 testers for 14 continuous days**, which
is calendar time nobody can compress (SEQUENCING.md puts production around 2026-10-17).
TestFlight has no such rule, and App Store review is typically days.

So a genuinely simultaneous launch means *delaying Android*, or rushing iOS. The better shape:

```
Android:  internal upload → phone benchmark → closed test (14 days, dead time) → production
iOS:                          └─ port happens inside that window ─┘ → TestFlight → review → launch together
```

The 14-day wait is the cheapest iOS budget available. Starting the port before the Android
numbers exist is the expensive version, because if W02/W04 say 0.6B is too weak, or the RAM
floor moves, both platforms change together.

## The question worth asking first

The Spine's user is on a 4 GB Android phone in Enugu, Jakarta or Recife, rationing a prepaid
bundle. In those markets iOS is a small minority, and iOS users are the least likely to be
blocked by data costs. An iOS build mostly buys credibility, press, and diaspora reach — real
things, but not the Spine's problem statement.

If the answer is "iOS is for reviewers and for people who will write about it", that is a
legitimate reason, and it should be written into the Spine rather than left implicit.
