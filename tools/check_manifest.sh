#!/usr/bin/env bash
# spine: C3, M5 — fails if the shipped bundle can reach the network or ships a non-arm64 ABI.
# Runs automatically after every :app:bundleRelease / :app:bundleDebug (task checkManifest<Variant>, app/build.gradle.kts).
# By hand: tools/check_manifest.sh android/app/build/outputs/bundle/release/app-release.aab
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AAB="${1:-$ROOT/android/app/build/outputs/bundle/release/app-release.aab}"
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
BT="$ROOT/tools/bin/bundletool.jar"
"$ROOT/tools/fetch_bundletool.sh" >/dev/null  # download if missing + sha256 pin (T8)
fail=0

manifest="$("$JAVA" -jar "$BT" dump manifest --bundle "$AAB")"
perms="$(grep -oE 'uses-permission[^>]*android:name="[^"]+"' <<<"$manifest" | sed -E 's/.*name="([^"]+)"/\1/' | sort -u)"
echo "permissions:"; sed 's/^/  /' <<<"$perms"

for forbidden in android.permission.INTERNET android.permission.ACCESS_NETWORK_STATE \
                 android.permission.ACCESS_WIFI_STATE android.permission.CHANGE_NETWORK_STATE; do
  if grep -qx "$forbidden" <<<"$perms"; then echo "FAIL: $forbidden present"; fail=1; fi
done

# Anything not on this list is a Spine question, not a build tweak (decisions.yml D-002, D-006).
allowed='^(android\.permission\.FOREGROUND_SERVICE|android\.permission\.REQUEST_DELETE_PACKAGES|[a-z0-9_.]+\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION)$'
unexpected="$(grep -vE "$allowed" <<<"$perms" || true)"
if [[ -n "$unexpected" ]]; then echo "FAIL: unexpected permissions:"; sed 's/^/  /' <<<"$unexpected"; fail=1; fi

abis="$(unzip -Z1 "$AAB" | grep -oE '^[^/]+/lib/[^/]+/' | awk -F/ '{print $3}' | sort -u)"
echo "abis: $(tr '\n' ' ' <<<"$abis")"
if [[ "$abis" != "arm64-v8a" ]]; then echo "FAIL: ABIs other than arm64-v8a"; fail=1; fi

grep -q 'android.hardware.ram.normal' <<<"$manifest" || { echo "FAIL: ram.normal feature missing"; fail=1; }
grep -q 'android:allowBackup="false"' <<<"$manifest" || { echo "FAIL: backup not disabled"; fail=1; }
# Android 12+ ignores allowBackup for device-to-device transfer; only dataExtractionRules excludes it (threat-model T13).
grep -q 'android:dataExtractionRules=' <<<"$manifest" || { echo "FAIL: dataExtractionRules missing (D2D transfer not excluded)"; fail=1; }

[[ $fail == 0 ]] && echo "OK: no network permission, arm64-v8a only, ram.normal, backup and D2D transfer off"
exit $fail
