#!/usr/bin/env python3
"""Compliance Leaf generator: Spine commitment → feature → test.

Scans code, config and tests for `spine: C<n>` tags (a tag line may list several: `spine: C1, C7`).
Writes leaves/compliance/TRACEABILITY.md.

Since Spine 0.2 the repo is a monorepo (leaves/MULTIPLATFORM.md): `/core` is the shared,
platform-free engine, `/android` and `/ios` are the two platform layers, `/tools` is shared
verification. Every reference is therefore also attributed to a platform, and the matrix reports
per-commitment platform coverage — because "implemented" and "implemented on both platforms" are
different claims, and C11 is the commitment that turns on the difference.

Exit codes:
  1  a tag names a commitment the Spine does not have (always fatal)
  2  --strict and a commitment has no tagged implementation or no tagged test (release gate)

Also reports, without failing, source files that carry no tag at all — under `android/**/src/main`,
under `/core` and under `/ios` sources: each is either plumbing that should name the commitment it
serves, or scope creep.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "leaves/compliance/TRACEABILITY.md"
SKIP = {"build", ".build", ".gradle", ".cxx", "third_party", "models", "leaves", ".git", ".kotlin",
        "bin", "DerivedData", "Pods", ".swiftpm", "xcuserdata"}
EXTS = {".kt", ".kts", ".cpp", ".h", ".xml", ".sh", ".py", ".swift", ".plist", ".entitlements",
        ".xcprivacy", ".modulemap"}
TAG = re.compile(r"spine:\s*((?:C\d+)(?:\s*,\s*C\d+)*)")
# A reference counts as a *test/verification* if it lives in one of these. `/core/tests/` and the
# iOS `Tests/` conventions were added in 0.2; without them a core unit test reads as an
# implementation and a commitment can look verified when nothing checks it.
TEST_MARKERS = ("/src/test/", "/src/androidTest/", "/tests/", "/Tests/",
                "tools/host/", "tools/check_", "tools/zip_entry", "tools/verify_", "tools/bench",
                "tools/release_check", "tools/ios_release_check")
SELF = {"tools/trace.py"}
# Not product source: build/packaging descriptions that happen to use a source extension.
NOT_MAIN = {"Package.swift"}
PLATFORMS = ("core", "android", "ios")
strict = "--strict" in sys.argv[1:]

spine = (ROOT / "leaves/SPINE.md").read_text()
version = re.search(r"spine_version:\s*([\d.]+)", spine).group(1)
commitments = dict(re.findall(r"^\| \*\*(C\d+)\*\* \| (.+?) \|$", spine, re.M))


def is_test(p: pathlib.Path) -> bool:
    s = "/" + p.as_posix()
    return any(k in s for k in TEST_MARKERS)


def platform_of(p: pathlib.Path) -> str:
    """Which tree a reference lives in. `tools` and anything else is shared/cross-platform."""
    top = p.parts[0]
    return top if top in PLATFORMS else "shared"


def is_main_source(p: pathlib.Path) -> bool:
    """Product source that ships, per tree — the set the untagged-file report is about."""
    s = p.as_posix()
    if is_test(p) or p.name in NOT_MAIN:
        return False
    if s.startswith("android/") and "/src/main/" in s:
        return p.suffix in {".kt", ".cpp", ".h"}
    if s.startswith("core/"):
        return p.suffix in {".cpp", ".h"}
    if s.startswith("ios/"):
        return p.suffix == ".swift"
    return False


features = {c: [] for c in commitments}
tests = {c: [] for c in commitments}
# commitment -> platform -> {"impl", "test"}
coverage = {c: {plat: set() for plat in (*PLATFORMS, "shared")} for c in commitments}
unknown, untagged_main = [], []
for p in sorted(ROOT.rglob("*")):
    rel = p.relative_to(ROOT)
    if p.is_dir() or p.suffix not in EXTS or SKIP & set(rel.parts) or rel.as_posix() in SELF:
        continue
    tagged = False
    kind = "test" if is_test(rel) else "impl"
    plat = platform_of(rel)
    for n, line in enumerate(p.read_text(errors="ignore").splitlines(), 1):
        for m in TAG.finditer(line):
            tagged = True
            for cid in re.findall(r"C\d+", m.group(1)):
                ref = f"`{rel.as_posix()}:{n}`"
                if cid not in commitments:
                    unknown.append(f"{ref} → {cid}")
                    continue
                (tests if kind == "test" else features)[cid].append(ref)
                coverage[cid][plat].add(kind)
    if not tagged and is_main_source(rel):
        untagged_main.append(f"`{rel.as_posix()}`")

CELL = {frozenset(): "—", frozenset({"impl"}): "impl", frozenset({"test"}): "test",
        frozenset({"impl", "test"}): "impl + test"}

rows, plat_rows, gaps = [], [], []
for cid, text in commitments.items():
    f, t = sorted(set(features[cid])), sorted(set(tests[cid]))
    if not f:
        gaps.append(f"**{cid}** has no tagged implementation")
    if not t:
        gaps.append(f"**{cid}** has no tagged test or verification")
    rows.append(f"| **{cid}** | {text} | {'<br>'.join(f) or '**GAP**'} | {'<br>'.join(t) or '**GAP**'} |")
    cells = [CELL[frozenset(coverage[cid][plat])] for plat in (*PLATFORMS, "shared")]
    plat_rows.append(f"| **{cid}** | " + " | ".join(cells) + " |")

# Commitments the second platform has not reached yet. Informational, never a gap: MULTIPLATFORM.md
# says "Never hold an Android fix for App Store review", so an iOS hole must not fail the Android gate.
missing_ios = [c for c in commitments if not coverage[c]["ios"]]
ios_todo = ([
    "**Not yet carried by `/ios`:** " + ", ".join(f"`{c}`" for c in missing_ios) +
    ". Informational — an iOS hole never fails `--strict`, because the Android release must not wait "
    "for App Store review (leaves/MULTIPLATFORM.md). Tracked in `appstore-policy-checklist.md` and "
    "`licence-audit.md` §7.6.",
    "",
] if missing_ios else ["**`/ios` carries every commitment.**", ""])

# C11 is the one commitment whose subject *is* the platform split: "one product, two platforms,
# capability chosen by the device". A C11 tag that exists only inside one platform tree would prove
# the opposite of the commitment, so the shared core must carry it.
if "C11" in commitments and "impl" not in coverage["C11"]["core"]:
    gaps.append("**C11** is not implemented in `/core` — a commitment about platform-independence "
                "cannot be anchored only in a platform tree")
# C11's iOS side is deliberately NOT a --strict gap: it would hold the Android release hostage to
# the iOS port. It shows up in the informational list above, and `tools/ios_release_check.sh` is the
# gate that stops an iOS build shipping without it.

md = [
    "<!-- generated by tools/trace.py — do not edit; re-run after any Spine or code change -->",
    "# Compliance Leaf — traceability matrix",
    "",
    f"spine_version: {version}",
    "",
    "Store-policy status per commitment lives in `play-policy-checklist.md` (Google Play) and",
    "`appstore-policy-checklist.md` (Apple App Store); licence obligations in `licence-audit.md`.",
    "A tagged test proves the *mechanism* exists, not that a store will accept it — read the checklists for C9.",
    "",
    "| Commitment | Spine text | Implemented in | Verified by |",
    "|---|---|---|---|",
    *rows,
    "",
    "## Platform coverage",
    "",
    "Where each commitment is tagged. `core` is the shared, platform-free engine; `shared` is",
    "`/tools` and other cross-platform verification. A commitment carried only by one platform tree",
    "is a one-platform commitment, whatever the Spine says (leaves/MULTIPLATFORM.md).",
    "",
    "| Commitment | core | android | ios | shared |",
    "|---|---|---|---|---|",
    *plat_rows,
    "",
    *ios_todo,
    "## Gaps",
    "",
    *([f"- {g}" for g in gaps] or ["None."]),
    "",
    "## Tags naming commitments the Spine does not have",
    "",
    *([f"- {u}" for u in unknown] or ["None."]),
    "",
    "## Untagged sources (possible scope creep, or missing tag)",
    "",
    "Not a failure. Scanned: `android/**/src/main` (.kt/.cpp/.h), `/core` (.cpp/.h), `/ios` (.swift).",
    "Each should either carry the `spine: C<n>` of the commitment it serves, or be questioned.",
    "",
    *([f"- {u}" for u in untagged_main] or ["None."]),
    "",
]
OUT.write_text("\n".join(md))
print(f"{len(commitments)} commitments, {len(gaps)} gaps, {len(unknown)} unknown tags, "
      f"{len(untagged_main)} untagged sources → {OUT.relative_to(ROOT)}")
if unknown:
    sys.exit(1)
if strict and gaps:
    sys.exit(2)
