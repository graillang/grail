#!/usr/bin/env bash
# Resume the gate in a worktree, or start it, without ever killing a live one.
#
# Why this exists: two agents each hand-rolled "kill any old gate, start a new one" after a host
# reset, ran within seconds of each other, and the second pkill killed the gate the first had just
# started. The machine spent a minute with no gate at all. Restarting the gate is a host-wide
# action, so it is one command, and it is safe to run when a gate is already going.
#
# Usage: tools/gate-resume.sh WORKTREE [LOG_DIR]
#
# What it does, and why each step is needed after a reset:
#   - refuses to start a second gate on this host (a gate is one per host, not per worktree);
#   - removes a killed leg's *.tmp, so the leg is re-run rather than inherited as a stale result;
#   - removes .work/native, because a reset leaves the cached compiler as a stale inode that
#     fails with ENOEXEC;
#   - leaves every *.log saying exit=0 alone: those legs are still evidence for this tree, and
#     gate.sh skips them, which is what lets a long gate accumulate across several short boots.
set -uo pipefail

dir=${1:?usage: gate-resume.sh WORKTREE [LOG_DIR]}
logs=${2:-$dir/.work/gate}

cd "$dir" || exit 1

# Identifying a running gate by substring is not safe: a monitor loop or a `bash -c` one-liner that
# merely *mentions* tools/gate.sh (for example `for i in ...; do if [ -f .work/gate/summary.txt ]`)
# matches `pgrep -f 'bash tools/gate.sh'` and this script then refuses to start a gate that is not
# running. Ask each process's argv instead: a real gate has an argument that *is* tools/gate.sh, not
# an argument that contains the words.
gate_pids() {
    for proc in /proc/[0-9]*; do
        [ -r "$proc/cmdline" ] || continue
        pid=${proc#/proc/}
        [ "$pid" = "$$" ] && continue
        while IFS= read -r -d '' arg; do
            case "$arg" in
                tools/gate.sh|*/tools/gate.sh) echo "$pid"; break ;;
            esac
        done < "$proc/cmdline" 2>/dev/null
    done
}
running=$(gate_pids | wc -l)
if [ "${running:-0}" -ge 1 ]; then
    echo "a gate is already running on this host (${running} process); not starting another"
    for pid in $(gate_pids | head -3); do echo "  pid $pid: $(tr '\0' ' ' < /proc/$pid/cmdline)"; done
    exit 0
fi

mkdir -p "$logs"
rm -f "$logs"/*.tmp
rm -rf .work/native

green=$(grep -l 'exit=0' "$logs"/*.log 2>/dev/null | wc -l)
export PATH="$HOME/.local/qemu-static/usr/bin:$PATH"
GATE_JOBS=${GATE_JOBS:-1} nohup setsid bash tools/gate.sh "$logs" > "$logs/driver.log" 2>&1 &

echo "gate started in $dir at $(git log --oneline -1 2>/dev/null | cut -c1-9), ${green} green leg(s) kept"
