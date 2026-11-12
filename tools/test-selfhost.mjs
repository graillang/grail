// Self-hosting fixpoint: the compiler built from the bootstrap seed (stage 1) compiles the compiler
// sources into stage 2, stage 2 compiles them again, and the two outputs must be byte-identical.
// A change that the seed accepts but the new compiler rejects (or miscompiles) in its own source
// fails here instead of at the next bootstrap update.
import { mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { assemble, buildCompiler, command, compilerSources, root } from './native.mjs';

const stage1 = buildCompiler();
const work = join(root, '.work/selfhost');
mkdirSync(work, { recursive: true });
const stage2Assembly = join(work, 'stage2.s');
command([stage1, stage2Assembly, ...compilerSources]);
const stage2 = assemble(stage2Assembly, join(work, 'stage2'));
const stage3Assembly = join(work, 'stage3.s');
command([stage2, stage3Assembly, ...compilerSources]);
const a = readFileSync(stage2Assembly);
const b = readFileSync(stage3Assembly);
if (!a.equals(b)) {
  console.error(`selfhost: stage 2 and stage 3 differ (${a.length} vs ${b.length} bytes)`);
  process.exit(1);
}
console.log(`selfhost: stage 2 and stage 3 identical (${a.length} bytes)`);
