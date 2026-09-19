#!/usr/bin/env bash
# Installs the AAB on a connected device the way Play would: base + ABI split + install-time model pack.
# (assembleDebug APKs do not contain asset packs.)
#   tools/install_bundle.sh [debug|release]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARIANT="${1:-debug}"
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"

# bundletool locates adb through ANDROID_HOME or PATH and fails outright without either:
# "Unable to determine the location of ADB". Neither is guaranteed on a machine that drives the
# build through Gradle and android/local.properties, where nothing ever needs to export it. Take
# it from local.properties first, since that is the file the Android build already trusts, then the
# default install location. tools/bench.sh defaults its adb path for the same reason.
if [[ -z "${ANDROID_HOME:-}" ]]; then
  SDK_DIR="$(sed -n 's/^sdk.dir=//p' "$ROOT/android/local.properties" 2>/dev/null | head -1)"
  export ANDROID_HOME="${SDK_DIR:-$HOME/Library/Android/sdk}"
fi
[[ -x "$ANDROID_HOME/platform-tools/adb" ]] || { echo "no adb under $ANDROID_HOME; set ANDROID_HOME" >&2; exit 1; }
export PATH="$ANDROID_HOME/platform-tools:$PATH"
"$ROOT/tools/fetch_bundletool.sh" >/dev/null  # download if missing + sha256 pin (T8)
cd "$ROOT/android"
CAP="$(tr "[:lower:]" "[:upper:]" <<<"${VARIANT:0:1}")${VARIANT:1}"
./gradlew ":app:bundle$CAP" --console=plain -q
AAB="app/build/outputs/bundle/$VARIANT/app-$VARIANT.aab"
TMP="$(mktemp -d)"
"$JAVA" -jar "$ROOT/tools/bin/bundletool.jar" build-apks --bundle "$AAB" --output "$TMP/app.apks" --connected-device --local-testing
unzip -q -o "$TMP/app.apks" -d "$TMP/x"
# /usr/bin/python3, not the shebang: the first python3 on PATH can be an x86_64 build that dies
# with "Bad CPU type in executable" on Apple silicon. tools/bench.sh, release_check.sh and
# ios_release_check.sh all name the system interpreter for the same reason.
PY_BIN="${PYTHON:-/usr/bin/python3}"
for apk in $(find "$TMP/x" -name 'modelpack*.apk'); do "$PY_BIN" "$ROOT/tools/zip_entry_offset.py" "$apk" .gguf; done
"$JAVA" -jar "$ROOT/tools/bin/bundletool.jar" install-apks --apks "$TMP/app.apks"
