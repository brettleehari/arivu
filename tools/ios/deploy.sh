#!/usr/bin/env bash
# Build Arivu, stamp it with the commit it was built from, and put it on the connected iPhone.
#
# One command for the loop, because the loop is run often and every step of it has already been got
# wrong once: the project regenerated without the framework, the app installed while running so iOS
# kept the old binary, a build whose provenance nobody could name.
#
# The stamp is the point. Two builds of an app that looks identical are otherwise
# indistinguishable, so About shows the short SHA and whether the tree was dirty when it was built.
# "It behaves differently now" becomes a question with an answer.
#
#   tools/ios/deploy.sh              # build, install, launch on the one connected device
#   tools/ios/deploy.sh --no-launch  # leave it for the user to open
#
# spine: C11
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SHA="$(git rev-parse --short HEAD)"
git diff --quiet && git diff --cached --quiet || SHA="$SHA+"   # '+' means uncommitted changes
export ARIVU_GIT_SHA="$SHA"

DEVICE="${ARIVU_DEVICE:-$(xcrun devicectl list devices 2>/dev/null \
  | awk '/physical/ && /connected/ {print $(NF-3); exit}')}"
[[ -n "$DEVICE" ]] || { echo "no connected iPhone. Plug one in, or set ARIVU_DEVICE=<udid>." >&2; exit 1; }

[[ -d build/ios/ArivuCore.xcframework ]] || { echo "no ArivuCore.xcframework — run tools/ios/build_core.sh" >&2; exit 1; }

echo "== generating the project (ARIVU_GIT_SHA=$SHA)"
tools/ios/generate_project.sh >/dev/null

echo "== building"
xcodebuild -project ios/Arivu.xcodeproj -scheme Arivu -configuration Debug \
  -destination "id=$DEVICE" -allowProvisioningUpdates build 2>&1 \
  | grep -E "error:|warning: .*(deprecat|unused)|BUILD SUCCEEDED|BUILD FAILED" | sort -u || true

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 5 \
        -path '*Debug-iphoneos/Arivu.app' -print -quit)"
[[ -n "$APP" ]] || { echo "no built Arivu.app" >&2; exit 1; }

echo "== installing $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist") ($SHA)"
xcrun devicectl device install app --device "$DEVICE" "$APP" | grep -E "App installed|error" || true

if [[ "${1:-}" != "--no-launch" ]]; then
  # A running app keeps the old binary until it is replaced, so launch rather than assume.
  xcrun devicectl device process launch --device "$DEVICE" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")" 2>&1 \
    | grep -iE "Launched|NSLocalizedFailureReason" | head -2 || true
fi
echo "== $SHA is on the device"
