#!/usr/bin/env python3
"""Grail landing service: one daemon lands queued branches on main through the fast gate.

Requests are files in requests/ (written by land.sh). The daemon takes up to TRAIN of the oldest,
merges each onto current origin/main in the queue worktree (a clean merge, or one whose only
conflicts are corpus cases and prose, which tools/merge-cases.mjs settles), gates the combined tree
once, and on green fast-forwards main and each branch. A branch that does not merge is refused with
its conflicting files. A red train is retried one branch at a time, so one bad branch cannot block
the others. Results go to results/<branch>.txt and ../grail-land-logs/landings.txt.
"""
import os, shlex, sys, time, subprocess, fcntl, shutil, re, glob, tempfile, json

SVC = os.path.dirname(os.path.abspath(__file__))
REQ = os.path.join(SVC, 'requests'); RES = os.path.join(SVC, 'results')
Q = os.environ.get('GRAIL_LAND_DIR', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tree'))
LOGS = os.environ.get('GRAIL_LAND_LOGS', '/home/shulgin/grail-land-logs')
LOCK = os.path.join(SVC, 'lock')
REMOTE = os.environ.get('GRAIL_LAND_REMOTE', 'root@borg.ml')
SEED = os.environ.get('GRAIL_LAND_SEED', '/home/shulgin/grail-view/.work/base/grail-c6')
TRAIN = int(os.environ.get('GRAIL_LAND_TRAIN', '8'))
# The owner's rule (2026-11-17): land, then fix forward. Before landing only the build and the self-host
# fixed point run (a compiler that cannot build itself blocks every fix); the full suites run after
# the landing, on main, in post mode (`landd.py --post`), and failures go to their branch's owner.
FAST = os.environ.get('GRAIL_LAND_FULL', '') == ''
SUITES = ['test-cli', 'interface-test', 'cache-test', 'split-test', 'test-ffi', 'abundance-test', 'borg-test', 'lsp-test']

def sh(cmd, cwd=Q, env=None, check=False, capture=True):
    r = subprocess.run(cmd, cwd=cwd, env=env, shell=isinstance(cmd, str), text=True,
                       stdout=subprocess.PIPE if capture else None, stderr=subprocess.STDOUT if capture else None)
    if check and r.returncode != 0:
        raise RuntimeError(f'{cmd}: {r.stdout}')
    return r

def git(*a, check=False): return sh(['git', *a], check=check)

def now(): return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())

def result(br, verdict, detail=''):
    line = f'{now()} {verdict} {detail}'.rstrip()
    with open(os.path.join(RES, br.replace('/', '_') + '.txt'), 'a') as f: f.write(line + '\n')
    with open(os.path.join(LOGS, 'landings.txt'), 'a') as f: f.write(f'{now()} {br} {verdict} {detail}'.rstrip() + '\n')
    print(f'[{now()}] {br}: {verdict} {detail}', flush=True)

def requests():
    out = []
    for name in sorted(os.listdir(REQ)):
        p = os.path.join(REQ, name)
        try: br = open(p).read().split('\n')[0].strip()
        except FileNotFoundError: continue
        if br: out.append((name, br, name.endswith('.solo')))
    return out

def drop(name):
    try: os.remove(os.path.join(REQ, name))
    except FileNotFoundError: pass

def known_lines(tree):
    p = os.path.join(tree, 'tools/land-known.txt')
    if not os.path.exists(p): return []
    ks = []
    for l in open(p):
        l = l.split('#')[0].strip()
        if l and not l.startswith('#'): ks.append(l)
    return ks

def merge_branch(br):
    """Merge origin/br into the current HEAD (which contains main). Returns None or a refusal text."""
    if git('rev-parse', '--verify', '-q', f'origin/{br}').returncode != 0:
        return f'no branch origin/{br}'
    r = git('merge', '--no-edit', '-q', f'origin/{br}')
    if r.returncode == 0: return None
    u = git('diff', '--name-only', '--diff-filter=U').stdout.split()
    hard = [f for f in u if not (re.match(r'tests/.*\.json$', f) or f.endswith('.md'))]
    if not hard:
        m = sh('bun tools/merge-cases.mjs')
        if m.returncode == 0 and not git('diff', '--name-only', '--diff-filter=U').stdout.strip():
            if git('-c', 'core.editor=true', 'commit', '-q', '--no-edit').returncode == 0: return None
        hard = u
    git('merge', '--abort')
    return 'merge conflict with main or with the branches ahead of it in: ' + ' '.join(hard)

