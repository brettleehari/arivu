#!/usr/bin/env bash
# Pull the App Store screenshots out of the .xcresult the Screenshots suite produced.
#
# They arrive as XCTAttachments because that is the only way a UI test can hand a file back: the
# test runs inside the Simulator and cannot write to this machine. Exporting them is therefore a
# step, not an oversight.
#
# Usage: tools/ios/export_screenshots.sh [output-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/leaves/gtm/screenshots/ios}"

RESULT="$(ls -td "$HOME/Library/Developer/Xcode/DerivedData"/Arivu-*/Logs/Test/*.xcresult 2>/dev/null | head -1)"
[[ -n "$RESULT" ]] || { echo "no .xcresult found — run the Screenshots suite first" >&2; exit 1; }
echo "== $RESULT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$TMP" >/dev/null 2>&1 \
  || { echo "xcresulttool could not export attachments" >&2; exit 1; }

mkdir -p "$OUT"
n=0
# The manifest names each attachment; the files themselves have opaque names.
python3 - "$TMP" "$OUT" <<'PY'
import json, os, shutil, sys
tmp, out = sys.argv[1], sys.argv[2]
manifest = os.path.join(tmp, "manifest.json")
if not os.path.exists(manifest):
    sys.exit("no manifest.json in the export")
for test in json.load(open(manifest)):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a.get("exportedFileName")
        src = os.path.join(tmp, a["exportedFileName"])
        if not name.lower().endswith(".png"):
            name += ".png"
        shutil.copy2(src, os.path.join(out, name))
        print(" ", name)
PY
echo "== screenshots in ${OUT#"$ROOT"/}"
