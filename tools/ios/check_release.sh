#!/usr/bin/env bash
# The build-phase guard: refuses to produce an installable app that is missing something.
#
# It is deliberately THIN. The real release gate is `tools/ios_release_check.sh`, written by the
# Compliance Leaf, which inspects a finished .app or .ipa against
# `leaves/compliance/appstore-policy-checklist.md` — privacy manifest, networking symbols, licences,
# encryption declaration, version numbers, the placeholder address, and `tools/trace.py --strict`.
# This script's only job is to run that gate at the moment it can still stop a build, and to check
# by hand the two or three things that are cheap enough to be worth failing on immediately.
#
# Runs only when installing (archive / TestFlight), so a debug build on a laptop with no report
# address configured still works.
#
# UNVERIFIED: never run — there is no Xcode on the machine this was written on.
#
# spine: C1, C3, C9
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail() { echo "error: $1" >&2; exit 1; }

BUNDLE="${TARGET_BUILD_DIR:-}/${WRAPPER_NAME:-}"
PLIST="${TARGET_BUILD_DIR:-}/${INFOPLIST_PATH:-}"

# --- the cheap checks, failed immediately ------------------------------------------------------
[[ -f "$PLIST" ]] || fail "no Info.plist at $PLIST"

EMAIL="$(/usr/libexec/PlistBuddy -c 'Print :ARIVUReportEmail' "$PLIST" 2>/dev/null || echo '')"
[[ -n "$EMAIL" ]] || fail "ARIVUReportEmail is not set; the in-app Report has nowhere to go (spine: C9)"
[[ "$EMAIL" != *example.invalid* ]] || fail "ARIVUReportEmail is still the placeholder ($EMAIL). Decide D-010."

MODEL="${TARGET_BUILD_DIR:-}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}/qwen3-1.7b-q4_k_m.gguf"
[[ -f "$MODEL" ]] || fail "the model is not in the bundle; the app would open into a chat that cannot answer (spine: C1)"

MANIFEST="${TARGET_BUILD_DIR:-}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}/PrivacyInfo.xcprivacy"
[[ -f "$MANIFEST" ]] || fail "PrivacyInfo.xcprivacy is not in the bundle (spine: C3)"

# --- then hand over to the real gate ------------------------------------------------------------
GATE="$ROOT/tools/ios_release_check.sh"
if [[ -x "$GATE" && -d "$BUNDLE" ]]; then
    echo "running the full release gate on $BUNDLE"
    "$GATE" "$BUNDLE"
else
    echo "note: $GATE not run (bundle=$BUNDLE). Run it by hand before any upload:"
    echo "      tools/ios_release_check.sh path/to/Arivu.app"
fi
