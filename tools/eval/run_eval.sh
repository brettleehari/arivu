#!/usr/bin/env bash
# W04 — run the writing and comprehension eval on the host and grade it.
#
#   tools/eval/run_eval.sh                       # all cases, the seeds in cases.yml
#   SEEDS=1,2,3,4,5 tools/eval/run_eval.sh       # more seeds for a final D-017 call
#   tools/eval/run_eval.sh --sheet               # also write the human scoring sheet
#
# Host-only, on purpose. Same GGUF, same core/src/engine.cpp, same shipped sampling and the same
# system prompt (extracted from Policy.kt, never copied), so the QUALITY answer is valid here. The
# speed numbers are a desktop's and must never be quoted — W02 on the physical phone is the only
# source for those (leaves/BRIEF.md "Test device").
#
# This is the piece of W04 that needs no phone, no Mac with Xcode and no store account.
#
# spine: C5, C7 — decides D-017, feeds D-026 and D-032.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build/host}"
OUT="${OUT_DIR:-$ROOT/build/eval}"
CMAKE="${CMAKE:-$(command -v cmake || echo "$HOME/Library/Android/sdk/cmake/4.1.2/bin/cmake")}"
MODEL="${MODEL:-$ROOT/models/Qwen3-0.6B-Q4_K_M.gguf}"
CASES="${CASES:-$ROOT/tools/eval/cases.yml}"

# Pick an interpreter that is (a) the right architecture and (b) has PyYAML. Not the shebang: the
# first python3 on PATH here was an x86_64 3.8 that dies with "Bad CPU type in executable" on Apple
# silicon. tools/bench.sh, release_check.sh and ios_release_check.sh all hardcode /usr/bin/python3
# for the same reason; this keeps that convention and says so when it cannot be met.
PY_BIN="${PYTHON:-}"
if [[ -z "$PY_BIN" ]]; then
  for candidate in /usr/bin/python3 python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import yaml' >/dev/null 2>&1; then
      PY_BIN="$candidate"; break
    fi
  done
fi
[[ -n "$PY_BIN" ]] || { echo "no python3 with PyYAML found (tried /usr/bin/python3, python3). Set PYTHON=/path/to/python3" >&2; exit 1; }

WANT_SHEET=0
[[ "${1:-}" == "--sheet" ]] && WANT_SHEET=1

[[ -f "$MODEL" ]] || { echo "no model at $MODEL — run tools/fetch_model.sh (about 400 MB, sha256-verified)" >&2; exit 1; }

EXTRA=()
if [[ "$(uname)" == "Darwin" ]]; then
  # Same workaround as tools/host/run_smoke.sh: some Command Line Tools installs ship an
  # incomplete libc++ header dir, and `xcrun --show-sdk-path` points at exactly that one. Pin the
  # newest versioned SDK instead, which has the headers.
  SDK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX1*.sdk | sort -V | tail -1)"
  EXTRA=(-DCMAKE_OSX_SYSROOT="$SDK" "-DCMAKE_CXX_FLAGS=-nostdinc++ -isystem $SDK/usr/include/c++/v1" -DGGML_METAL=OFF -DGGML_BLAS=OFF)
fi

mkdir -p "$OUT"
export PATH="$(dirname "$CMAKE"):$PATH"
"$CMAKE" -S "$ROOT/tools/host" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release "${EXTRA[@]}" >/dev/null
"$CMAKE" --build "$BUILD" --target arivu_eval -j 8

# The dataset is YAML for humans; the runner reads a length-prefixed record file. This step is also
# what extracts the shipped system prompt out of Policy.kt, so there is no second copy of it.
PREPARED="$OUT/cases.bin"
SEEDS_FROM_FILE="$("$PY_BIN" "$ROOT/tools/eval/prepare_cases.py" "$CASES" "$PREPARED" | sed -n 's/^seeds: //p')"
SEEDS="${SEEDS:-$SEEDS_FROM_FILE}"

STAMP="$(date +%Y%m%d-%H%M%S)"
ROWS="$OUT/rows-$STAMP.jsonl"
"$BUILD/arivu_eval" "$MODEL" "$PREPARED" "$SEEDS" "$ROWS"

GRADE=("$PY_BIN" "$ROOT/tools/eval/grade.py" "$ROWS" --cases "$CASES")
[[ $WANT_SHEET == 1 ]] && GRADE+=(--sheet "$OUT/sheet-$STAMP.md")
"${GRADE[@]}"

echo "  rows:  $ROWS"
[[ $WANT_SHEET == 1 ]] && echo "  sheet: $OUT/sheet-$STAMP.md"
echo
echo "  D-017 is decided on the human column. Score the sheet, save it as CSV (case,seed,score),"
echo "  then re-run:  $PY_BIN tools/eval/grade.py $ROWS --scores <that.csv>"
