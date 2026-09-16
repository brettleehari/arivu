# Arivu

A free, open-source, fully offline writing and comprehension assistant for Android.
The model ships inside the app. It has no internet permission.

- **Why and for whom:** [`SPINE.md`](SPINE.md)
- **Engineering brief:** [`CLAUDE.md`](CLAUDE.md)
- **How it's built:** [`leaves/engineering.md`](leaves/engineering.md) · [`leaves/architecture.md`](leaves/architecture.md)
- **What's next:** [`leaves/sequencing/SEQUENCING.md`](leaves/sequencing/SEQUENCING.md) · open calls in [`leaves/decisions.yml`](leaves/decisions.yml)
- **Guided tour:** open [`leaves/gtm/tour.html`](leaves/gtm/tour.html)

```sh
tools/llama/fetch_llama.sh && tools/fetch_model.sh
tools/host/run_smoke.sh
cd android && ./gradlew :app:testDebugUnitTest :app:bundleRelease && cd .. && tools/check_manifest.sh
```

Licence: Apache-2.0. Model weights: Qwen3 0.6B, Apache-2.0. Runtime: llama.cpp, MIT.
