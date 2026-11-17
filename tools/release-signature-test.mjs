// Cross-module calls in a release build are declared with the callee's own signature
// (docs/design/separate-compilation.md, "Cross-module calls are declared with the callee's own
// signature"). LLVM, and ThinLTO with it, never inlines a call whose declared type differs from the
// definition, so a mismatch is a silent loss of every inline across that call. This builds a few
// std-heavy programs with `grail build --release` (one LLVM module per Grail module) and compares
// every declaration of a function with the definition another module gives it: the return type and
// the parameter list must agree.
//   bun tools/release-signature-test.mjs
import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, readFileSync, rmSync, copyFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildCompiler, root } from './native.mjs';

const compiler = buildCompiler();
const work = join(root, '.work/release-signature-test');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const programs = ['hashmap', 'json', 'strings', 'iterchain', 'bintrees'];
// `define [linkage] RET @"NAME"(PARAMS)` and `declare RET @"NAME"(PARAMS)`: the type, without
// parameter names or attributes.
const shape = (ret, params) => `${ret.trim()} (${params.split(',').map(p => p.trim().split(/\s+/)[0]).filter(Boolean).join(', ')})`;
let failures = 0;
let checked = 0;
for (const name of programs) {
  const dir = join(work, name);
  mkdirSync(dir, { recursive: true });
  copyFileSync(join(root, 'bench', `${name}.grl`), join(dir, 'main.grl'));
  const env = { ...process.env, GRAIL_HOME: root, GRAIL_CACHE_DIR: join(work, 'store') };
  const built = spawnSync(compiler, ['build', 'main.grl', '-o', 'prog', '--release', '--module-root', join(root, 'lib')], { cwd: dir, env, encoding: 'utf8' });
  if (built.status !== 0) throw new Error(`${name}: the release build failed: ${built.stdout}${built.stderr}`);
  const modules = join(dir, 'prog.modules');
  const defined = new Map();
  const declared = [];
  for (const file of readdirSync(modules).filter(f => f.endsWith('.s.ll'))) {
    const text = readFileSync(join(modules, file), 'utf8');
    for (const m of text.matchAll(/^define (?!internal|private)(?:\S+ )*?(\{[^}]*\}|[\w<> ]+?) @"([^"]+)"\(([^)]*)\)/gm)) defined.set(m[2], { file, type: shape(m[1], m[3]) });
    for (const m of text.matchAll(/^declare (\{[^}]*\}|[\w<> ]+?) @"([^"]+)"\(([^)]*)\)/gm)) declared.push({ file, name: m[2], type: shape(m[1], m[3]) });
  }
  for (const d of declared) {
    const def = defined.get(d.name);
    if (!def || def.file === d.file) continue;
    checked += 1;
    if (def.type !== d.type) {
      failures += 1;
      console.error(`${name}: ${d.file} declares @${d.name} as ${d.type}, ${def.file} defines it as ${def.type}`);
    }
  }
}
if (failures !== 0) {
  console.error(`release-signature: ${failures} cross-module declarations disagree with their definitions`);
  process.exit(1);
}
console.log(`release-signature: ${checked} cross-module declarations in ${programs.length} programs agree with their definitions`);
rmSync(work, { recursive: true, force: true });
