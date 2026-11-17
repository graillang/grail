#!/usr/bin/env bash
# Land a branch on main: one landing at a time, through the fast gate, with no hand merge.
#
#   bash tools/land.sh BRANCH            land origin/BRANCH
#   bash tools/land.sh --status          the queue and the last landings
#
# The branch must already contain origin/main: merge main into it and resolve conflicts on the
# branch, where the owner knows both sides. The gate then runs on exactly the branch's tree, and
# green means main fast-forwards to it. Nothing is rebased or re-merged here.
#
# The gate: build, the self-host fixed point, the x86_64 corpus in three shards, and the tool
# suites. A corpus case or suite that fails is retried once on its own (load can time one out);
# one that fails twice blocks the landing unless tools/land-known.txt names it (an owner and a
# reason on every line; the file only ever shrinks). The emulated aarch64/riscv64 legs run after
# the landing on the build host (GRAIL_LAND_REMOTE) and do not hold the queue: a failure there is
# fixed forward by the branch's owner.
set -uo pipefail
# The queue checks branches out in its own worktree, which may be where this script lives: run from a
# copy, so the checkout cannot change the script under the running shell.
if [ -z "${LAND_HERE:-}" ]; then
  export LAND_HERE=$(cd "$(dirname "$0")/.." && pwd)
  copy=$(mktemp /tmp/land.XXXXXX.sh); cp "$0" "$copy"; exec bash "$copy" "$@"
fi
here=$LAND_HERE
queue=${GRAIL_LAND_DIR:-$HOME/grail-landq}
logs=${GRAIL_LAND_LOGS:-$HOME/grail-land-logs}
remote=${GRAIL_LAND_REMOTE:-}
mkdir -p "$logs"
if [ "${1:-}" = "--status" ]; then
  if flock -n "$queue.lock" true 2>/dev/null; then echo "queue: free"; else echo "queue: busy ($(cat "$queue.lock.who" 2>/dev/null))"; fi
  tail -n 15 "$logs/landings.txt" 2>/dev/null
  exit 0
fi
br=${1:?usage: tools/land.sh BRANCH | --status}
exec 9>"$queue.lock"
if ! flock -n 9; then echo "land: queue busy ($(cat "$queue.lock.who" 2>/dev/null)); waiting"; flock 9; fi
echo "$br since $(date -u +%H:%M)" > "$queue.lock.who"
stamp=$(date -u +%Y%m%d-%H%M%S)
out="$logs/$stamp-${br//\//_}"
mkdir -p "$out"
note() { echo "land: $*" | tee -a "$out/summary.txt"; }
record() { echo "$(date -u +%FT%TZ) $br $(git -C "$queue" rev-parse --short HEAD 2>/dev/null) $*" >> "$logs/landings.txt"; }

[ -e "$queue/.git" ] || git -C "$here" worktree add -q --detach "$queue" origin/main
cd "$queue" || exit 1
git fetch -q origin || { note "fetch failed"; exit 1; }
git checkout -q -f --detach "origin/$br" 2>/dev/null || { note "no branch origin/$br"; exit 1; }
git clean -qfd
if git merge-base --is-ancestor HEAD origin/main; then note "$br is already on main"; exit 0; fi
if ! git merge-base --is-ancestor origin/main HEAD; then
  note "REFUSED: origin/$br does not contain origin/main ($(git rev-parse --short origin/main)). Merge origin/main into $br, resolve, push, and run this again."
  record refused-not-on-main; exit 2
fi
note "$br at $(git rev-parse --short HEAD), $(git rev-list --count origin/main..HEAD) commits over main; logs in $out"

# Build with the compiler of the last landing; fall back to the seed a fresh queue starts from.
build() { GRAIL_COMPILER=$1 bun tools/native.mjs build > "$out/build.log" 2>&1 && tail -1 "$out/build.log"; }
C=""
for base in "$queue/.work/land-base/grail" "${GRAIL_LAND_SEED:-$HOME/grail-view/.work/base/grail-c6}"; do
  [ -x "$base" ] || continue
  C=$(build "$base") && [ -x "$C" ] && break
  C=""
done
[ -n "$C" ] || { note "BLOCKED: the compiler does not build (see build.log)"; record blocked-build; exit 1; }
export GRAIL_COMPILER=$C GRAIL_FFI_COMPILER=$C

