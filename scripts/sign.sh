#!/usr/bin/env bash
# Sign every profile in profiles/ into dist/ with a Developer ID identity from
# the keychain, then prove the signed file decodes back to the exact input.
#
#   SIGNING_IDENTITY="Developer ID Application: ... (TEAMID)" scripts/sign.sh
#
# Defaults to the GET Technology Developer ID. Works on any Mac (local or CI)
# whose keychain holds the identity and its private key.
set -euo pipefail

IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: GET TECHNOLOGY INC. (FAW8H2KWX2)}"
SRC="${1:-profiles}"
DST="${2:-dist}"

mkdir -p "$DST"

if ! security find-identity -v -p codesigning | grep -Fq "$IDENTITY"; then
  echo "error: identity not found in keychain: $IDENTITY" >&2
  exit 1
fi

count=0
for src in "$SRC"/*.mobileconfig; do
  name="$(basename "$src")"
  out="$DST/$name"

  plutil -lint -s "$src"
  security cms -S -N "$IDENTITY" -i "$src" -o "$out"

  # The decoded payload must be byte-identical to what we signed.
  if ! security cms -D -i "$out" | cmp -s - "$src"; then
    echo "error: $out does not decode back to $src" >&2
    exit 1
  fi
  # Signature must verify against the embedded chain (LibreSSL/OpenSSL both fine).
  openssl smime -verify -inform der -in "$out" -noverify -out /dev/null 2>/dev/null

  echo "signed     $out"
  count=$((count + 1))
done

echo "$count profiles signed with: $IDENTITY"
