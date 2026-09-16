#!/usr/bin/env bash
# Generates ios/Arivu.xcodeproj from ios/project.yml.
#
# The .xcodeproj is not committed. It is generated, and regenerating it is the fix for every
# "it works on my machine" problem an Xcode project file creates.
#
# UNVERIFIED: xcodegen is not installed on the machine this was written on.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v xcodegen >/dev/null; then
  cat >&2 <<'MSG'
xcodegen is not installed.

  brew install xcodegen          # or: mint install yonaskolb/XcodeGen

It reads ios/project.yml and writes ios/Arivu.xcodeproj. Nothing else in the repository needs it,
and no generated project file is committed.
MSG
  exit 1
fi

# The report address lives in Info.plist, not in source, so it can be set per build without a commit.
if [[ -n "${ARIVU_REPORT_EMAIL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :ARIVUReportEmail ${ARIVU_REPORT_EMAIL}" "$ROOT/ios/App/Support/Info.plist"
  echo "report address set to ${ARIVU_REPORT_EMAIL}"
fi

cd "$ROOT/ios"
xcodegen generate --spec project.yml
echo
echo "wrote ios/Arivu.xcodeproj — open it with: open ios/Arivu.xcodeproj"
