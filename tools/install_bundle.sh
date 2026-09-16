#!/usr/bin/env bash
# Installs the AAB on a connected device the way Play would: base + ABI split + install-time model pack.
# (assembleDebug APKs do not contain asset packs.)
#   tools/install_bundle.sh [debug|release]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARIANT="${1:-debug}"
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
"$ROOT/tools/fetch_bundletool.sh" >/dev/null  # download if missing + sha256 pin (T8)
cd "$ROOT/android"
CAP="$(tr "[:lower:]" "[:upper:]" <<<"${VARIANT:0:1}")${VARIANT:1}"
./gradlew ":app:bundle$CAP" --console=plain -q
AAB="app/build/outputs/bundle/$VARIANT/app-$VARIANT.aab"
TMP="$(mktemp -d)"
"$JAVA" -jar "$ROOT/tools/bin/bundletool.jar" build-apks --bundle "$AAB" --output "$TMP/app.apks" --connected-device --local-testing
unzip -q -o "$TMP/app.apks" -d "$TMP/x"
for apk in $(find "$TMP/x" -name 'modelpack*.apk'); do "$ROOT/tools/zip_entry_offset.py" "$apk" .gguf; done
"$JAVA" -jar "$ROOT/tools/bin/bundletool.jar" install-apks --apks "$TMP/app.apks"
