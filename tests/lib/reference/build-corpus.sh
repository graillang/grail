#!/bin/bash
# Builds and runs the geometry corpus generators against Abundance's vendored C++ sources.
#   bash tests/lib/reference/build-corpus.sh            build + generate tests/lib/{earcut,clipper2}
#   bash tests/lib/reference/build-corpus.sh --check    also require the aarch64 cross-libm check
# The Abundance checkout (/home/shulgin/abundance) is read-only input: every generator compiles the
# vendored headers and the water_geometry.cpp caller unmodified, with -ffp-contract=off as the
# engine does, and writes fixture files only under tests/lib/.
set -euo pipefail
AB=${ABUNDANCE_ROOT:-/home/shulgin/abundance}
REF="$(cd "$(dirname "$0")" && pwd)"
OUT_EARCUT="$(dirname "$REF")/earcut"
OUT_CLIPPER2="$(dirname "$REF")/clipper2"
mkdir -p "$OUT_EARCUT" "$OUT_CLIPPER2"
CXX=${CXX:-c++}
FLAGS=(-O2 -std=c++20 -ffp-contract=off
  -I "$AB/ThirdParty/earcut/include"
  -I "$AB/ThirdParty/clipper2/include"
  -I "$AB/engine"
  -I "$AB/Source/AbundanceWorldGen/Public"
  -I "$AB/Source/AbundanceWorldGen/Private")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# The vendored Clipper2 translation units the engine compiles for this module (the three
# clipper2_*_ue.cpp wrappers name exactly these).
nice -n 19 $CXX "${FLAGS[@]}" "$REF/earcut_corpus.cpp" \
  "$AB/Source/AbundanceWorldGen/Private/water_geometry.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.engine.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.offset.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.rectclip.cpp" -o "$WORK/earcut_corpus"
"$WORK/earcut_corpus" "$AB" "$OUT_EARCUT"
echo "earcut corpus: $(ls "$OUT_EARCUT" | wc -l) files"
