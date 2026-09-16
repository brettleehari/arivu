#!/usr/bin/env bash
# spine: C3 — bundletool certifies M5 (no network permission), so it is pinned by sha256 (threat-model T8).
# Downloads tools/bin/bundletool.jar if missing and verifies it every time. Prints the jar path.
# Pin verified 2026-09-15 against the GitHub release asset digest of google/bundletool 1.18.3
# (api.github.com .../releases/tags/1.18.3: bundletool-all-1.18.3.jar sha256:a099cfa1…8e29, 32,520,401 B).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=1.18.3
SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29
JAR="$ROOT/tools/bin/bundletool.jar"
if [[ ! -f "$JAR" ]]; then
  mkdir -p "$(dirname "$JAR")"
  curl -fsSL -o "$JAR.part" "https://github.com/google/bundletool/releases/download/$VERSION/bundletool-all-$VERSION.jar"
  mv "$JAR.part" "$JAR"
fi
actual="$(shasum -a 256 "$JAR" | awk '{print $1}')"
if [[ "$actual" != "$SHA256" ]]; then
  echo "bundletool sha256 mismatch: $actual (expected $SHA256) — deleting $JAR" >&2
  rm -f "$JAR"; exit 1
fi
echo "$JAR"
