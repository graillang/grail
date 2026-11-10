#!/usr/bin/env python3
"""Resolve merge conflicts that recur in this repo.

Case lists under tests/ are merged structurally by case `name` (both sides append, keeping both
textually produces invalid JSON; a branch's entry WINS over main's, because it is newer). Prose
(any .md) keeps both sides. A source conflict is refused: it needs a human decision.

Usage: tools/merge-cases.py [FILE...]   (default: every unmerged file)
"""
import json, os, re, subprocess, sys

MARK = r'<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n'

def unmerged():
    return subprocess.check_output(['git','diff','--name-only','--diff-filter=U']).decode().split()

def load(rev, path):
    raw = json.loads(subprocess.check_output(['git','show',f'{rev}:{path}']).decode())
    return raw, (raw if isinstance(raw, list) else raw['cases'])

def union(path):
    head, ours = load('HEAD', path)          # HEAD = our side after previous resolutions
    _, theirs = load('MERGE_HEAD', path)     # MERGE_HEAD = the branch being merged (newer)
    order, byname, extra = [], {}, []
    for c in ours:
        if isinstance(c, dict) and 'name' in c:
            byname[c['name']] = c; order.append(c['name'])
        else:
            order.append(None); extra.append(c)
    for c in theirs:
        if isinstance(c, dict) and 'name' in c:
            if c['name'] not in byname: order.append(c['name'])
            byname[c['name']] = c            # branch wins on collision
        else:
            order.append(None); extra.append(c)
    merged, ei = [], 0
    for k in order:
        if k is None:
            merged.append(extra[ei]); ei += 1
        else:
            merged.append(byname[k])
    out = merged if isinstance(head, list) else {**head, 'cases': merged}
    open(path,'w').write(json.dumps(out, indent=2) + '\n')
    back = json.load(open(path))
    n = len(back if isinstance(back, list) else back['cases'])
    print(f'{path}: {len(ours)} ours + {len(theirs)} theirs -> {n}')

def both(path):
    t = re.sub(MARK, lambda m: m.group(1) + m.group(2), open(path).read(), flags=re.S)
    assert '<<<<<<<' not in t, path
    open(path,'w').write(t); print(f'{path}: kept both')

paths = sys.argv[1:] or unmerged()
if not paths:
    print('no unmerged files'); sys.exit(0)
for p in paths:
    if p.endswith('.json'): union(p)
    elif p.endswith('.md'): both(p)
    else: sys.exit(f'{p}: refusing a source conflict — needs a human decision')
