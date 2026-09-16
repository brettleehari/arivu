#!/usr/bin/env bash
# W01 — run the benchmark harness on the connected physical test phone and pull the JSON report.
#   tools/bench.sh                                  # full: threads 2,4,heuristic + 10-min thermal soak
#   tools/bench.sh -e thermalMinutes 0              # quick
#   tools/bench.sh -e repack false,true -e threads 4
# Paste the summary into leaves/NOTES.md. Emulators do not count (leaves/BRIEF.md "Test device").
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
REPORT="$(ls -t "$OUT"/bench-*.json | head -1)"
echo "report: $REPORT"
# The three numbers that decide whether this phone can run Arivu (M1, M2, M3).
/usr/bin/python3 - "$REPORT" <<'PYEOF'
import json, sys
r = json.load(open(sys.argv[1]))
h, d = r.get("headline", {}), r.get("device", {})
print()
print(f"  device            {d.get('manufacturer','?')} {d.get('model','?')} · {d.get('soc','?')} · {d.get('totalMemBytes',0)/1.073741824e9:.1f} GiB")
print(f"  cold first token  {h.get('coldTimeToFirstTokenMs',0)/1000:>6.1f} s      M1 target <= 15 s     {'PASS' if h.get('coldTimeToFirstTokenMs',9e9) <= 15000 else 'FAIL'}")
print(f"  decode            {h.get('decodeTokPerSecMedian',0):>6.1f} tok/s  M2 target >= 8        {'PASS' if h.get('decodeTokPerSecMedian',0) >= 8 else 'FAIL'}")
print(f"  peak RSS          {h.get('peakRssMb',0):>6.0f} MB     M3 target <= 800      {'PASS' if h.get('peakRssMb',9e9) <= 800 else 'FAIL'}")
t = r.get("thermal", {}).get("throttleOnsetSec", None)
if t is not None:
    print(f"  throttle onset    {'none observed' if t < 0 else f'{t:.0f} s'}")
print(f"\n  at {h.get('threads','?')} threads, repack={h.get('repack','?')}, ttft case '{h.get('ttftCase','?')}'")
print("  Paste this row into leaves/NOTES.md.")
PYEOF
