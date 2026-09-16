#!/usr/bin/env bash
# Builds ios/App/Resources/licenses/ from the shared licence texts.
#
# spine: C4 — every shipped component, including the model weights, with its licence readable in the
# app and with no network. The TEXTS are shared with Android (they are the same licences); the INDEX
# is not, because the two apps link different things: no Kotlin, no Compose, no AndroidX and no
# Android libc++ here, and the Swift runtime and swift-testing instead.
#
# Re-run this after changing a dependency. It is a copy, not a symlink, because an app bundle cannot
# contain one.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/android/app/src/main/assets/licenses"
DEST="$ROOT/ios/App/Resources/licenses"

[[ -d "$SRC" ]] || { echo "shared licence texts not found at $SRC" >&2; exit 1; }
mkdir -p "$DEST"

# The licence bodies that apply to both platforms.
for f in Apache-2.0.txt llama.cpp-MIT.txt llama.cpp-embedded-MIT.txt qwen3-Apache-2.0.txt Unicode-3.0.txt; do
  [[ -f "$SRC/$f" ]] && cp "$SRC/$f" "$DEST/$f"
done

# NOTICE is NOT copied: Android's names Kotlin, Compose, AndroidX and the `.gguf.so` packaging name,
# none of which exist here. The shared paragraphs below are kept word for word so the two files can
# be diffed. REQUEST (leaves/engineering-ios.md): move the licence texts and one NOTICE generator to
# a shared /licenses directory, so this divergence stops being maintained by hand.
cat > "$DEST/NOTICE.txt" <<'NOTICE'
Arivu
Copyright 2026 The Arivu authors
Licensed under the Apache License, Version 2.0.

This product bundles the Qwen3-0.6B model weights, Copyright 2024 Alibaba Cloud, Apache License 2.0,
as the Q4_K_M GGUF quantization published by Unsloth (huggingface.co/unsloth/Qwen3-0.6B-GGUF), named
qwen3-0.6b-q4_k_m.gguf in the app bundle and otherwise unmodified by Arivu.

This product includes llama.cpp and ggml, Copyright (c) 2023-2026 The ggml authors, MIT License, with
modifications by Arivu (tools/llama/patches). They contain:
  - YaRN RoPE scaling, Copyright (c) 2023 Jeffrey Quesnelle and Bowen Peng, MIT License
  - code adapted from ggllm.cpp (github.com/cmp-nct/ggllm.cpp), Copyright (c) 2023 https://github.com/cmp-nct,
    MIT License
  - tables derived from the Unicode Character Database, Copyright Unicode, Inc., Unicode License v3

This product includes the Swift standard library and Foundation (Apple Inc. and the Swift project
authors) and the LLVM libc++ runtime (LLVM Project), licensed under the Apache License 2.0 with the
Runtime Library Exception.

Arivu on iPhone links no other third-party code. There is no analytics, advertising, tracking,
crash-reporting or networking library in it.
NOTICE

# The iOS index. Order matters: "Notices (read first)" is always first (leaves/design.md §8).
cat > "$DEST/index.txt" <<'INDEX'
Notices (read first)|NOTICE|NOTICE.txt
Arivu|Apache-2.0|Apache-2.0.txt
Qwen3 0.6B model weights (Alibaba Cloud, Qwen team); Q4_K_M quantization by Unsloth|Apache-2.0|qwen3-Apache-2.0.txt
llama.cpp and ggml (The ggml authors), with Arivu's fd-loading patch|MIT|llama.cpp-MIT.txt
YaRN RoPE scaling in ggml (Jeffrey Quesnelle and Bowen Peng)|MIT|llama.cpp-embedded-MIT.txt
BPE tokenizer code in llama.cpp adapted from ggllm.cpp (cmp-nct)|MIT|llama.cpp-embedded-MIT.txt
Unicode Character Database tables in llama.cpp (Unicode, Inc.)|Unicode-3.0|Unicode-3.0.txt
Swift standard library and Foundation (Apple and the Swift project authors)|Apache-2.0 WITH LLVM-exception|swift-Apache-2.0.txt
LLVM libc++ runtime (LLVM Project)|Apache-2.0 WITH LLVM-exception|swift-Apache-2.0.txt
INDEX

# The Swift runtime licence: Apache-2.0 with the Runtime Library Exception. Its text is the Apache
# licence plus the exception, so it gets its own file rather than sharing Android's Apache-2.0.txt.
if [[ ! -f "$DEST/swift-Apache-2.0.txt" ]]; then
  {
    cat <<'HEADER'
The Swift standard library, Foundation and the LLVM libc++ runtime are licensed under
Apache License v2.0 with Runtime Library Exception.

---- Runtime Library Exception to the Apache 2.0 License ----

As an exception, if you use this Software to compile your source code and
portions of this Software are embedded into the binary product as a result,
you may redistribute such product without providing attribution as would
otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.

The full Apache License v2.0 text follows.

HEADER
    cat "$SRC/Apache-2.0.txt"
  } > "$DEST/swift-Apache-2.0.txt"
fi

echo "wrote $(ls "$DEST" | wc -l | tr -d ' ') files to ${DEST#"$ROOT"/}"
echo
echo "CHECK BEFORE RELEASE: this index is hand-maintained. If a dependency is added, add its licence"
echo "here too — C4 is 'licences visible in-app', not 'most licences visible in-app'."
