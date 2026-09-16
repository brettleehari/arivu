#!/usr/bin/env bash
# spine: C9, C3, C1 — release gate. Fails a Play release while a store-blocking item is unresolved.
# Usage: tools/release_check.sh [path/to/app-release.aab]
# Checks, in order (each prints PASS/FAIL; the script exits non-zero if any FAIL):
#   1. arivu.reportEmail is a real address, not the D-010 placeholder — also in the compiled dex
#   2. arivu.applicationId is set, well-formed, and D-001 / D-010 are no longer pending in decisions.yml
#   3. the AAB's package matches arivu.applicationId; not debuggable; targetSdk >= 36 (Play, 2026-08-31)
#   4. tools/check_manifest.sh (no network permission, arm64-v8a only, ram.normal, backup off)
#   5. every native lib's ELF LOAD segments are 16 KB aligned
#   6. model asset is in an install-time pack, uncompressed per BundleConfig, named *.gguf.so (D-013)
#   7. in-app licence texts are in the bundle
#   8. the AAB is signed (upload key)
#   9. tools/trace.py --strict (no commitment without implementation and test)
# Console-only items (privacy policy URL, Data safety, content rating, target audience, AI reporting
# review) cannot be checked from here: see leaves/compliance/play-policy-checklist.md.
#
# PLATFORM: this gate is Google Play only. Since Spine 0.2 the App Store sibling is
# tools/ios_release_check.sh (checklist: leaves/compliance/appstore-policy-checklist.md). The two
# scripts share step 9 (tools/trace.py --strict) and nothing else, because almost none of the
# evidence transfers: C3 is proved here by a missing INTERNET permission and there by the absence of
# any networking framework, symbol or entitlement in the Mach-O. play-policy-checklist.md §16 lists
# every answer that differs.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AAB="${1:-$ROOT/android/app/build/outputs/bundle/release/app-release.aab}"
PROPS="$ROOT/android/gradle.properties"
PY=/usr/bin/python3
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
BT="$ROOT/tools/bin/bundletool.jar"
fail=0
pass() { echo "PASS  $*"; }
bad()  { echo "FAIL  $*"; fail=1; }
prop() { grep -E "^$1=" "$PROPS" | tail -1 | cut -d= -f2- | tr -d '[:space:]'; }

# 1. Report address (D-010)
email="$(prop arivu.reportEmail)"
if [[ -z "$email" ]]; then
  bad "arivu.reportEmail is empty"
elif ! grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' <<<"$email"; then
  bad "arivu.reportEmail is not an email address: $email"
elif grep -qiE '(@|\.)(example\.(com|org|net|invalid)|invalid|test|localhost)$|^report@example' <<<"$email"; then
  bad "arivu.reportEmail is still a placeholder ($email) — resolve decisions.yml D-010"
else
  pass "report address: $email"
fi

# 2. Application id (D-001) and decision status
appid="$(prop arivu.applicationId)"
if [[ -z "$appid" || "$appid" == *'$'* ]]; then
  bad "arivu.applicationId is unresolved"
elif ! grep -qE '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' <<<"$appid"; then
  bad "arivu.applicationId is not a valid package name: $appid"
else
  pass "applicationId: $appid"
fi
for d in D-001 D-010; do
  status="$("$PY" - "$ROOT/leaves/decisions.yml" "$d" <<'PYEOF'
import sys, yaml
for e in yaml.safe_load(open(sys.argv[1])) or []:
    if e.get("id") == sys.argv[2]:
        print(e.get("status", "missing")); break
else:
    print("missing")
PYEOF
)"
  case "$status" in
    resolved_human|resolved_ai|overridden) pass "$d status: $status" ;;
    *) bad "$d is $status in leaves/decisions.yml — a human must resolve it before the first upload" ;;
  esac
done

if [[ ! -f "$AAB" ]]; then
  bad "release bundle not found: $AAB (run ./gradlew :app:bundleRelease)"
  echo "RELEASE CHECK: FAILED"; exit 1
fi
"$ROOT/tools/fetch_bundletool.sh" >/dev/null && pass "bundletool sha256 pinned" || bad "bundletool missing or sha256 mismatch (tools/fetch_bundletool.sh)"

# 1b. The compiled artifact, not just the property file
dexhits="$(unzip -p "$AAB" 'base/dex/*.dex' 2>/dev/null | LC_ALL=C grep -aoE '[A-Za-z0-9._%+-]+@example\.invalid' | sort -u)"
[[ -z "$dexhits" ]] && pass "no placeholder report address in dex" || bad "placeholder address compiled into dex: $dexhits (rebuild after fixing gradle.properties)"

