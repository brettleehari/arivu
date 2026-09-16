#!/usr/bin/env bash
# Fetches llama.cpp at the pinned commit into third_party/ and applies Arivu's patches.
# Pinned, not floating: a llama.cpp bump is a deliberate change re-verified by tools/host/run_smoke.sh
# and the on-device benchmark.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMIT="38a5b42d9a3e82e0a586bcd1caed121f36c87a73"   # b10988+1, 2026-09-15
DEST="$ROOT/third_party/llama.cpp"
if [[ ! -d "$DEST/.git" ]]; then
  git clone --filter=blob:none https://github.com/ggml-org/llama.cpp.git "$DEST"
fi
cd "$DEST"
git fetch --depth 1 origin "$COMMIT" 2>/dev/null || true
git checkout -q --force "$COMMIT"
git clean -fdq
for p in "$ROOT"/tools/llama/patches/*.patch; do
  git apply --whitespace=nowarn "$p"
  echo "applied $(basename "$p")"
done
