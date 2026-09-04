#!/usr/bin/env bash
# Print the signer of each signed profile in dist/ and confirm the chain ends
# at Apple Root CA. Useful for a quick look before publishing.
set -euo pipefail
DST="${1:-dist}"
for f in "$DST"/*.mobileconfig; do
  echo "== $(basename "$f")"
  openssl pkcs7 -inform der -in "$f" -print_certs -noout 2>/dev/null | grep -E '^(subject|issuer)=' | sed 's/^/   /'
done
