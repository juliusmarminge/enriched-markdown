#!/bin/bash
set -euo pipefail

REPO="mity/md4c"
BRANCH="master"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/src"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/packages/core/cpp/md4c"

FILES=(
  "md4c.c"
  "md4c.h"
)

echo "Fetching md4c sources from github.com/${REPO} (branch: ${BRANCH})..."

mkdir -p "$DEST_DIR"

for file in "${FILES[@]}"; do
  url="${BASE_URL}/${file}"
  dest="${DEST_DIR}/${file}"
  echo "  ${url} -> ${dest}"
  curl -fSL --retry 3 "$url" -o "$dest"
done

# Restore Enriched's private symbol name after replacing the upstream header.
awk '
  { print }
  /^#define MD4C_H$/ {
    print ""
    print "/* Isolate the embedded parser from other libraries linking their own MD4C. */"
    print "#define md_parse enrm_md_parse"
    isolated = 1
  }
  END { if (!isolated) exit 1 }
' "$DEST_DIR/md4c.h" > "$DEST_DIR/md4c.h.tmp"
mv "$DEST_DIR/md4c.h.tmp" "$DEST_DIR/md4c.h"

echo "Done. Files updated in ${DEST_DIR}"
