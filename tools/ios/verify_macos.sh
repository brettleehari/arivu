#!/usr/bin/env bash
# Builds every ArivuKit target for macOS and runs the test suites, WITHOUT SwiftPM.
#
# Why this exists at all: `swift test` is the normal way to do this and it is what CI and Hari's Mac
# should use. On the machine this port was written on, SwiftPM cannot load ANY package manifest —
# the Command Line Tools ship a PackageDescription.swiftmodule newer than the libPackageDescription
# dylib beside it, so every `Package.swift` fails to link with
#   Undefined symbols: PackageDescription.SwiftVersion
# (reproduce with an empty package; it is not this package). The Swift compiler itself is fine, so
# this script drives swiftc directly over exactly the sources and tests the manifest declares.
#
# It also works around a second CLT defect: usr/include/swift ships both module.modulemap and
# bridging.modulemap defining SwiftBridging, so `import Foundation` fails with "redefinition of
# module". A VFS overlay blanks the stale one. Both workarounds are no-ops on a healthy toolchain.
#
# ARIVU_REAL_CORE=1 links the real /core built for macOS instead of the C stub, so the CoreParity
# tests (which skip against the stub) actually execute. Build the core first:
#   cmake -S core -B build/core-macos -DCMAKE_BUILD_TYPE=Release ... ; cmake --build build/core-macos
# tools/ios/build_core_macos.sh does exactly that.
#
# On a Mac with Xcode, prefer:   cd ios/ArivuKit && swift test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="$ROOT/ios/ArivuKit"
BUILD="${BUILD_DIR:-$ROOT/build/ios-verify}"
SWIFT_VERSION="${SWIFT_VERSION:-6}"
TESTING_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

rm -rf "$BUILD"
mkdir -p "$BUILD"

# --- workaround 1: the duplicate SwiftBridging module map -------------------------------------
OVERLAY=()
STALE=/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
if [[ -f "$STALE" && -f /Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap ]]; then
  : > "$BUILD/empty.modulemap"
  cat > "$BUILD/vfs.yaml" <<EOF
{
  "version": 0,
  "roots": [
    { "name": "/Library/Developer/CommandLineTools/usr/include/swift",
      "type": "directory",
      "contents": [
        { "name": "module.modulemap", "type": "file", "external-contents": "$BUILD/empty.modulemap" }
      ]
    }
  ]
}
EOF
  OVERLAY=(-vfsoverlay "$BUILD/vfs.yaml")
fi

CORE_MODULEMAP="$PKG/Sources/CArivuCore/module.modulemap"
# -enable-testing so the suites can `@testable import`, exactly as `swift test` builds them.
COMMON=("${OVERLAY[@]}" -swift-version "$SWIFT_VERSION" -I "$BUILD" -enable-testing
        -Xcc "-fmodule-map-file=$CORE_MODULEMAP")

say() { printf '\n== %s\n' "$1"; }

# --- the fake core (C) -------------------------------------------------------------------------
REAL_CORE="${ARIVU_REAL_CORE:-0}"
CORE_LIBS_DIR="${CORE_LIBS_DIR:-$ROOT/build/core-macos}"

