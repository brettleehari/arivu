#!/usr/bin/env bash
# Downloads the shipped model and verifies it. The sha256 is the model's identity:
# changing it is a Spine-level decision (see leaves/decisions.yml D-001 area "Model").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf"
SHA="b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897"
OUT="$ROOT/models/Qwen3-1.7B-Q4_K_M.gguf"
mkdir -p "$ROOT/models"
[[ -f "$OUT" ]] || curl -fL --progress-bar -o "$OUT" "$URL"
echo "$SHA  $OUT" | shasum -a 256 -c
