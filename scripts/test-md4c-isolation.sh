#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_CPP="$REPO_ROOT/packages/core/cpp"
RN_IOS="$REPO_ROOT/packages/react-native-enriched-markdown/ios"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
CC="${CC:-cc}"
CXX="${CXX:-c++}"

# Compile a second complete copy with the original name, as another library
# would embed it. The header guard keeps md4c.c from restoring Enriched's alias.
cat > "$TEST_DIR/foreign-md4c.c" <<'EOF'
#include "md4c.h"
#undef md_parse
#include "md4c.c"
EOF

"$CC" -std=c99 -c "$CORE_CPP/md4c/md4c.c" -o "$TEST_DIR/enriched-md4c.o"
"$CC" -std=c99 -I "$CORE_CPP/md4c" -c "$TEST_DIR/foreign-md4c.c" -o "$TEST_DIR/foreign-md4c.o"
"$CXX" -std=c++17 -I "$CORE_CPP" \
  "$REPO_ROOT/scripts/tests/md4c-isolation.cpp" "$CORE_CPP/parser/MD4CParser.cpp" \
  "$TEST_DIR/enriched-md4c.o" "$TEST_DIR/foreign-md4c.o" -o "$TEST_DIR/coexistence"
"$TEST_DIR/coexistence"
echo "Two embedded MD4C copies link and parse successfully."

# Compile the bridges' actual C++ includes without requiring UIKit or React.
# Conflicting basenames model another pod's headers winning the search order.
mkdir -p "$TEST_DIR/conflicting" "$TEST_DIR/ios/parser" "$TEST_DIR/ios/input"
for header in md4c.h MD4CParser.hpp MarkdownASTNode.hpp; do
  echo '#error Resolved a foreign parser header' > "$TEST_DIR/conflicting/$header"
done
for source in parser/MarkdownParserBridge.mm input/ENRMInputParser.mm; do
  awk '/^#include/ { print }' "$RN_IOS/$source" > "$TEST_DIR/ios/${source%.mm}.cpp"
done

for layout in symlink copy; do
  if [[ "$layout" == symlink ]]; then
    ln -s "$CORE_CPP" "$TEST_DIR/cpp"
  else
    rm "$TEST_DIR/cpp"
    mkdir -p "$TEST_DIR/cpp"
    cp -R "$CORE_CPP/md4c" "$CORE_CPP/parser" "$TEST_DIR/cpp/"
  fi
  for source in parser/MarkdownParserBridge input/ENRMInputParser; do
    "$CXX" -std=c++17 -fsyntax-only \
      -I "$TEST_DIR/conflicting" -I "$TEST_DIR/cpp/md4c" -I "$TEST_DIR/cpp/parser" \
      "$TEST_DIR/ios/$source.cpp"
  done
  echo "Bridge C++ includes resolve Enriched's own headers with the $layout layout."
done
