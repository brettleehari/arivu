#!/usr/bin/env bash
# Capture the App Store screenshots, from the real app on a 6.9" device.
#
# The simulator's keyboard assists are turned off first, and that is not fussiness: predictive text
# once put the word "The" on the front of a question, and it went into a listing image. A typo in a
# screenshot is seen by everyone who ever looks at the App Store page, and nobody reviews these the
# way they review copy.
#
# Usage: tools/ios/capture_screenshots.sh [simulator-name]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${1:-iPhone 18 Pro Max}"   # 1320x2868 — Apple's 6.9" requirement, no resizing needed

UDID="$(xcrun simctl list devices available | grep -F "$NAME (" | grep -oE '[0-9A-F-]{36}' | head -1)"
[[ -n "$UDID" ]] || { echo "no simulator called '$NAME'" >&2; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true

for k in KeyboardAutocorrection KeyboardPrediction KeyboardShowPredictionBar KeyboardAutocapitalization; do
  xcrun simctl spawn "$UDID" defaults write -g "$k" -bool false 2>/dev/null || true
done

cd "$ROOT/ios"
xcodebuild build-for-testing -project Arivu.xcodeproj -scheme ArivuJourneys \
  -sdk iphonesimulator -configuration Debug | grep -E "TEST BUILD (SUCCEEDED|FAILED)"
xcodebuild test -project Arivu.xcodeproj -scheme ArivuJourneys \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:ArivuUITests/Screenshots \
  | grep -E "Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)|error:|XCTAssert|XCTFail"
# The filter above includes the assertion lines ON PURPOSE. It used to match only the pass/fail
# summary, so a failing capture printed "TEST FAILED" and nothing about why — the same way
# deploy.sh once printed success after failing. A script that hides its own reason is worse than
# no script.
[[ "${PIPESTATUS[0]}" -eq 0 ]] || { echo "capture failed — see above" >&2; exit 1; }

cd "$ROOT"
rm -f leaves/gtm/screenshots/ios/*.png
tools/ios/export_screenshots.sh
# xcresulttool names attachments <name>_<n>_<uuid>.png; the listing wants the name.
for f in leaves/gtm/screenshots/ios/*.png; do
  mv "$f" "$(echo "$f" | sed -E 's/_[0-9]+_[A-F0-9-]+\.png/.png/')"
done
echo "== $(ls leaves/gtm/screenshots/ios/*.png | wc -l | tr -d ' ') screenshots, $(sips -g pixelWidth -g pixelHeight leaves/gtm/screenshots/ios/01-welcome.png 2>/dev/null | tail -2 | tr -d ' \n' | sed 's/pixelWidth:/ /;s/pixelHeight:/x/')"
