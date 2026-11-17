// Unboxed stage 3a (docs/design/unboxed-values.md): every program given is built with and without
// --frame-records and must print the same and exit 0 both ways. Removed with the switch.
//   bun tools/frame-records-test.mjs COMPILER FILE.grl...
import { compileProgram } from './native.mjs';
import { spawnSync } from 'node:child_process';
const compiler = process.argv[2];
const roots = ['--module-root', process.cwd() + '/lib'];
for (const file of process.argv.slice(3)) {
  const name = file.replace(/.*\//, '').replace(/\.grl$/, '');
  const out = [];
  for (const [tag, extra] of [['off', [...roots]], ['on', ['--frame-records', ...roots]]]) {
    try {
      const exe = compileProgram(compiler, [file], `.work/ub/fr/${name}-${tag}`, { name, extra, overflow: 'wrap' });
      const r = spawnSync(exe, [], { encoding: 'utf8', timeout: 20000 });
      out.push({ tag, status: r.status, signal: r.signal, stdout: r.stdout });
    } catch (e) { out.push({ tag, status: 'compile', stdout: String(e.message).split('\n').slice(0, 4).join(' | ') }); }
  }
  const same = out[0].stdout === out[1].stdout && out[1].status === 0;
  console.log(`${same ? 'SAME' : 'DIFF'} ${name} off=${out[0].status} on=${out[1].status}${out[1].signal ? ' ' + out[1].signal : ''}${same ? '' : '\n  on: ' + String(out[1].stdout).slice(0, 300)}`);
}
