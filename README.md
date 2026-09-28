# Arivu

**A language model that runs on your phone.** Not a client for one somewhere else — the whole
model is inside the app, which is why it works with the aeroplane mode on and why nothing you type
ever leaves the device. No account, no sign-in, no setup, no network code linked at all.

It is small enough to fit on a phone, so it is good at working with text you give it — rewriting,
shortening, explaining, summarising, translating, drafting — and unreliable about facts. It is built
to say so rather than to bluff.

It is also a way to **see how such a thing works**: every reply shows what it cost in tokens, you
can open any reply to read the exact text the model was given, and you can edit the instructions it
runs on and watch the behaviour change.

Free, Apache-2.0, **model weights included**. iOS and Android.

## Where things actually stand

Said plainly, because a README that oversells is the first thing a contributor stops trusting.

| | |
|---|---|
| **iOS** | The lead platform. Chat, several conversations, per-reply cost, the exact-prompt disclosure, an editable system prompt, a learning module with a live tokenizer, a first-run welcome. Built, tested and running on a handset; in TestFlight |
| **Android** | Behind. Chat, About and the incompatible screen only — no conversation list, no learning page, no prompt disclosure, no prompt editor, and still on a smaller model. See `W139`, `W142` |
| **Model** | Qwen3-1.7B, Q4_K_M, ~1.1 GB, bundled |
| **Not proven** | Arivu claims it runs on a modest phone. Every iOS measurement so far comes from an iPhone 17 Pro Max, which cannot fail the memory ceiling and therefore cannot test it. See `W111` |

## Reading order

- **Why it exists, and what it refuses to become:** [`leaves/SPINE.md`](leaves/SPINE.md) — read this first if you intend to contribute
- **Engineering brief:** [`leaves/BRIEF.md`](leaves/BRIEF.md)
- **How it is built:** [`leaves/engineering.md`](leaves/engineering.md) · [`leaves/architecture.md`](leaves/architecture.md)
- **What is next, and what is undecided:** [`leaves/sequencing/SEQUENCING.md`](leaves/sequencing/SEQUENCING.md) · [`leaves/decisions.yml`](leaves/decisions.yml)
- **Guided tour:** [`leaves/gtm/tour.html`](leaves/gtm/tour.html)

## Build it

```sh
tools/llama/fetch_llama.sh && tools/fetch_model.sh   # ~1.1 GB, sha256-verified

tools/core_test.sh          # core unit tests — no model, no platform SDK, seconds
tools/host/run_smoke.sh     # the real engine against the real model, on your machine

swift test --package-path ios/ArivuKit                    # iOS logic, 118 tests
cd android && ./gradlew :app:testDebugUnitTest             # Android, 57 tests
```

iOS app and the twelve end-to-end journeys need Xcode: `tools/ios/deploy.sh` to a connected phone.

## Contributing

**Please do** — see [`CONTRIBUTING.md`](CONTRIBUTING.md). It is worth five minutes before you write
any code, because this repository has two unusual rules: some things are *refused by design* and a
pull request implementing one will be turned down however good the code is, and contested changes
are raised as decisions rather than opened as patches. Both exist so that nobody's afternoon is
wasted.

The most useful help right now is named in CONTRIBUTING under "Where help is actually wanted".

## Licence

Apache-2.0, **including the model weights** (Qwen3, Apache-2.0). Runtime: llama.cpp, MIT.
Full attribution in [`NOTICE`](NOTICE).
