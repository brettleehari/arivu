#!/usr/bin/env bash
# Downloads the shipped model and verifies it. The sha256 is the model's identity:
# changing it is a Spine-level decision (see leaves/decisions.yml D-001 area "Model").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf"
SHA="ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a"
OUT="$ROOT/models/Qwen3-0.6B-Q4_K_M.gguf"
mkdir -p "$ROOT/models"
[[ -f "$OUT" ]] || curl -fL --progress-bar -o "$OUT" "$URL"
echo "$SHA  $OUT" | shasum -a 256 -c
