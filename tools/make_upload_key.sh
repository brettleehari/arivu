#!/usr/bin/env bash
# spine: C1 — creates Arivu's Play UPLOAD key. Run it yourself, once, on the release machine.
# Never run by an agent or CI. The key is written OUTSIDE the repository and never committed.
#
#   tools/make_upload_key.sh [path/to/arivu-upload.p12]      default: ~/.arivu-keys/arivu-upload.p12
#
# What it does (leaves/architecture/release-and-signing.md §3):
#   RSA-4096, PKCS12, alias arivu-upload, validity 10000 days; prompts for the passphrase (not echoed,
#   not stored in shell history); prints the SHA-256 certificate fingerprint and the Gradle lines to add to
#   ~/.gradle/gradle.properties. This is the upload key, not the app signing key (Play App Signing, D-018).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$HOME/.arivu-keys/arivu-upload.p12}"
ALIAS=arivu-upload
KEYTOOL="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"
command -v "$KEYTOOL" >/dev/null || { echo "keytool not found; set JAVA_HOME" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
case "$OUT" in
  "$ROOT"/*) echo "refusing: $OUT is inside the repository ($ROOT). Choose a path outside it." >&2; exit 1 ;;
esac
[[ -e "$OUT" ]] && { echo "refusing: $OUT already exists. An upload key is created once; back it up instead." >&2; exit 1; }

read -r -p "Name to put in the certificate (CN), e.g. your name or 'Arivu': " CN
[[ -n "$CN" ]] || { echo "CN is required" >&2; exit 1; }
read -r -s -p "Passphrase (min 12 characters; store it in your password manager first): " PW; echo
read -r -s -p "Repeat passphrase: " PW2; echo
[[ "$PW" == "$PW2" ]] || { echo "passphrases differ" >&2; exit 1; }
[[ ${#PW} -ge 12 ]] || { echo "passphrase too short" >&2; exit 1; }

umask 077
# Passphrase goes through the environment, not argv (argv is visible in `ps`).
ARIVU_KS_PW="$PW" "$KEYTOOL" -genkeypair -v \
  -keystore "$OUT" -storetype PKCS12 -storepass:env ARIVU_KS_PW \
  -alias "$ALIAS" -keyalg RSA -keysize 4096 -sigalg SHA256withRSA -validity 10000 \
  -dname "CN=$CN"
chmod 600 "$OUT"
FP="$(ARIVU_KS_PW="$PW" "$KEYTOOL" -list -v -keystore "$OUT" -storetype PKCS12 -storepass:env ARIVU_KS_PW -alias "$ALIAS" \
      | awk -F': ' '/SHA256:/{print $2; exit}')"
unset PW PW2

cat <<MSG

Upload key created: $OUT
Certificate SHA-256: $FP
  -> record this fingerprint in leaves/architecture/release-and-signing.md (it is the UPLOAD key's,
     not the app signing key's; users compare against the app signing cert from Play Console).

Add to ~/.gradle/gradle.properties (outside the repo; chmod 600 that file):
  arivu.upload.storeFile=$OUT
  arivu.upload.storePassword=<the passphrase>
  arivu.upload.keyAlias=$ALIAS
Or export ARIVU_UPLOAD_STORE_FILE / ARIVU_UPLOAD_STORE_PASSWORD for one shell session only.

BACK IT UP NOW:
  1. Two encrypted copies (e.g. encrypted USB drive + encrypted archive) kept in two different places.
  2. The passphrase in your password manager, never next to the file.
  3. Never email it, never put it in the repo, a cloud-synced repo folder, or CI.
  If this key is lost or leaks, request an upload-key reset in Play Console (App integrity); users are
  not affected because Play holds the app signing key.
MSG
