#!/usr/bin/env bash
# Core unit tests on the host. The companion to tools/host/run_smoke.sh: the smoke test proves the
# engine works against the real 400MB model, this proves the logic works against nothing at all.
#
#   tools/core_test.sh                 logic suite always; engine suite if llama.cpp is already built
#   tools/core_test.sh --with-engine   build llama.cpp if needed, then run both (CI uses this)
#   tools/core_test.sh --logic-only    the seconds-long suite and nothing else
#
# Two suites, because they cost different things:
#
#   core_logic   prompt building, truncation policy, device profiles, UTF-8 boundaries.
#                Links neither llama.cpp nor a platform SDK. This is MULTIPLATFORM.md's rule
#                ("/core compiles and passes its tests with no Android or Apple SDK present")
#                reduced to something that runs in about a second on every commit.
#   core_engine  the C API's behaviour with a NULL handle, no model and an invalid model file.
#                Links llama.cpp; loads no model, so it needs no download.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMAKE="${CMAKE:-$(command -v cmake || echo "$HOME/Library/Android/sdk/cmake/4.1.2/bin/cmake")}"
CTEST="${CTEST:-$(dirname "$CMAKE")/ctest}"
LOGIC_BUILD="${LOGIC_BUILD_DIR:-$ROOT/build/core-test}"
HOST_BUILD="${BUILD_DIR:-$ROOT/build/host}"
LLAMA_DIR="$ROOT/third_party/llama.cpp"
JOBS="${JOBS:-8}"

mode=auto
case "${1:-}" in
  --with-engine) mode=engine ;;
  --logic-only|--fast) mode=logic ;;
  "") ;;
  *) echo "usage: $0 [--with-engine|--logic-only]" >&2; exit 2 ;;
esac

EXTRA=()
if [[ "$(uname)" == "Darwin" ]]; then
  # Same workaround as run_smoke.sh: some Command Line Tools installs ship an incomplete libc++
  # header dir, so pin the SDK's.
  SDK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX1*.sdk | sort -V | tail -1)"
  EXTRA=(-DCMAKE_OSX_SYSROOT="$SDK" "-DCMAKE_CXX_FLAGS=-nostdinc++ -isystem $SDK/usr/include/c++/v1")
fi
export PATH="$(dirname "$CMAKE"):$PATH"

# --- 1. Logic suite: no llama.cpp, no model, no SDK ------------------------------------------
echo "== core logic tests (no llama.cpp, no model) =="
"$CMAKE" -S "$ROOT/core" -B "$LOGIC_BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
         -DARIVU_CORE_LOGIC_ONLY=ON -DARIVU_CORE_TESTS=ON "${EXTRA[@]}" >/dev/null
"$CMAKE" --build "$LOGIC_BUILD" -j "$JOBS" >/dev/null
"$CTEST" --test-dir "$LOGIC_BUILD" --output-on-failure

# --- 2. Engine suite: links llama.cpp, still loads no model -----------------------------------
if [[ "$mode" == logic ]]; then
  echo
  echo "SKIP core engine tests (--logic-only)"
  exit 0
fi
if [[ ! -f "$LLAMA_DIR/src/llama-mmap.cpp" ]]; then
  echo
  echo "SKIP core engine tests: patched llama.cpp not present. Run tools/llama/fetch_llama.sh."
  exit 0
fi
if [[ "$mode" == auto && ! -f "$HOST_BUILD/llama.cpp/src/libllama.a" ]]; then
  echo
  echo "SKIP core engine tests: llama.cpp is not built yet in $HOST_BUILD."
  echo "     Run 'tools/core_test.sh --with-engine' (or tools/host/run_smoke.sh) once; after that"
  echo "     this suite is incremental and takes seconds."
  exit 0
fi

echo
echo "== core engine tests (llama.cpp linked, no model loaded) =="
EXTRA_HOST=("${EXTRA[@]}")
if [[ "$(uname)" == "Darwin" ]]; then
  EXTRA_HOST+=(-DGGML_METAL=OFF -DGGML_BLAS=OFF)   # match run_smoke.sh so the build dir is shared
fi
"$CMAKE" -S "$ROOT/tools/host" -B "$HOST_BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release "${EXTRA_HOST[@]}" >/dev/null
"$CMAKE" --build "$HOST_BUILD" --target core_engine_test -j "$JOBS"
"$CTEST" --test-dir "$HOST_BUILD" -R core_engine --output-on-failure