def gate_fast(out):
    """Build and check the self-host fixed point. Returns (ok, notes, compiler)."""
    base = os.path.join(Q, '.work/land-base/grail')
    C = None
    for b in (base, SEED):
        if not os.path.exists(b): continue
        r = sh(f'GRAIL_COMPILER={b} bun tools/native.mjs build > {out}/build.log 2>&1 && tail -1 {out}/build.log')
        c = r.stdout.strip().split('\n')[-1] if r.returncode == 0 else ''
        if c and os.path.exists(c): C = c; break
    if not C: return False, ['FAIL: the compiler does not build (build.log)'], None
    r = sh(f'GRAIL_COMPILER={base if os.path.exists(base) else SEED} bun tools/test-selfhost.mjs > {out}/selfhost.log 2>&1')
    if r.returncode != 0:
        tail = [l.strip() for l in open(f'{out}/selfhost.log') if l.strip()][-1:]
        return False, ['FAIL: self-host: ' + (tail[0] if tail else '')], C
    return True, ['self-host fixed point holds'], C

def gate(out, stamp):
    """Build and run the fast gate on the worktree's tree. Returns (ok, notes, compiler)."""
    notes = []
    base = os.path.join(Q, '.work/land-base/grail')
    C = None
    for b in (base, SEED):
        if not os.path.exists(b): continue
        r = sh(f'GRAIL_COMPILER={b} bun tools/native.mjs build > {out}/build.log 2>&1 && tail -1 {out}/build.log')
        c = r.stdout.strip().split('\n')[-1] if r.returncode == 0 else ''
        if c and os.path.exists(c): C = c; break
    if not C: return False, ['the compiler does not build (build.log)'], None
    env = dict(os.environ, GRAIL_COMPILER=C, GRAIL_FFI_COMPILER=C)
    def start(name, cmd):
        d = tempfile.mkdtemp(prefix='landcache-')
        e = dict(env, GRAIL_CACHE_DIR=d)
        f = open(f'{out}/{name}.log', 'w')
        return name, subprocess.Popen(cmd, cwd=Q, env=e, stdout=f, stderr=subprocess.STDOUT, shell=True), f
    # The suites come from the tree being gated (tools/landsvc/suites.txt: one `name command...` per
    # line), so a branch that adds a suite lands its fix and its gate leg together.
    suites = []
    sp = os.path.join(Q, 'tools/landsvc/suites.txt')
    if os.path.exists(sp):
        for l in open(sp):
            l = l.split('#')[0].strip()
            if l: n, _, c = l.partition(' '); suites.append((n, c.strip() or f'bun tools/{n}.mjs'))
    else:
        suites = [(t, f'bun tools/{t}.mjs') for t in SUITES] + [('book', 'bun tools/book.mjs check'), ('lint', 'bun tools/ci.mjs lint')]
    legs = [start(f'x86_{i}', f'GRAIL_TEST_SHARD={i}/3 bun tools/test-native.mjs x86_64') for i in (1, 2, 3)]
    legs.append(start('selfhost', 'bun tools/test-selfhost.mjs'))
    # The suites run alongside the corpus: agents' processes are at nice 10 while a landing runs.
    for n, c in suites: legs.append(start(n, c))
    codes = {}
    for name, p, f in legs:
        codes[name] = p.wait(); f.write(f'exit={codes[name]}\n'); f.close()
    ks = known_lines(Q)
    def known(s): return any(k in s for k in ks)
    ok = True
    fails = set()
    for i in (1, 2, 3):
        txt = open(f'{out}/x86_{i}.log').read()
        fails |= set(re.findall(r'^FAIL (\S+)', txt, re.M))
        if codes[f'x86_{i}'] != 0 and not re.search(r'^FAIL ', txt, re.M):
            notes.append(f'FAIL: x86 shard {i} ended without a verdict'); ok = False
    if fails:
        flt = '^(' + '|'.join(re.escape(c) for c in sorted(fails)) + ')$'
        r = sh(f'GRAIL_CACHE_DIR=$(mktemp -d) GRAIL_TEST_FILTER=\'{flt}\' bun tools/test-native.mjs x86_64 > {out}/x86_retry.log 2>&1', env=env)
        txt = open(f'{out}/x86_retry.log').read()
        for c in sorted(fails):
            if re.search(rf'^FAIL {re.escape(c)}\b', txt, re.M):
                if known(c): notes.append(f'known failure: {c}')
                else: notes.append(f'FAIL (twice): {c}'); ok = False
            else: notes.append(f'flake (passed alone): {c}')
    retry_cmd = dict(suites); retry_cmd['selfhost'] = 'bun tools/test-selfhost.mjs'
    for n in ['selfhost'] + [n for n, _ in suites]:
        if codes[n] == 0: continue
        cmd = retry_cmd[n]
        r = sh(f'GRAIL_CACHE_DIR=$(mktemp -d) {cmd} > {out}/{n}.retry.log 2>&1', env=env)
        if r.returncode == 0: notes.append(f'flake (passed alone): {n}'); continue
        lines = [l for l in open(f'{out}/{n}.retry.log') if re.match(r'^(FAIL|error)', l)][:20]
        unknown = [l.strip() for l in lines if not known(l)]
        if not lines:
            tail = [l.strip() for l in open(f'{out}/{n}.retry.log') if l.strip()][-1:]
            unknown = ['no FAIL line: ' + (tail[0] if tail else '')]
        if unknown: notes.append(f'FAIL: {n}: {unknown[0][:200]}'); ok = False
        else: notes.append(f'known failure in {n}')
    return ok, notes, C