leg() { local n=$1; shift; ( GRAIL_CACHE_DIR=$(mktemp -d) "$@" > "$out/$n.log" 2>&1; echo "exit=$?" >> "$out/$n.log" ); }
t0=$(date +%s)
for i in 1 2 3; do leg "x86_$i" env GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs x86_64 & done
leg selfhost bun tools/test-selfhost.mjs &
wait
suites="test-cli interface-test cache-test split-test test-ffi abundance-test borg-test lsp-test pkg-test"
for t in $suites; do leg "$t" bun "tools/$t.mjs" & done
leg book bun tools/book.mjs check &
leg lint bun tools/ci.mjs lint &
wait

known() {
  [ -f tools/land-known.txt ] || return 0
  grep -v '^#' tools/land-known.txt | cut -d'#' -f1 | sed 's/[[:space:]]*$//' | grep -v '^$' |
    while IFS= read -r k; do case "$1" in *"$k"*) echo yes; break;; esac; done
}
failed=0
# Corpus cases: retry the failures once, alone.
cases=$(cat "$out"/x86_*.log | sed -n 's/^FAIL \([^ ]*\).*/\1/p' | sort -u)
if [ -n "$cases" ]; then
  filter="^($(echo $cases | tr ' ' '|'))\$"
  leg x86_retry env GRAIL_TEST_FILTER="$filter" bun tools/test-native.mjs x86_64
  for c in $cases; do
    if grep -q "^FAIL $c\b" "$out/x86_retry.log"; then
      if [ -n "$(known "$c")" ]; then note "known failure: $c"; else note "FAIL (twice): $c"; failed=1; fi
    else note "flake (passed alone): $c"; fi
  done
fi
for i in 1 2 3; do
  grep -q '^exit=0$' "$out/x86_$i.log" || grep -q '^FAIL ' "$out/x86_$i.log" || { note "FAIL: x86 shard $i ended without a verdict"; failed=1; }
done
# Suites: retry a failing one once, alone; a still-failing suite is known only if every FAIL line is.
for n in selfhost $suites book lint; do
  grep -q '^exit=0$' "$out/$n.log" && continue
  case $n in selfhost) cmd="bun tools/test-selfhost.mjs";; book) cmd="bun tools/book.mjs check";; lint) cmd="bun tools/ci.mjs lint";; *) cmd="bun tools/$n.mjs";; esac
  leg "$n.retry" $cmd
  if grep -q '^exit=0$' "$out/$n.retry.log"; then note "flake (passed alone): $n"; continue; fi
  lines=$(grep -E '^(FAIL|error)' "$out/$n.retry.log" | head -20)
  unknown=""
  if [ -z "$lines" ]; then unknown="no FAIL line: $(grep -v '^exit=' "$out/$n.retry.log" | tail -1)"; else
    while IFS= read -r l; do [ -n "$(known "$l")" ] || unknown="$l"; done <<< "$lines"
  fi
  if [ -n "$unknown" ]; then note "FAIL: $n: ${unknown:0:200}"; failed=1; else note "known failure in $n"; fi
done
mins=$(( ($(date +%s) - t0) / 60 ))
if [ $failed != 0 ]; then note "BLOCKED after ${mins} min; main unchanged"; record blocked; exit 1; fi

git push -q origin HEAD:main 2>"$out/push.log" || { note "push refused (main moved outside the queue?): $(tail -1 "$out/push.log")"; record push-refused; exit 1; }
mkdir -p .work/land-base && cp "$C" .work/land-base/grail.new && mv .work/land-base/grail.new .work/land-base/grail
note "LANDED $br at $(git rev-parse --short HEAD) after ${mins} min"
record "landed ${mins}min"

# Emulated legs on the build host, after the landing.
if [ -n "$remote" ]; then
  if ( git push -q "$remote:/srv/grail/repo.git" HEAD:refs/heads/main &&
       rsync -az "$C" "$remote:/srv/grail/grail-main" &&
       ssh -o BatchMode=yes "$remote" "cd /srv/grail/w && git fetch -q origin && git checkout -q -f origin/main && mkdir -p /srv/grail/logs/$stamp && for t in aarch64 riscv64; do for i in 1 2 3; do GRAIL_LEG_COMPILER=/srv/grail/grail-main nohup setsid /srv/grail/run-leg.sh $stamp/\${t}_\$i env GRAIL_TEST_SHARD=\$i/3 bun tools/test-native.mjs \$t --jobs 2 >/dev/null 2>&1 & done; done" ) > "$out/remote.log" 2>&1
  then note "emulated legs started on $remote (/srv/grail/logs/$stamp)"; else note "could not start the emulated legs (remote.log)"; fi
fi
exit 0