# Which core the tests link against. The stub keeps this runnable with nothing built; the real core
# is what makes the CoreParity suites execute instead of skipping.
CORE_OBJECTS=()
if [[ "$REAL_CORE" == "1" ]]; then
  # bash 3.2 on macOS has no mapfile
  while IFS= read -r lib; do CORE_OBJECTS+=("$lib"); done < <(find "$CORE_LIBS_DIR" -name "*.a" 2>/dev/null)
  if [[ ${#CORE_OBJECTS[@]} -eq 0 ]]; then
    echo "ARIVU_REAL_CORE=1 but no static libs under $CORE_LIBS_DIR — run tools/ios/build_core_macos.sh" >&2
    exit 1
  fi
  # The behaviour tests drive the stub through knobs the real core does not have, so linking both
  # would be a duplicate-symbol error. Supply the knobs as no-ops and run only the parity suite:
  # against the real core those tests stop skipping, which is the entire point of this mode.
  cat > "$BUILD/stub_knobs_noop.c" <<'KNOBS'
#include <stddef.h>
void arivu_stub_set_script(const char * utf8) { (void) utf8; }
void arivu_stub_set_piece_delay_us(int micros) { (void) micros; }
void arivu_stub_fail_next_load(const char * message) { (void) message; }
void arivu_stub_fail_next_context(const char * message) { (void) message; }
void arivu_stub_next_stop_context_full(void) { }
int  arivu_stub_live_engines(void) { return 0; }
void arivu_stub_reset(void) { }
KNOBS
  clang -c "$BUILD/stub_knobs_noop.c" -o "$BUILD/stub_knobs_noop.o"
  CORE_OBJECTS+=("$BUILD/stub_knobs_noop.o" -lc++ -framework Accelerate -framework Foundation)
  echo "linking the REAL core: ${#CORE_OBJECTS[@]} inputs from $CORE_LIBS_DIR"
else
  CORE_OBJECTS=("$BUILD/arivu_stub.o")
fi

say "CArivuStub (C)"
clang -c -O0 -g -std=c11 -Wall -Wextra -Werror \
      -I "$PKG/Sources/CArivuStub" \
      "$PKG/Sources/CArivuStub/arivu_stub.c" -o "$BUILD/arivu_stub.o"
# A module map so Swift can `import CArivuStub` for its knobs.
mkdir -p "$BUILD/CArivuStub"
cp "$PKG/Sources/CArivuStub/include/arivu_stub.h" "$BUILD/CArivuStub/"
cat > "$BUILD/CArivuStub/module.modulemap" <<EOF
module CArivuStub {
    header "arivu_stub.h"
    export *
}
EOF

# --- the Swift libraries -----------------------------------------------------------------------
build_module() {
  local name="$1"; shift
  say "$name"
  swiftc "${COMMON[@]}" -module-name "$name" \
    -emit-module -emit-module-path "$BUILD/$name.swiftmodule" \
    -emit-library -static -o "$BUILD/lib$name.a" \
    "$@"
}

build_module ArivuCore "$PKG"/Sources/ArivuCore/*.swift
build_module ArivuEngine "$PKG"/Sources/ArivuEngine/*.swift
build_module ArivuChat "$PKG"/Sources/ArivuChat/*.swift

# --- the tests ---------------------------------------------------------------------------------
# swift-testing ships with the toolchain; SwiftPM normally generates the entry point, so the
# runner below is the three lines SwiftPM would have written.
cat > "$BUILD/main.swift" <<'EOF'
import Testing

@main struct ArivuKitTests {
    static func main() async { await Testing.__swiftPMEntryPoint() as Never }
}
EOF

say "tests"
swiftc "${COMMON[@]}" \
  -Xcc "-fmodule-map-file=$BUILD/CArivuStub/module.modulemap" \
  -parse-as-library \
  -F "$TESTING_FRAMEWORKS" -framework Testing \
  -Xlinker -rpath -Xlinker "$TESTING_FRAMEWORKS" \
  -L "$BUILD" -lArivuCore -lArivuEngine -lArivuChat \
  "${CORE_OBJECTS[@]}" \
  "$PKG"/Tests/ArivuCoreTests/*.swift \
  "$PKG"/Tests/ArivuEngineTests/*.swift \
  "$PKG"/Tests/ArivuChatTests/*.swift \
  "$BUILD/main.swift" \
  -o "$BUILD/ArivuKitTests"

say "running"
# The copy catalogue is a SwiftPM resource; without SwiftPM there is no resource bundle, so point
# the catalogue loader at the source directory. The app and `swift test` both find it by themselves.
export ARIVU_STRINGS_DIR="$PKG/Sources/ArivuCore/Resources"
set +e
# --no-parallel: the fake core has process-wide knobs (script, delays, forced failures), so two
# suites running at once would set each other's. `swift test --no-parallel` for the same reason.
FILTER=()
if [[ "$REAL_CORE" == "1" ]]; then
  FILTER=(--filter "CoreParityTests")
fi
"$BUILD/ArivuKitTests" --no-parallel "${FILTER[@]}" 2>&1 | tee "$BUILD/test-output.txt"
set -e
if grep -q "Test run with .* passed" "$BUILD/test-output.txt"; then
  echo
  echo "ALL PASSED  ($(grep -o 'Test run with [0-9]* tests passed' "$BUILD/test-output.txt" | tail -1))"
else
  echo
  echo "FAILED — see $BUILD/test-output.txt"
  exit 1
fi
