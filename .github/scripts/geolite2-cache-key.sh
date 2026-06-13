#!/usr/bin/env bash
# Derive the Actions cache key for a GeoLite2-City Last-Modified date.
set -euo pipefail

DATE="${1:?GeoLite2 last-modified date required}"
HASH=$(printf '%s' "$DATE" | sha256sum | cut -d' ' -f1 | head -c 16)
echo "geolite2-${HASH}"
