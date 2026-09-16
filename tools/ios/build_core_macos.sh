#!/usr/bin/env bash
# Builds /core + llama.cpp for the HOST MAC as static libraries, so ArivuKit's tests can link the
# real core instead of the C stub (tools/ios/verify_macos.sh ARIVU_REAL_CORE=1).
#
# This is not the iOS build — that is tools/ios/build_core.sh and it needs Xcode. This one needs
# only CMake and the Command Line Tools, so the CoreParity suites can run before Xcode exists.
# A macOS arm64 result is not evidence about an iPhone; it is evidence that Swift and C agree.
#
# spine: C11
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build/core-macos}"
CMAKE="${CMAKE:-$(command -v cmake || echo "$HOME/Library/Android/sdk/cmake/4.1.2/bin/cmake")}"
[[ -x "$CMAKE" ]] || { echo "cmake not found"; exit 1; }
[[ -f "$ROOT/third_party/llama.cpp/src/llama-mmap.cpp" ]] || { echo "run tools/llama/fetch_llama.sh first"; exit 1; }

EXTRA=()
# Some Command Line Tools installs ship an incomplete libc++ header dir; pin the SDK's, exactly as
# tools/host/run_smoke.sh does. Harmless on a healthy toolchain.
SDK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX1*.sdk 2>/dev/null | sort -V | tail -1 || true)"
if [[ -n "$SDK" && -d "$SDK/usr/include/c++/v1" ]]; then
  EXTRA=(-DCMAKE_OSX_SYSROOT="$SDK" "-DCMAKE_CXX_FLAGS=-nostdinc++ -isystem $SDK/usr/include/c++/v1")
fi

export PATH="$(dirname "$CMAKE"):$PATH"
"$CMAKE" -S "$ROOT/core" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_METAL=OFF \
  -DGGML_BLAS=OFF \
  -DGGML_OPENMP=OFF \
  -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF -DLLAMA_OPENSSL=OFF -DLLAMA_CURL=OFF \
  "${EXTRA[@]}" >/dev/null
"$CMAKE" --build "$BUILD" -j "$(sysctl -n hw.ncpu)" >/dev/null
find "$BUILD" -name "*.a" | sed "s|$BUILD/|  |"
echo "core built for macOS in $BUILD"
