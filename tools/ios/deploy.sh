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

# Match the UDID by shape, not by column. Device names contain spaces — "Brettlee's iPhone" —
# so positional awk picked the word "Pro" out of "iPhone 17 Pro Max" and tried to install to that.
DEVICE="${ARIVU_DEVICE:-$(xcrun devicectl list devices 2>/dev/null \
  | grep -E 'connected' | grep -E 'physical' \
  | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}' | head -1)}"
[[ -n "$DEVICE" ]] || { echo "no connected iPhone. Plug one in, or set ARIVU_DEVICE=<udid>." >&2; exit 1; }

[[ -d build/ios/ArivuCore.xcframework ]] || { echo "no ArivuCore.xcframework — run tools/ios/build_core.sh" >&2; exit 1; }

echo "== generating the project (ARIVU_GIT_SHA=$SHA)"
tools/ios/generate_project.sh >/dev/null

echo "== building"
# PIPESTATUS, not the pipeline's status: piping into grep would otherwise report grep's success as
# the build's. This script exists to be believed, so it must not say "on the device" after a failure.
set -o pipefail
xcodebuild -project ios/Arivu.xcodeproj -scheme Arivu -configuration Debug \
  -destination "id=$DEVICE" -allowProvisioningUpdates build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | sort -u
[[ "${PIPESTATUS[0]}" -eq 0 ]] || { echo "build failed" >&2; exit 1; }

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 5 \
        -path '*Debug-iphoneos/Arivu.app' -print -quit)"
[[ -n "$APP" ]] || { echo "no built Arivu.app" >&2; exit 1; }

echo "== installing $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist") ($SHA)"
if ! xcrun devicectl device install app --device "$DEVICE" "$APP" | grep -E "App installed|error"; then
  echo "install failed" >&2; exit 1
fi

LAUNCHED=""
if [[ "${1:-}" != "--no-launch" ]]; then
  # A running app keeps the old binary until it is replaced, so launch rather than assume.
  OUT="$(xcrun devicectl device process launch --device "$DEVICE" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")" 2>&1 || true)"
  echo "$OUT" | grep -iE "Launched|NSLocalizedFailureReason" | head -2 || true
  echo "$OUT" | grep -qi "Launched application" && LAUNCHED=yes
fi

# The install is what "on the device" means, and it succeeded or the script already exited. Whether
# the app actually came up is a separate fact, and a locked phone is the ordinary way it does not —
# so say which happened. This script has lied once already (it used to print success after failing
# to install at all); it does not get to do it quietly in a second place.
if [[ "${1:-}" == "--no-launch" ]]; then
  echo "== $SHA is on the device (not launched, as asked)"
elif [[ -n "$LAUNCHED" ]]; then
  echo "== $SHA is on the device and running"
else
  echo "== $SHA is on the device, but did NOT launch — unlock the phone and open Arivu"
fi
