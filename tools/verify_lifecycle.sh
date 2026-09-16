#!/usr/bin/env bash
# spine: C2 — W08 / M4 — after a reply, RSS must fall back to about the Compose baseline within ~30s.
# Usage: open Arivu on the phone, send one message, wait for the reply to finish, then run this.
set -euo pipefail
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
PKG="${PKG:-io.github.brettleehari.arivu}"
sample() { "$ADB" shell dumpsys meminfo "$PKG" | awk '/TOTAL RSS:/{print $3; exit} /TOTAL PSS:/{pss=$3} END{}'; }
echo "t=0s   RSS kB: $(sample)"
for t in 10 20 30 40; do sleep 10; echo "t=${t}s  RSS kB: $(sample)"; done
"$ADB" logcat -d -s arivu-lifecycle:I | tail -5
echo "Expect an 'arivu-lifecycle: context freed: idle 30000ms' line and a drop of roughly KV + compute (~200MB)."
