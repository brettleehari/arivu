#!/usr/bin/env bash
# Builds patched llama.cpp + the Arivu engine for the host and runs the smoke test.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build/host}"
CMAKE="${CMAKE:-$(command -v cmake || echo "$HOME/Library/Android/sdk/cmake/4.1.2/bin/cmake")}"
MODEL="${MODEL:-$ROOT/models/Qwen3-0.6B-Q4_K_M.gguf}"
EXTRA=()
if [[ "$(uname)" == "Darwin" ]]; then
  # Some Command Line Tools installs ship an incomplete libc++ header dir; pin the SDK's.
  SDK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX1*.sdk | sort -V | tail -1)"
  EXTRA=(-DCMAKE_OSX_SYSROOT="$SDK" "-DCMAKE_CXX_FLAGS=-nostdinc++ -isystem $SDK/usr/include/c++/v1" -DGGML_METAL=OFF -DGGML_BLAS=OFF)
fi
export PATH="$(dirname "$CMAKE"):$PATH"
"$CMAKE" -S "$ROOT/tools/host" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release "${EXTRA[@]}" >/dev/null
"$CMAKE" --build "$BUILD" --target engine_smoke -j 8
mkdir -p "$BUILD/scratch"
"$BUILD/engine_smoke" "$MODEL" "$BUILD/scratch"