def remote_legs(C, stamp):
    if not REMOTE: return 'no remote'
    # One batch at a time: a newer main supersedes the emulated legs still running for an older one
    # (every landing starting its own batch put 13 batches on the 8-core box at once).
    # Each batch's legs share the launcher's session: stop every session that runs a dated leg
    # (agents' own legs, named <agent>/<leg>, are left alone). Emulated legs compile with one job each,
    # since forked optimiser workers per leg put hundreds of processes on the 8-core box.
    stop_old = ("for s in $(ps -eo sid=,args= | awk '/run-leg[.]sh 20[0-9]+-[0-9]+[/]/ {print $1}' | sort -u); "
                "do pkill -TERM -s $s; done; sleep 3; export GRAIL_JOBS=1; ")
    script = (stop_old + 'cd /srv/grail/w && git fetch -q origin && git checkout -q -f origin/main && '
              f'if [ -f tools/land-remote.sh ]; then bash tools/land-remote.sh {stamp}; else mkdir -p /srv/grail/logs/{stamp} && '
              f'for t in aarch64 riscv64; do for i in 1 2 3; do GRAIL_LEG_COMPILER=/srv/grail/grail-main nohup setsid /srv/grail/run-leg.sh {stamp}/${{t}}_$i env GRAIL_TEST_SHARD=$i/3 bun tools/test-native.mjs $t --jobs 2 >/dev/null 2>&1 & done; done; fi')
    r = sh(f'git push -q {REMOTE}:/srv/grail/repo.git HEAD:refs/heads/main && rsync -az {C} {REMOTE}:/srv/grail/grail-main && ssh -o BatchMode=yes {REMOTE} {shlex.quote(script)}')
    return 'emulated legs started' if r.returncode == 0 else 'could not start the emulated legs: ' + r.stdout[-200:]

