#!/usr/bin/env bash
# spine: C9, C3, C1, C11 — release gate for the App Store, the sibling of tools/release_check.sh.
# Usage: tools/ios_release_check.sh [path/to/Arivu.app | path/to/Arivu.ipa]
#
# Checks, in order (each prints PASS/FAIL/NOTE; the script exits non-zero if any FAIL):
#   1. the bundle resolves, and Info.plist and the executable are readable
#   2. the model is a plain file IN THE BUNDLE — not downloaded, not an asset pack, not linked
#      into the executable (leaves/compliance/appstore-policy-checklist.md §9, §13)
#   3. PrivacyInfo.xcprivacy is present, declares no tracking and no collection, and its
#      required-reason declarations match what the shipped binary actually references (§3)
#   4. no network: no networking framework, symbol, entitlement or Info.plist key (C3)
#   5. ITSAppUsesNonExemptEncryption is present and false (§7)
#   6. in-app licences are present and the shipped NOTICE matches the repo's (C4, licence-audit.md)
#   7. version and build numbers are well formed, and the deployment floor is set (§12)
#   8. no placeholder report address survives into the bundle (D-010, mirrors release_check.sh 1b)
#   9. tools/trace.py --strict (no commitment without implementation and test)
#
# App Store Connect-only items (privacy policy URL, App Privacy answers, age rating, export
# compliance review, content rights) cannot be checked from here: see the checklist.
#
# NOTE ON WHAT THIS CAN SEE. There is no Xcode on the machine this was written on, so the binary
# inspection below reads the Mach-O's *strings* — dylib load paths, imported symbol names and the
# embedded entitlements plist all appear there literally. That finds a networking framework or a
# network entitlement reliably; it cannot prove a call is unreachable, and it cannot read __TEXT
# section sizes. Where otool/nm/codesign are available the script uses them and says so.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY=/usr/bin/python3
APP_IN="${1:-$ROOT/build/ios/Arivu.app}"
MIN_IOS="${ARIVU_MIN_IOS:-17.0}"
fail=0
pass() { echo "PASS  $*"; }
bad()  { echo "FAIL  $*"; fail=1; }
note() { echo "NOTE  $*"; }
prop() { grep -E "^$1=" "$ROOT/android/gradle.properties" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]'; }

