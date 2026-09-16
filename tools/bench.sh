#!/usr/bin/env bash
# W01 — run the benchmark harness on the connected physical test phone and pull the JSON report.
#   tools/bench.sh                                  # full: threads 2,4,heuristic + 10-min thermal soak
#   tools/bench.sh -e thermalMinutes 0              # quick
#   tools/bench.sh -e repack false,true -e threads 4
# Paste the summary into NOTES.md. Emulators do not count (CLAUDE.md "Test device").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
"$ADB" get-state >/dev/null
if [[ "$("$ADB" shell getprop ro.kernel.qemu)" == "1" ]]; then
  echo "refusing: emulator detected; benchmark only on the physical test phone" >&2; exit 1
fi
"$ROOT/tools/fetch_model.sh"
cd "$ROOT/android"
./gradlew :llama:assembleDebugAndroidTest --console=plain -q
# AGP's APK packager gives non-lib assets 4-byte alignment; Play's bundletool page-aligns ".so" entries.
# Re-align to 16K so the benchmark mmaps the model exactly as the Play-installed app will (D-013).
BT="$(ls -d "$HOME"/Library/Android/sdk/build-tools/* | sort -V | tail -1)"
SRC=llama/build/outputs/apk/androidTest/debug/llama-debug-androidTest.apk
ALIGNED="$ROOT/build/bench/llama-androidTest-aligned.apk"; mkdir -p "$(dirname "$ALIGNED")"
"$BT/zipalign" -f 16384 "$SRC" "$ALIGNED"
"$BT/apksigner" sign --ks "$HOME/.android/debug.keystore" --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android "$ALIGNED"
"$ROOT/tools/zip_entry_offset.py" "$ALIGNED" .gguf
"$ADB" install -r -t "$ALIGNED"
"$ADB" logcat -c
"$ADB" shell am instrument -w -r "$@" -e class io.github.brettleehari.arivu.llama.Benchmark io.github.brettleehari.arivu.llama.test/androidx.test.runner.AndroidJUnitRunner
OUT="$ROOT/build/bench"; mkdir -p "$OUT"
"$ADB" logcat -d -s arivu-bench:I | sed -n 's/.*ARIVU_BENCH_JSON //p' | tr -d '\n' > "$OUT/bench-$(date +%Y%m%d-%H%M%S).json"
"$ADB" logcat -d -s arivu-bench:I | grep -v ARIVU_BENCH_JSON
echo "report: $(ls -t "$OUT"/bench-*.json | head -1)"
