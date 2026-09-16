#!/usr/bin/env bash
# Copies the shipped GGUF into the app bundle. Run as an Xcode build phase (ios/project.yml).
#
# The model is NOT in the repository: models/ is gitignored and fetched by tools/fetch_model.sh,
# which verifies its sha256 (the sha is the model's identity; changing it is a Spine-level decision).
# So this phase fails loudly on a fresh clone rather than producing an app that opens into a chat and
# then cannot answer — which is exactly the failure C1 exists to prevent.
#
# The bundle-size consequence, written here because this is where it is created:
#   the .ipa is ~400 MB. iOS allows a 4 GB app, so size is not a blocker, but 200 MB is the cellular
#   download threshold: above it the user must be on Wi-Fi or approve a large download explicitly.
#   The listing carries the same "install on Wi-Fi" line the Play listing does. On-Demand Resources
#   would move the download out of the install, and is refused: it would break "one tap and it
#   works" (C1) by turning the first message into a download.
#
# spine: C1
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/../.." && pwd)/ios}/.."
ROOT="$(cd "$ROOT" && pwd)"
SOURCE="${ARIVU_MODEL:-$ROOT/models/Qwen3-0.6B-Q4_K_M.gguf}"
DEST_DIR="${BUILT_PRODUCTS_DIR:-$ROOT/build/ios/bundle}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}"
DEST="$DEST_DIR/qwen3-0.6b-q4_k_m.gguf"

if [[ ! -f "$SOURCE" ]]; then
  echo "error: $SOURCE is missing. Run tools/fetch_model.sh (about 400 MB, sha256-verified)." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
# Clone rather than copy where the filesystem allows it: APFS makes this free and instant, which
# matters when it is 400 MB on every incremental build.
if cp -c "$SOURCE" "$DEST" 2>/dev/null; then
  :
else
  cp "$SOURCE" "$DEST"
fi

# The GGUF must be readable at its natural offset, which on a directory-shaped bundle it always is.
# No alignment dance, no `.so` suffix: D-013 is Android-only complexity that does not exist here.
echo "model: $(du -h "$DEST" | cut -f1) -> ${DEST#"$ROOT"/}"
