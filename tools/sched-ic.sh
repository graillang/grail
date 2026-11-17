#!/bin/bash
# Instructions per scheduler operation (callgrind, one worker): Grail against rayon and oneTBB, on
# counters the machine's load cannot move. Per-op = (count at 2N - count at N) / N.
#   tools/sched-ic.sh GRAIL_COMPILER [RAYON_BIN]
# RAYON_BIN is bench/ic/rayon.rs built as the main of a crate depending on rayon (the rivals' crate).
set -e
root=$(cd "$(dirname "$0")/.." && pwd); G=$1; R=$2
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
ic(){ GRAIL_WORKERS=1 RAYON_NUM_THREADS=1 valgrind --tool=callgrind --callgrind-out-file=/dev/null "$@" 2>&1 | awk '/I   refs/{gsub(",","",$4); print $4}'; }
g++ -O2 "$root/bench/ic/tbb.cpp" -o "$w/tbb" -ltbb; gcc -O2 "$root/bench/ic/fib.c" -o "$w/cfib"
names=(join spawn fib)
for m in 0 1 2; do
  a=20000; [ $m = 2 ] && a=200; b=$((a*2))
  for n in $a $b; do sed "s/MODE/$m/; s/COUNT/$n/" "$root/bench/ic/grail.grl" > "$w/p.grl"; "$G" build "$w/p.grl" -o "$w/g_$n" --no-cache >/dev/null; done
  line="${names[$m]}: grail $(( ($(ic "$w/g_$b") - $(ic "$w/g_$a")) / a ))"
  line="$line tbb $(( ($(ic "$w/tbb" ${names[$m]} $b) - $(ic "$w/tbb" ${names[$m]} $a)) / a ))"
  [ -n "$R" ] && line="$line rayon $(( ($(ic "$R" ${names[$m]} $b) - $(ic "$R" ${names[$m]} $a)) / a ))"
  echo "$line"
done
echo "serial fib(20) in C: $(( ($(ic "$w/cfib" 400) - $(ic "$w/cfib" 200)) / 200 ))"