TMP=""
cleanup() { [[ -n "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT

# 1. Resolve the bundle ------------------------------------------------------------------------
APP="$APP_IN"
if [[ "$APP_IN" == *.ipa ]]; then
  if [[ ! -f "$APP_IN" ]]; then bad "ipa not found: $APP_IN"; echo "IOS RELEASE CHECK: FAILED"; exit 1; fi
  TMP="$(mktemp -d)"
  unzip -q "$APP_IN" -d "$TMP" || { bad "cannot unzip $APP_IN"; echo "IOS RELEASE CHECK: FAILED"; exit 1; }
  APP="$(find "$TMP/Payload" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"
  [[ -n "$APP" ]] || { bad "no Payload/*.app inside $APP_IN"; echo "IOS RELEASE CHECK: FAILED"; exit 1; }
  pass "ipa unpacked: $(basename "$APP")"
fi
if [[ ! -d "$APP" ]]; then
  bad "app bundle not found: $APP"
  echo "      Build one first (Xcode: Product > Archive, or xcodebuild -exportArchive), then pass its path."
  echo "IOS RELEASE CHECK: FAILED"; exit 1
fi
PLIST="$APP/Info.plist"
[[ -f "$PLIST" ]] && pass "Info.plist present" || bad "no Info.plist in $APP"
EXEC_NAME="$($PY -c "
import plistlib,sys
try: print(plistlib.load(open(sys.argv[1],'rb')).get('CFBundleExecutable',''))
except Exception: print('')
" "$PLIST" 2>/dev/null)"
EXEC="$APP/$EXEC_NAME"
if [[ -n "$EXEC_NAME" && -f "$EXEC" ]]; then
  pass "executable: $EXEC_NAME ($(du -h "$EXEC" | cut -f1))"
else
  bad "CFBundleExecutable missing or not a file in the bundle (got '$EXEC_NAME')"
  EXEC=/dev/null
fi

# 2-3, 5, 7. Everything that is a question about the two property lists --------------------------
"$PY" - "$APP" "$PLIST" "$EXEC" "$ROOT" "$MIN_IOS" <<'PYEOF' || fail=1
import os, plistlib, re, sys

app, plist_path, exec_path, root, min_ios = sys.argv[1:6]
bad = 0
def out(ok, msg):
    global bad
    print(("PASS  " if ok else "FAIL  ") + msg)
    bad |= (not ok)
def note(msg): print("NOTE  " + msg)

def load(p):
    try:
        with open(p, "rb") as f: return plistlib.load(f)
    except Exception as e:
        return {"__error__": str(e)}

info = load(plist_path)
if "__error__" in info:
    out(False, f"Info.plist unreadable: {info['__error__']}"); sys.exit(1)

# ---- 2. The model is in the bundle, as a plain file -------------------------------------------
models = []
for dirpath, dirnames, filenames in os.walk(app):
    for f in filenames:
        if f.endswith(".gguf") or f.endswith(".gguf.so"):
            models.append(os.path.relpath(os.path.join(dirpath, f), app))
out(len(models) == 1, f"exactly one model file in the bundle: {models or 'NONE'}")
for m in models:
    size = os.path.getsize(os.path.join(app, m))
    out(size > 300 * 1000 * 1000, f"{m} is {size:,} B (a real GGUF, not a placeholder)")
    out(not m.endswith(".gguf.so"),
        f"{m} is named *.gguf, not *.gguf.so — D-013 is Android packaging and must not cross over")
    out("/" not in m.replace("\\", "/") or not m.startswith("OnDemandResources"),
        f"{m} is not under OnDemandResources")

# On-Demand Resources / Background Assets would mean a first-run download: C1, C2, C3.
odr_dirs = [d for d in os.listdir(app) if d.endswith(".assetpack") or d == "OnDemandResources"]
out(not odr_dirs, f"no on-demand asset packs in the bundle: {odr_dirs or '(none)'}")
odr_keys = [k for k in ("BAManifestURL", "BAInitialDownloadRestrictions", "BAAppGroupID",
                        "BAMaxInstallSize", "BAEssentialMaxInstallSize", "BADownloaderExtension",
                        "NSBundleResourceRequestTags") if k in info]
out(not odr_keys, f"Info.plist declares no downloaded-asset mechanism: {odr_keys or '(none)'}")

# The model must be a resource, never linked into the executable (__TEXT limit is 80 MB).
if os.path.isfile(exec_path):
    esize = os.path.getsize(exec_path)
    out(esize < 80 * 1024 * 1024, f"executable is {esize:,} B (< 80 MB __TEXT ceiling; the model is not linked in)")

# ---- 3. Privacy manifest ----------------------------------------------------------------------
pm_path = os.path.join(app, "PrivacyInfo.xcprivacy")
out(os.path.isfile(pm_path), "PrivacyInfo.xcprivacy at the bundle root")
pm = load(pm_path) if os.path.isfile(pm_path) else {"__error__": "missing"}
declared = {}
if "__error__" not in pm:
    out(pm.get("NSPrivacyTracking") is False, f"NSPrivacyTracking is false (got {pm.get('NSPrivacyTracking')!r})")
    out(pm.get("NSPrivacyTrackingDomains", []) == [], f"NSPrivacyTrackingDomains is empty (got {pm.get('NSPrivacyTrackingDomains')!r})")
    out(pm.get("NSPrivacyCollectedDataTypes", None) == [],
        f"NSPrivacyCollectedDataTypes is an empty array — the positive 'Data Not Collected' statement (got {pm.get('NSPrivacyCollectedDataTypes')!r})")
    for d in pm.get("NSPrivacyAccessedAPITypes", []) or []:
        declared[d.get("NSPrivacyAccessedAPIType", "")] = list(d.get("NSPrivacyAccessedAPITypeReasons", []) or [])
    # Reason codes Apple approves for each category (developer.apple.com, checked 2026-09-15).
    approved = {
        "NSPrivacyAccessedAPICategoryFileTimestamp":  {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"},
        "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1", "8FFB.1", "3D61.1"},
        "NSPrivacyAccessedAPICategoryDiskSpace":      {"85F4.1", "E174.1", "7D9E.1", "B728.1"},
        "NSPrivacyAccessedAPICategoryActiveKeyboards": {"3EC4.1", "54BD.1"},
        "NSPrivacyAccessedAPICategoryUserDefaults":   {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"},
    }
    for cat, reasons in declared.items():
        out(cat in approved, f"{cat} is a real required-reason category")
        out(bool(reasons), f"{cat} declares at least one reason")
        for r in reasons:
            out(r in approved.get(cat, set()), f"{cat} reason {r} is on Apple's approved list")
    # Arivu is not a keyboard; declaring this would be a false statement about the app.
    out("NSPrivacyAccessedAPICategoryActiveKeyboards" not in declared,
        "ActiveKeyboards is not declared (Arivu never reads the keyboard list)")

# Manifest vs binary. Undefined-symbol names and dylib paths are literal strings in a Mach-O, so
# grep finds them without otool. This catches the failure App Store Connect rejects for: a
# required-reason API the binary references and the manifest does not mention.
blob = b""
if os.path.isfile(exec_path):
    with open(exec_path, "rb") as f: blob = f.read()
def refs(*names): return [n for n in names if n.encode() in blob]

evidence = {
    "NSPrivacyAccessedAPICategoryFileTimestamp":
        refs("_fstat", "_fstatat", "_lstat", "_getattrlist", "_getattrlistat", "_fgetattrlist",
             "NSFileModificationDate", "contentModificationDateKey"),
    "NSPrivacyAccessedAPICategoryDiskSpace":
        refs("_statfs", "_statvfs", "_fstatfs", "volumeAvailableCapacity",
             "NSURLVolumeAvailableCapacityKey", "NSURLVolumeAvailableCapacityForImportantUsageKey"),
    "NSPrivacyAccessedAPICategoryUserDefaults":
        refs("_OBJC_CLASS_$_NSUserDefaults", "NSUserDefaults"),
    "NSPrivacyAccessedAPICategorySystemBootTime":
        refs("_mach_absolute_time", "_CACurrentMediaTime", "systemUptime"),
    "NSPrivacyAccessedAPICategoryActiveKeyboards":
        refs("activeInputModes", "UITextInputMode"),
}
if blob:
    for cat, hits in evidence.items():
        if hits and cat not in declared:
            out(False, f"binary references {hits} but {cat} is NOT declared in PrivacyInfo.xcprivacy "
                       f"— App Store Connect rejects this at upload")
        elif hits:
            print(f"PASS  {cat} declared, and the binary does reference {hits}")
        elif cat in declared:
            note(f"{cat} is declared but no matching symbol was found in the executable — harmless, "
                 f"but a manifest should describe what the app does (appstore-policy-checklist.md §3)")
else:
    note("no executable to cross-check the privacy manifest against")

# ---- 4. No network --------------------------------------------------------------------------
# Presence is not the question; the VALUE is. This used to fail on the mere existence of
# UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace, which Arivu declares EXPLICITLY FALSE
# — the safest possible setting, and better documentation than leaving them out and relying on the
# default. A gate that fails the careful spelling of "no" teaches people to delete the "no".
_absent = ("NSAppTransportSecurity", "NSLocalNetworkUsageDescription", "NSBonjourServices",
           "NSUserTrackingUsageDescription")
_must_be_false = ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace")
net_keys = [k for k in _absent if k in info]
net_keys += [k for k in _must_be_false if info.get(k) is True]
out(not net_keys, f"Info.plist opens no network, tracking or file-sharing door: {net_keys or '(none)'}")
for k in _must_be_false:
    if k in info and info.get(k) is False:
        note(f"{k} is declared false, which is the point")

if blob:
    frameworks = [f for f in ("CFNetwork.framework/CFNetwork", "Network.framework/Network",
                              "SystemConfiguration.framework/SystemConfiguration")
                  if f.encode() in blob]
    out(not frameworks, f"executable links no networking framework: {frameworks or '(none)'}")
    symbols = [s for s in ("_OBJC_CLASS_$_NSURLSession", "_OBJC_CLASS_$_NSURLConnection",
                           "_OBJC_CLASS_$_NSURLRequest", "_nw_connection_create",
                           "_CFStreamCreatePairWithSocketToHost", "_SCNetworkReachabilityCreateWithName",
                           "_getaddrinfo")
               if s.encode() in blob]
    out(not symbols, f"executable imports no networking symbol: {symbols or '(none)'}")
    # Entitlements are an embedded XML plist inside the signed binary.
    ent = re.search(rb"<\?xml[^<]*<!DOCTYPE plist.*?</plist>", blob, re.S)
    if ent:
        etext = ent.group(0).decode("utf-8", "replace")
        net_ents = re.findall(r"<key>(com\.apple\.(?:developer\.networking|security\.network|developer\.associated-domains)[^<]*)</key>", etext)
        out(not net_ents, f"entitlements grant no network access: {net_ents or '(none)'}")
        if "com.apple.developer.kernel.increased-memory-limit" in etext:
            note("the increased-memory-limit entitlement is present. The COMPACT profile does not need "
                 "it (appstore-policy-checklist.md §8); it belongs to a future large profile — D-039.")
        else:
            print("PASS  no increased-memory-limit entitlement (not needed by the shipped profile)")
    else:
        note("no embedded entitlements found — is the bundle signed? (codesign -d --entitlements)")

# ---- 5. Export compliance --------------------------------------------------------------------
out(info.get("ITSAppUsesNonExemptEncryption") is False,
    f"ITSAppUsesNonExemptEncryption is false (got {info.get('ITSAppUsesNonExemptEncryption')!r}) "
    f"— without it every upload gets the export questionnaire")
out("ITSEncryptionExportComplianceCode" not in info,
    "no ITSEncryptionExportComplianceCode (none is needed when no non-exempt encryption is used)")

# ---- 6. Licences ------------------------------------------------------------------------------
index = None
for dirpath, _, filenames in os.walk(app):
    if "index.txt" in filenames and os.path.basename(dirpath).lower() in ("licenses", "licences"):
        index = os.path.join(dirpath, "index.txt"); break
out(index is not None, "in-app licences index found in the bundle")
if index:
    lic_dir = os.path.dirname(index)
    entries = [l.split("|") for l in open(index).read().splitlines() if l.strip()]
    out(bool(entries), f"licences index has {len(entries)} entries")
    for e in entries:
        f = os.path.join(lic_dir, e[-1])
        out(os.path.isfile(f) and os.path.getsize(f) > 500, f"licence text present: {e[-1]}")
    names = "\n".join(e[0] for e in entries)
    # The iOS bundle drops libc++ and AndroidX and gains nothing (licence-audit.md §7).
    for required in ("Qwen3", "llama.cpp", "YaRN", "ggllm.cpp", "Unicode"):
        out(required in names, f"licences cover {required}")
    for android_only in ("libc++", "AndroidX", "graphics-path"):
        if android_only in names:
            note(f"licences list '{android_only}', which an iOS bundle does not ship "
                 f"(licence-audit.md §7) — listing it is not a violation, but it is untrue")
    notice = os.path.join(lic_dir, "NOTICE.txt")
    repo_notice = os.path.join(root, "NOTICE")
    if os.path.isfile(notice) and os.path.isfile(repo_notice):
        shipped, canonical = open(notice).read(), open(repo_notice).read()
        if shipped == canonical:
            print("PASS  shipped NOTICE.txt is byte-identical to the repo NOTICE")
        else:
            # An iOS NOTICE may legitimately be a *subset* of the root one: Kotlin, ThreeTen-BP,
            # AndroidX and libc++ are not in this binary (licence-audit.md §7). It may never be a
            # superset or drop a notice for code that IS here.
            required = ["Unsloth", "Jeffrey Quesnelle and Bowen Peng", "cmp-nct", "Unicode License v3",
                        "The ggml authors"]
            missing = [r for r in required if r not in shipped]
            out(not missing, f"shipped NOTICE.txt covers everything in the iOS binary (missing: {missing})")
            note("shipped NOTICE.txt differs from the repo NOTICE. A per-platform NOTICE is the right "
                 "answer (D-040) but it must be generated from one source, not edited twice.")
    else:
        out(False, "NOTICE.txt is not in the bundle's licences directory")

    # The iOS analogue of licence-audit.md L10: every shipped binary artifact maps to an entry.
    artifacts = []
    for dirpath, dirnames, filenames in os.walk(app):
        for f in filenames:
            if f.endswith((".metallib", ".dylib")) or f.endswith(".framework"):
                artifacts.append(os.path.relpath(os.path.join(dirpath, f), app))
    rules = [(re.compile(r"libswift.*\.dylib$"), None),       # Swift Runtime Library Exception: no attribution
             (re.compile(r"\.metallib$"), "llama.cpp"),        # ggml Metal shaders, same MIT licence
             (re.compile(r"libc\+\+.*\.dylib$"), "libc++")]
    for a in artifacts:
        base = os.path.basename(a)
        rule = next((r for r in rules if r[0].search(base)), None)
        if rule is None:
            out(False, f"{a} ships in the bundle and no licence rule covers it — decide which entry "
                       f"it belongs to and add it here and to index.txt")
        elif rule[1] is None:
            note(f"{a} is an embedded Swift runtime library. No attribution is required (Swift's "
                 f"Runtime Library Exception waives Apache-2.0 4(a), 4(b) and 4(d)), but its presence "
                 f"means the deployment target is below iOS 12.2 or backward deployment is on.")
        else:
            out(any(rule[1] in e[0] for e in entries), f"{a} maps to licence entry '{rule[1]}'")
    if not artifacts:
        print("PASS  no dylibs, frameworks or metallibs in the bundle (everything is statically linked)")

# ---- 7. Versions and the device floor ---------------------------------------------------------
short = str(info.get("CFBundleShortVersionString", ""))
build = str(info.get("CFBundleVersion", ""))
out(bool(re.fullmatch(r"\d+\.\d+(\.\d+)?", short)), f"CFBundleShortVersionString '{short}' is a marketing version")
out(bool(re.fullmatch(r"\d+(\.\d+){0,2}", build)), f"CFBundleVersion '{build}' is a build number")
bid = str(info.get("CFBundleIdentifier", ""))
out(bool(re.fullmatch(r"[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)+", bid)), f"CFBundleIdentifier '{bid}' is well formed")
try:
    android_id = [l.split("=", 1)[1].strip() for l in open(os.path.join(root, "android/gradle.properties"))
                  if l.startswith("arivu.applicationId=")][0]
    if bid != android_id:
        note(f"bundle id '{bid}' differs from the Android applicationId '{android_id}'. Independent "
             f"per-platform ids are fine (MULTIPLATFORM.md), but D-001 chose one identity — record it.")
    else:
        print("PASS  bundle id matches the Android applicationId (D-001)")
except Exception:
    note("could not read arivu.applicationId from android/gradle.properties")

floor = info.get("MinimumOSVersion", "")
def ver(s):
    try: return tuple(int(x) for x in str(s).split("."))
    except Exception: return ()
out(bool(floor), f"MinimumOSVersion is set ('{floor}') — it is the only device gate the App Store offers (§12)")
if floor:
    out(ver(floor) >= ver(min_ios), f"MinimumOSVersion {floor} >= {min_ios} (set ARIVU_MIN_IOS to change)")
out(info.get("UIRequiresFullScreen", True) is not None, "Info.plist parsed")

# ---- 8. No placeholder report address ---------------------------------------------------------
placeholders = set()
pat = re.compile(rb"[A-Za-z0-9._%+-]+@(?:example\.(?:com|org|net|invalid)|invalid|test|localhost)\b")
for dirpath, _, filenames in os.walk(app):
    for f in filenames:
        p = os.path.join(dirpath, f)
        if os.path.getsize(p) > 64 * 1024 * 1024:   # don't scan the model
            continue
        try:
            with open(p, "rb") as fh: data = fh.read()
        except Exception:
            continue
        placeholders.update(m.decode() for m in pat.findall(data))
out(not placeholders, f"no placeholder report address in the bundle: {sorted(placeholders) or '(none)'} (D-010)")

sys.exit(1 if bad else 0)
PYEOF

# Extra confidence where Xcode's tools happen to be installed.
if command -v codesign >/dev/null 2>&1; then
  if codesign -dv "$APP" >/dev/null 2>&1; then pass "bundle is signed (codesign)"; else bad "bundle is not signed"; fi
else
  note "codesign not available — signature not checked"
fi
if command -v otool >/dev/null 2>&1 && [[ -f "$EXEC" ]]; then
  libs="$(otool -L "$EXEC" 2>/dev/null | grep -Ei 'CFNetwork|/Network\.framework|SystemConfiguration' || true)"
  [[ -z "$libs" ]] && pass "otool -L: no networking dylib" || bad "otool -L finds a networking dylib: $libs"
else
  note "otool not available — dylib list read from the binary's strings instead"
fi

# 9. Traceability
if "$PY" "$ROOT/tools/trace.py" --strict; then pass "tools/trace.py --strict"; else bad "tools/trace.py --strict"; fi

echo
echo "App Store Connect-only items are NOT checked here: leaves/compliance/appstore-policy-checklist.md"
[[ $fail == 0 ]] && echo "IOS RELEASE CHECK: PASSED" || echo "IOS RELEASE CHECK: FAILED"
exit $fail