def run_once():
    reqs = requests()
    if not reqs: return False
    solo = [r for r in reqs if r[2]]
    batch = solo[:1] if solo else reqs[:TRAIN]
    with open(LOCK, 'w') as lk:
        fcntl.flock(lk, fcntl.LOCK_EX)
        with open(LOCK + '.who', 'w') as w: w.write(' '.join(b for _, b, _ in batch) + ' since ' + now())
        git('fetch', '-q', 'origin')
        git('checkout', '-q', '-f', '--detach', 'origin/main'); sh('git clean -qfd')
        main = git('rev-parse', '--short', 'HEAD').stdout.strip()
        included = []
        for name, br, _ in batch:
            if git('rev-parse', '--verify', '-q', f'origin/{br}').returncode == 0 and \
               git('merge-base', '--is-ancestor', f'origin/{br}', 'origin/main').returncode == 0:
                result(br, 'already-on-main'); drop(name); continue
            why = merge_branch(br)
            if why: result(br, 'REFUSED', why); drop(name); continue
            included.append((name, br))
        if not included: return True
        stamp = time.strftime('%Y%m%d-%H%M%S', time.gmtime())
        tag = '+'.join(b for _, b in included)
        out = os.path.join(LOGS, f'{stamp}-{tag.replace("/", "_")[:120]}'); os.makedirs(out, exist_ok=True)
        head = git('rev-parse', '--short', 'HEAD').stdout.strip()
        t0 = time.time()
        with open(f'{out}/summary.txt', 'w') as s: s.write(f'land: {tag} merged onto main {main} as {head}; logs in {out}\n')
        ok, notes, C = gate_fast(out) if FAST else gate(out, stamp)
        mins = int((time.time() - t0) / 60)
        with open(f'{out}/summary.txt', 'a') as s:
            for n in notes: s.write('land: ' + n + '\n')
        if ok:
            r = git('push', '-q', 'origin', 'HEAD:main')
            if r.returncode != 0:
                for name, br in included: result(br, 'retry', 'main moved during the gate')
                return True
            os.makedirs(os.path.join(Q, '.work/land-base'), exist_ok=True)
            shutil.copy(C, os.path.join(Q, '.work/land-base/grail.new')); os.replace(os.path.join(Q, '.work/land-base/grail.new'), os.path.join(Q, '.work/land-base/grail'))
            for name, br in included:
                git('push', '-q', 'origin', f'HEAD:refs/heads/{br}')  # fast-forward the branch when its owner has not moved it
                result(br, 'LANDED', f'main={head} after {mins} min ({out})'); drop(name)
            rl = 'emulated legs: run by the post-landing verifier'
            with open(f'{out}/summary.txt', 'a') as s: s.write(f'land: LANDED {tag} at {head} after {mins} min; {rl}\n')
        else:
            first = '; '.join(n for n in notes if n.startswith('FAIL'))[:400]
            if len(included) > 1:
                for name, br in included:
                    os.rename(os.path.join(REQ, name), os.path.join(REQ, name + '.solo')) if not name.endswith('.solo') else None
                    result(br, 'train-red', f'retrying alone: {first}')
            else:
                name, br = included[0]
                result(br, 'BLOCKED', f'after {mins} min: {first} ({out})'); drop(name)
        return True

def post_loop():
    """Verify main after landings: the full gate on each new origin/main, results in post.txt."""
    last = ''
    lf = os.path.join(LOGS, 'post.txt')
    while True:
        try:
            git('fetch', '-q', 'origin')
            head = git('rev-parse', '--short', 'origin/main').stdout.strip()
            if head and head != last:
                git('checkout', '-q', '-f', '--detach', 'origin/main'); sh('git clean -qfd')
                stamp = time.strftime('%Y%m%d-%H%M%S', time.gmtime())
                out = os.path.join(LOGS, f'post-{stamp}-{head}'); os.makedirs(out, exist_ok=True)
                t0 = time.time()
                ok, notes, C = gate(out, stamp)
                if C:
                    rl = remote_legs(C, stamp)
                    notes.append(rl)
                mins = int((time.time() - t0) / 60)
                with open(f'{out}/summary.txt', 'w') as s:
                    for n in notes: s.write(n + '\n')
                    s.write(('GREEN' if ok else 'RED') + f' main {head} after {mins} min\n')
                fails = '; '.join(n for n in notes if n.startswith('FAIL'))[:600]
                with open(lf, 'a') as f: f.write(f'{now()} main {head} {"GREEN" if ok else "RED"} {mins}min {fails} ({out})\n')
                if ok and C:
                    os.makedirs(os.path.join(Q, '.work/land-base'), exist_ok=True)
                    shutil.copy(C, os.path.join(Q, '.work/land-base/grail'))
                last = head
            else:
                time.sleep(60)
        except Exception as e:
            print(f'[{now()}] post error: {e}', flush=True); time.sleep(60)

def main():
    if '--post' in sys.argv: return post_loop()
    print(f'[{now()}] landd started', flush=True)
    while True:
        try:
            if not run_once(): time.sleep(15)
        except Exception as e:
            print(f'[{now()}] error: {e}', flush=True); time.sleep(30)

if __name__ == '__main__': main()
