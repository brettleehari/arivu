#!/usr/bin/env bash
# Builds /core + llama.cpp into build/ios/ArivuCore.xcframework — device and simulator.
#
# UNVERIFIED: this script has never been run. There is no Xcode and no iOS SDK on the machine it was
# written on, and CMake is not installed there either. Every flag below is deliberate and the
# reasoning is in the comments, but the first person to run it should expect to fix something.
#
# What it produces:
#   build/ios/ArivuCore.xcframework
#     ios-arm64/libArivuCore.a                 device
#     ios-arm64-simulator/libArivuCore.a       simulator on Apple silicon (arm64 only, deliberately:
#                                              an x86_64 slice would only serve Intel Macs, which
#                                              cannot run a useful benchmark anyway)
#     Headers/arivu/arivu.h
#
# Each slice is ONE static library: llama.cpp produces several (llama, ggml, ggml-base, ggml-cpu…)
# and Xcode will not take a folder of them, so libtool merges them per platform.
#
# spine: C2, C11
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build/ios}"
OUT="$BUILD/ArivuCore.xcframework"
DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-17.0}"
CONFIG="${CONFIG:-Release}"

# cmake, with the same fallback tools/host/run_smoke.sh uses: the Android SDK ships cmake AND ninja
# under $ANDROID_HOME/cmake/<version>/bin, so a machine set up for the Android build already has
# both and needs no Homebrew. Putting that directory on PATH is also what lets -G Ninja find ninja.
CMAKE="${CMAKE:-$(command -v cmake || ls -d "$HOME"/Library/Android/sdk/cmake/*/bin/cmake 2>/dev/null | sort -V | tail -1)}"
[[ -x "$CMAKE" ]] || { echo "cmake not found. Install it, or set CMAKE=/path/to/cmake."; exit 1; }
export PATH="$(dirname "$CMAKE"):$PATH"
command -v xcodebuild >/dev/null || { echo "xcodebuild not found — install Xcode, not just the Command Line Tools"; exit 1; }
[[ -f "$ROOT/third_party/llama.cpp/src/llama-mmap.cpp" ]] || { echo "run tools/llama/fetch_llama.sh first"; exit 1; }

# --- why these flags -----------------------------------------------------------------------------
#
# GGML_METAL=OFF is the important one, and it is a memory decision, not a speed one.
#   Jetsam charges phys_footprint, which excludes clean file-backed pages. The mmap'd weights are
#   therefore very nearly free against the limit. Metal buffers are dirty memory: offloading layers
#   would convert ~373 MB of uncharged clean pages into charged memory and delete the property the
#   whole budget rests on. n_gpu_layers stays 0, and this is where that is enforced.
#   It is also what keeps Android and iOS on the same code path, so a tok/s number means the same
#   thing on both (C11).
#   Turning it on is a profile decision with a measurement behind it, never a convenience. Proposed
#   as a decision in leaves/engineering-ios.md; ARIVU_METAL=1 exists so the experiment is one flag.
#
# GGML_ACCELERATE=ON uses Apple's BLAS for prompt processing. CPU-side, no extra dirty memory.
# GGML_OPENMP=OFF — iOS has no libomp to link against.
# LLAMA_CURL=OFF and the BUILD_* switches — Arivu links no networking and builds no tools (C3).
METAL="${ARIVU_METAL:-0}"
[[ "$METAL" == "1" ]] && echo "WARNING: building with Metal. Read the comment above before trusting a memory number."

common_flags=(
  -DCMAKE_SYSTEM_NAME=iOS
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
  -DCMAKE_BUILD_TYPE="$CONFIG"
  -DBUILD_SHARED_LIBS=OFF
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DGGML_METAL=$([[ "$METAL" == "1" ]] && echo ON || echo OFF)
  -DGGML_METAL_EMBED_LIBRARY=$([[ "$METAL" == "1" ]] && echo ON || echo OFF)
  -DGGML_ACCELERATE=ON
  -DGGML_BLAS=OFF
  -DGGML_OPENMP=OFF
  -DGGML_NATIVE=OFF
  -DLLAMA_CURL=OFF
  -DLLAMA_BUILD_TESTS=OFF
  -DLLAMA_BUILD_EXAMPLES=OFF
  -DLLAMA_BUILD_TOOLS=OFF
  -DLLAMA_BUILD_SERVER=OFF
)

build_slice() {
  local name="$1" sysroot="$2" archs="$3"
  local dir="$BUILD/$name"
  echo "== $name ($sysroot, $archs)"
  "$CMAKE" -S "$ROOT/core" -B "$dir" -G Ninja \
    "${common_flags[@]}" \
    -DCMAKE_OSX_SYSROOT="$sysroot" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    >/dev/null
  "$CMAKE" --build "$dir" --config "$CONFIG" -j "$(sysctl -n hw.ncpu)"

  # Merge every static library the build produced into one. `find` rather than a list, because the
  # set of ggml backend libraries changes between llama.cpp versions and a stale list fails at link
  # time inside Xcode, which is the worst place to find out.
  local libs
  libs=$(find "$dir" -name '*.a' -not -name 'libArivuCore.a' | sort)
  [[ -n "$libs" ]] || { echo "no static libraries produced in $dir"; exit 1; }
  echo "$libs" | sed 's/^/   /'
  # shellcheck disable=SC2086
  libtool -static -o "$dir/libArivuCore.a" $libs
}

rm -rf "$BUILD"
mkdir -p "$BUILD"

build_slice "device" "iphoneos" "arm64"
build_slice "simulator" "iphonesimulator" "arm64"

HEADERS="$BUILD/Headers"
mkdir -p "$HEADERS/arivu"
cp "$ROOT/core/include/arivu/arivu.h" "$HEADERS/arivu/"

rm -rf "$OUT"
xcodebuild -create-xcframework \
  -library "$BUILD/device/libArivuCore.a"    -headers "$HEADERS" \
  -library "$BUILD/simulator/libArivuCore.a" -headers "$HEADERS" \
  -output "$OUT"

echo
echo "wrote $OUT"
echo "slices:"
/usr/libexec/PlistBuddy -c "Print AvailableLibraries" "$OUT/Info.plist" | grep -E "LibraryIdentifier|SupportedArchitectures" || true
echo
echo "sizes:"
du -h "$BUILD"/*/libArivuCore.a
