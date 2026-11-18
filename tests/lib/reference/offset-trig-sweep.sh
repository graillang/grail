#!/bin/bash
# Proves the offset fixtures are insensitive to one-ulp differences in std::sin/cos/acos/atan2.
#   1. build the reference corpus generator normally;
#   2. build a second copy whose clipper.offset.cpp calls nextafter-perturbed trig;
#   3. run both over the same SEED/COUNT random InflatePaths cases and require identical output;
#   4. run the Grail test binary over that corpus and require 0 failures.
# Usage: bash tests/lib/reference/offset-trig-sweep.sh [SEED] [COUNT] [GRAIL_TEST_BINARY]
set -euo pipefail
AB=${ABUNDANCE_ROOT:-/home/shulgin/abundance}
REF="$(cd "$(dirname "$0")" && pwd)"
SEED=${1:-20261118}
COUNT=${2:-600}
GRL=${3:-/tmp/clipper2_test}
CXX=${CXX:-c++}
FLAGS=(-O2 -std=c++20 -ffp-contract=off
  -I "$AB/ThirdParty/earcut/include" -I "$AB/ThirdParty/clipper2/include"
  -I "$AB/engine" -I "$AB/Source/AbundanceWorldGen/Public" -I "$AB/Source/AbundanceWorldGen/Private")
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
nice -n 19 $CXX "${FLAGS[@]}" "$REF/clipper2_corpus.cpp" \
  "$AB/Source/AbundanceWorldGen/Private/water_geometry.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.engine.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.offset.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.rectclip.cpp" -o "$W/normal"
# Perturbed copy: every std::sin/cos/acos/atan2 in the offset engine moved one ulp upward.
python3 - "$AB/ThirdParty/clipper2/src/clipper.offset.cpp" "$W/offset_pert.cpp" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
for fn in ('sin', 'cos', 'acos', 'atan2'):
    s = s.replace('std::' + fn + '(', 'pert_' + fn + '(')
pre = '#include <cmath>\n#include <cstdio>\n'
for fn, args, call in (('sin', 'double x', 'std::sin(x)'), ('cos', 'double x', 'std::cos(x)'),
                       ('acos', 'double x', 'std::acos(x)'),
                       ('atan2', 'double y, double x', 'std::atan2(y, x)')):
    pre += f'static inline double pert_{fn}({args}){{ double v = {call}; return std::nextafter(v, 4.0); }}\n'
open(dst, 'w').write(pre + s)
PY
nice -n 19 $CXX "${FLAGS[@]}" "$REF/clipper2_corpus.cpp" \
  "$AB/Source/AbundanceWorldGen/Private/water_geometry.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.engine.cpp" "$W/offset_pert.cpp" \
  "$AB/ThirdParty/clipper2/src/clipper.rectclip.cpp" -o "$W/pert"
mkdir -p "$W/a" "$W/b"
"$W/normal" --sweep "$SEED" "$COUNT" "$W/a"
"$W/pert"   --sweep "$SEED" "$COUNT" "$W/b"
if ! diff -r "$W/a" "$W/b" > /dev/null; then
  echo "FAIL: one-ulp trig perturbation changed the reference output:"
  diff -r "$W/a" "$W/b" | head -20
  exit 1
fi
echo "perturbation: $COUNT cases identical under a one-ulp trig perturbation"
"$GRL" "$W/a"