# 3. Manifest identity
if [[ -f "$BT" ]]; then
  manifest="$("$JAVA" -jar "$BT" dump manifest --bundle "$AAB" 2>/dev/null)"
  pkg="$(grep -oE ' package="[^"]+"' <<<"$manifest" | head -1 | sed -E 's/.*"([^"]+)"/\1/')"
  [[ "$pkg" == "$appid" ]] && pass "bundle package matches applicationId" || bad "bundle package '$pkg' != arivu.applicationId '$appid' (stale bundle?)"
  grep -q 'android:debuggable="true"' <<<"$manifest" && bad "bundle is debuggable" || pass "not debuggable"
  tsdk="$(grep -oE 'targetSdkVersion="[0-9]+"' <<<"$manifest" | grep -oE '[0-9]+')"
  [[ -n "$tsdk" && "$tsdk" -ge 36 ]] && pass "targetSdk $tsdk" || bad "targetSdk '$tsdk' < 36 (Play requirement since 2026-08-31)"
fi

# 4. Network permission / ABI / backup
cm_log="$(mktemp)"
if "$ROOT/tools/check_manifest.sh" "$AAB" >"$cm_log" 2>&1; then
  pass "tools/check_manifest.sh"
else
  sed 's/^/      /' "$cm_log"; bad "tools/check_manifest.sh"
fi
rm -f "$cm_log"

# 5-7. Native lib alignment, model asset storage, licence assets
"$PY" - "$AAB" <<'PYEOF' || fail=1
import struct, sys, zipfile
z = zipfile.ZipFile(sys.argv[1]); bad = 0
def out(ok, msg):
    global bad
    print(("PASS  " if ok else "FAIL  ") + msg); bad |= (not ok)
libs = [i for i in z.infolist() if "/lib/" in i.filename and i.filename.endswith(".so")]
out(bool(libs), f"{len(libs)} native libs in bundle")
for i in libs:
    b = z.read(i)
    if b[:4] != b"\x7fELF" or b[4] != 2:
        out(False, f"{i.filename}: not ELF64"); continue
    phoff, = struct.unpack_from("<Q", b, 0x20); phentsize, phnum = struct.unpack_from("<HH", b, 0x36)
    aligns = [struct.unpack_from("<Q", b, phoff + k*phentsize + 0x30)[0]
              for k in range(phnum) if struct.unpack_from("<I", b, phoff + k*phentsize)[0] == 1]
    if not aligns or min(aligns) < 16384:
        out(False, f"{i.filename}: LOAD align {aligns} < 16384")
out(not bad, "all native LOAD segments >= 16 KB aligned") if libs else None
models = [i for i in z.infolist() if "/assets/model/" in i.filename]
out(len(models) == 1 and not models[0].filename.startswith("base/"), f"model in an asset pack: {[m.filename for m in models]}")
for m in models:
    # The AAB itself may deflate the entry; what matters is that bundletool is told to store it in
    # the generated APKs (BundleConfig uncompressed glob). W18 verifies Play's actual output.
    cfg = z.read("BundleConfig.pb")
    out(b"**.[gG][gG][uU][fF].[sS][oO]" in cfg or b"**[gG][gG][uU][fF]" in cfg,
        f"{m.filename} marked uncompressed in BundleConfig (stored in generated APKs)")
    out(m.filename.endswith(".gguf.so"), f"{m.filename} named *.gguf.so (D-013)")
    pack = m.filename.split("/")[0]
    try:
        pm = z.read(f"{pack}/manifest/AndroidManifest.xml")
        out(b"install-time" in pm, f"{pack} declares install-time delivery")
    except KeyError:
        out(False, f"{pack} has no manifest")
names = set(z.namelist())
for f in ("index.txt", "NOTICE.txt", "Apache-2.0.txt", "llama.cpp-MIT.txt", "llama.cpp-embedded-MIT.txt", "qwen3-Apache-2.0.txt",
          "threetenbp-BSD-3-Clause.txt", "Unicode-3.0.txt"):
    out(f"base/assets/licenses/{f}" in names, f"licence asset {f}")
sys.exit(1 if bad else 0)
PYEOF

# 8. Signature
if unzip -Z1 "$AAB" | grep -qE '^META-INF/[^/]+\.(RSA|DSA|EC)$'; then
  # Play registers whatever key signs the FIRST upload as the upload key, so a throwaway test key must never pass.
  owner="$("${JAVA_HOME:+$JAVA_HOME/bin/}keytool" -printcert -jarfile "$AAB" 2>/dev/null | grep -m1 '^Owner:' || true)"
  if grep -qiE 'NOT.FOR.UPLOAD|THROWAWAY|Android Debug' <<<"$owner"; then
    bad "bundle is signed with a test key ($owner) — sign with the real upload key (tools/make_upload_key.sh)"
  else
    pass "bundle is signed ($owner)"
  fi
else
  bad "bundle is unsigned — sign with the upload key (W17) before uploading"
fi

# 9. Traceability
if "$PY" "$ROOT/tools/trace.py" --strict; then pass "tools/trace.py --strict"; else bad "tools/trace.py --strict"; fi

echo
echo "Console-only items are NOT checked here: leaves/compliance/play-policy-checklist.md"
[[ $fail == 0 ]] && echo "RELEASE CHECK: PASSED" || echo "RELEASE CHECK: FAILED"
exit $fail
