// B1 stage 1 proof: `--split` emits the same program as the single-file build, one file per module.
//
// The compiler still checks, specialises and lowers the whole program (the optimizer inlines across
// modules), so "per module" is a property of the emitted stream, not of a separate compilation run.
// This tool proves the two shapes agree:
//
//  1. text:  the parts, minus each file's `.text` prologue and the `.globl` lines separate objects
//            need, concatenate to the single assembly file byte for byte;
//  2. object: the concatenated part objects have the single object's section lengths and are
//            identical everywhere except in the fields the linker relocates (addresses, not code);
//  3. image:  the linked program has the same `.rodata`/`.data`/`.bss`, the same symbols in the
//            same order (only their local/global binding differs) and the same behaviour; `.text`
//            differs only by the alignment the linker inserts between input sections;
//  4. driver: `grail build --split` produces the same program as `grail build`.
//
// Usage: bun tools/split-test.mjs [--target T] [--timing]
import { spawn, spawnSync } from 'node:child_process';
import { copyFileSync, readdirSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import assert from 'node:assert/strict';
import { buildCompiler, command, compilerSources, emulations, execute, hostTarget, linkInputs, root, runner, targetName, triples } from './native.mjs';

const flags = process.argv.slice(2);
const target = targetName(flags.includes('--target') ? flags[flags.indexOf('--target') + 1] : hostTarget);
const timing = flags.includes('--timing');
const compiler = buildCompiler();
const work = join(root, '.work/split-test', target);
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const prologue = '.text\n';

// One assembly stream for the whole program, or one file per module plus OUT.parts.
function compile(name, inputs, split) {
  const asm = join(work, `${name}${split ? '.split' : '.single'}.s`);
  const args = [compiler, '--target', target];
  // A split build carries no runtime-error call-site table, so the single reference is built without
  // one too: the proof is that splitting changes nothing else.
  if (split) args.push('--split'); else args.push('--no-error-sites');
  args.push(asm, ...inputs);
  const started = process.hrtime.bigint();
  command(args);
  return { asm, ms: Number(process.hrtime.bigint() - started) / 1e6 };
}

function manifestOf(asm) {
  const path = asm.replace(/\.s$/, '.parts');
  assert.ok(existsSync(path), `${path}: missing parts manifest`);
  const lines = readFileSync(path, 'utf8').split('\n').filter(line => line.length > 0);
  assert.equal(lines[0], '// grail-parts 1', `${path}: unexpected header`);
  const parts = lines.filter(line => !line.startsWith('//'));
  const link = lines.filter(line => line.startsWith('// grail-link: '));
  assert.ok(parts.length > 1, `${path}: expected one part per module, got ${parts.length}`);
  return { path, parts, link };
}

function assembleOne(source, object) {
  command([process.env.GRAIL_ASSEMBLER ?? 'clang', `--target=${triples[target]}`, '-c', source, '-o', object]);
}

// Assemble every part at once, the way the driver does, and return the elapsed time.
async function assembleParts(parts) {
  const started = process.hrtime.bigint();
  const objects = parts.map(part => part.replace(/\.s$/, '.o'));
  await Promise.all(objects.map((object, i) => new Promise((ok, fail) => {
    const child = spawn(process.env.GRAIL_ASSEMBLER ?? 'clang', [`--target=${triples[target]}`, '-c', parts[i], '-o', object], { stdio: 'inherit' });
    child.on('error', fail);
    child.on('exit', code => (code === 0 ? ok() : fail(new Error(`${parts[i]}: assembler exited ${code}`))));
  })));
  return { objects, ms: Number(process.hrtime.bigint() - started) / 1e6 };
}

function link(objects, executable, linkArgs = []) {
  const started = process.hrtime.bigint();
  command([process.env.GRAIL_LINKER ?? 'ld.lld', '-m', emulations[target], ...linkArgs, ...objects, '-o', executable]);
  return Number(process.hrtime.bigint() - started) / 1e6;
}

function section(path, name) {
  const dump = `${path}.${name.replace(/[^A-Za-z0-9]/g, '_')}.bin`;
  rmSync(dump, { force: true });
  const result = spawnSync('llvm-objcopy', ['--dump-section', `${name}=${dump}`, path], { encoding: 'utf8' });
  // A module that has no literals has no .rodata; an absent section is empty, not an error.
  const absent = result.status !== 0 && /not found|has no section|cannot dump/i.test(result.stderr ?? '');
  if (result.status !== 0 && !absent) throw new Error(`objcopy ${path} ${name}: ${result.stderr}`);
  const bytes = existsSync(dump) ? readFileSync(dump) : Buffer.alloc(0);
  rmSync(dump, { force: true });
  return bytes;
}

// Every byte the linker rewrites in this object's .text: an object that calls across module
// boundaries carries a relocation where a single object carries a resolved address.
function relocatedSpans(object) {
  const text = spawnSync('llvm-readelf', ['-rW', object], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }).stdout ?? '';
  const sizes = { R_X86_64_PLT32: 4, R_X86_64_PC32: 4, R_X86_64_32: 4, R_X86_64_32S: 4, R_X86_64_64: 8 };
  const spans = [];
  let inText = false;
  for (const line of text.split('\n')) {
    const section = /^Relocation section '(\S+)'/.exec(line);
    if (section) { inText = section[1] === '.rela.text'; continue; }
    if (!inText) continue;
    const row = /^([0-9a-f]{6,})\s+\S+\s+(R_\S+)/.exec(line.trim());
    if (row) spans.push([parseInt(row[1], 16), sizes[row[2]] ?? 4]);
  }
  return spans;
}

function symbols(path) {
  const text = spawnSync('llvm-nm', ['--defined-only', path], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }).stdout ?? '';
  return text.split('\n').map(line => line.trim().split(/\s+/)).filter(f => f.length === 3 && /^[TtWwDdBbRr]$/.test(f[1]));
}

// The modules a per-module build ran the compiler for: one `<module>.s` beside the image.
function moduleRuns(project, image) {
  const directory = join(project, `${image}.modules`);
  assert.ok(existsSync(directory), `${image}.modules: the default build must make one file per module`);
  return readdirSync(directory).filter(name => name.endsWith('.s')).map(name => name.slice(0, -2)).sort();
}
function run(executable) {
  const result = spawnSync(executable, [], { encoding: 'utf8', timeout: 900_000 });
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

const stripGlobals = text => text.split('\n').filter(line => !line.startsWith('.globl ')).join('\n');
const leadingNotes = text => text.split('\n').filter(line => line.startsWith('// grail-link: ')).join('\n') + (text.startsWith('// grail-link: ') ? '\n' : '');

// (1) The parts are the single stream: same bytes, same order, nothing duplicated or dropped.
function proveText(name, single, split) {
  const { parts, link } = manifestOf(split.asm);
  const singleText = readFileSync(single.asm, 'utf8');
  assert.equal(link.join('\n') + (link.length ? '\n' : ''), leadingNotes(singleText), `${name}: link requests differ`);
  const body = singleText.replace(/^(\/\/ grail-link: [^\n]*\n)*/, '').replace(/^\.text\n/, '');
  let joined = '';
  for (const part of parts) {
    const text = readFileSync(part, 'utf8');
    assert.ok(text.startsWith(prologue), `${part}: missing .text prologue`);
    joined += stripGlobals(text.slice(prologue.length));
  }
  assert.equal(stripGlobals(joined), stripGlobals(body), `${name}: parts do not concatenate to the single assembly`);
  return { parts, link };
}

// (2) The objects carry the same code: same section sizes, identical bytes outside relocations.
function proveObject(name, singleObject, objects) {
  // Data sections are compared in the linked image below: a per-object section starts on its own
  // alignment, so concatenating the objects' `.rodata` can differ in padding, and padding is not
  // data. Code is compared here, where it is still one instruction stream.
  const expected = section(singleObject, '.text');
  const chunks = objects.map(object => section(object, '.text'));
  const joined = Buffer.concat(chunks);
  assert.equal(joined.length, expected.length, `${name}: .text length ${joined.length} != ${expected.length}`);
  if (target !== 'x86_64') return { masked: 0 };
  const masked = new Set();
  let base = 0;
  objects.forEach((object, i) => {
    for (const [offset, size] of relocatedSpans(object)) {
      for (let k = 0; k < size; k += 1) masked.add(base + offset + k);
    }
    base += chunks[i].length;
  });
  let differing = 0;
  for (let i = 0; i < expected.length; i += 1) {
    if (!masked.has(i) && expected[i] !== joined[i]) differing += 1;
  }
  assert.equal(differing, 0, `${name}: ${differing} code bytes differ outside relocation fields`);
  return { masked: masked.size };
}

// (3) The linked program is the same program: same tables, same symbols, same output.
function proveImage(name, singleExe, splitExe, objects, expect) {
  for (const sectionName of ['.rodata', '.data', '.bss']) {
    assert.deepEqual(section(splitExe, sectionName), section(singleExe, sectionName), `${name}: ${sectionName} differs in the linked image`);
  }
  const single = symbols(singleExe).map(f => `${f[2].toLowerCase()}`).sort();
  const split = symbols(splitExe).map(f => `${f[2].toLowerCase()}`).sort();
  assert.deepEqual(split, single, `${name}: symbol names differ`);
  const textDelta = section(splitExe, '.text').length - section(singleExe, '.text').length;
  // Objects are laid out in order; the only growth is padding that aligns each input section.
  assert.ok(textDelta >= 0 && textDelta < 3 * objects.length, `${name}: .text grew by ${textDelta} bytes`);
  if (target === hostTarget) {
    const a = run(singleExe);
    const b = run(splitExe);
    assert.equal(b.status, a.status, `${name}: exit status ${b.status} != ${a.status}`);
    assert.equal(b.stdout, a.stdout, `${name}: program output differs`);
    if (expect !== undefined) assert.equal(a.stdout, expect, `${name}: single-file output`);
  }
  return textDelta;
}

const cases = [];
{
  const book = JSON.parse(readFileSync(join(root, 'book/book.json'), 'utf8'));
  const example = (book.examples ?? []).find(e => e.id === 'modules');
  assert.ok(example, 'book/book.json: no `modules` example');
  cases.push({
    name: 'book-modules',
    inputs: [join(root, 'book', example.entry), ...(example.modules ?? []).map(m => join(root, 'book', m))],
    expect: example.output,
  });
}
{
  const corpus = JSON.parse(readFileSync(join(root, 'tests/native-cases.json'), 'utf8'));
  const test = corpus.find(t => t.name === 'vecs-fold-and-predicates');
  assert.ok(test, 'tests/native-cases.json: no vecs-fold-and-predicates case');
  const entry = join(work, 'vecs-fold.grl');
  writeFileSync(entry, test.source);
  cases.push({
    name: 'native-generics',
    inputs: [entry, ...test.modules.map(m => join(root, m)), ...(test.std ?? []).map(s => join(root, 'lib', `${s}.grl`))],
    expect: test.stdout,
  });
}
// The compiler's own sources already end with runtime.grl and os-linux.grl.
cases.push({ name: 'compiler', inputs: compilerSources, expect: undefined, bare: true });

const timings = [];
let parts = 0;
for (const test of cases) {
  const platform = test.bare ? [] : [join(root, 'compiler/runtime.grl'), join(root, 'compiler/os-linux.grl')];
  const inputs = [...test.inputs, ...platform];
  const single = compile(test.name, inputs, false);
  const split = compile(test.name, inputs, true);
  const manifest = proveText(test.name, single, split);
  const singleObject = single.asm.replace(/\.s$/, '.o');
  const assembleSingle = (() => { const started = process.hrtime.bigint(); assembleOne(single.asm, singleObject); return Number(process.hrtime.bigint() - started) / 1e6; })();
  const { objects, ms: assembleSplitMs } = await assembleParts(manifest.parts);
  const linkArgs = linkInputs(readFileSync(single.asm, 'utf8'), dirname(inputs[0]));
  const singleExe = single.asm.replace(/\.s$/, '.exe');
  const splitExe = split.asm.replace(/\.s$/, '.exe');
  const linkSingleMs = link([singleObject], singleExe, linkArgs);
  const linkSplitMs = link(objects, splitExe, linkArgs);
  const { masked } = proveObject(test.name, singleObject, objects);
  const textDelta = proveImage(test.name, singleExe, splitExe, objects, test.expect);
  parts += manifest.parts.length;
  timings.push({ name: test.name, parts: manifest.parts.length, masked, textDelta, compile: [single.ms, split.ms], assemble: [assembleSingle, assembleSplitMs], link: [linkSingleMs, linkSplitMs] });
  console.log(`split: ${test.name}: ${manifest.parts.length} parts, same text, same object (${masked} relocated bytes), +${textDelta} bytes of link-time padding`);
}

// (4) The driver: `grail build --split` must produce the same program as `grail build`.
{
  const project = join(work, 'project');
  mkdirSync(join(project, 'src'), { recursive: true });
  writeFileSync(join(project, 'grail.pkg'), 'name split-demo\n');
  writeFileSync(join(project, 'src/util.grl'), 'module util;\n\npub fn twice(x: u64) -> u64 {\n    return x * 2;\n}\n\npub fn report(name: &[u8], value: u64) {\n    print(name);\n    print(" = ");\n    println(value);\n}\n');
  writeFileSync(join(project, 'src/main.grl'), 'use util;\n\npub fn main() -> u64 {\n    util::report("twice(21)", util::twice(21));\n    return 0;\n}\n');
  const env = { ...process.env, GRAIL_HOME: root };
  const build = args => {
    const result = spawnSync(compiler, ['build', ...args], { cwd: project, env, encoding: 'utf8' });
    assert.equal(result.status, 0, `grail build ${args.join(' ')}: ${result.stdout}${result.stderr}`);
    return `${result.stdout}${result.stderr}`;
  };
  // The split build has no runtime-error location table; the reference is built without one too.
  build(['--whole-program', '--no-error-sites', '-o', 'target/demo']);
  build(['--split', '-o', 'target/demo-split']);
  const single = join(project, 'target/demo');
  const split = join(project, 'target/demo-split');
  assert.deepEqual(section(split, '.rodata'), section(single, '.rodata'), 'driver: .rodata differs');
  const a = run(single);
  const b = run(split);
  assert.equal(b.stdout, a.stdout, 'driver: program output differs');
  assert.equal(b.status, a.status, 'driver: exit status differs');
  assert.equal(a.stdout, 'twice(21) = 42\n', 'driver: unexpected program output');
  assert.ok(existsSync(join(project, 'target/demo-split.parts')), 'driver: missing parts manifest');
  console.log('split: driver: grail build --split agrees with grail build');

  // One compiler invocation per module (B1 stage 4): a module that instantiates a generic from
  // another, and one that uses the standard library's interfaces and implementations (vecs::sort
  // through order::Ord). Each module is compiled by its own run against the interfaces of the
  // modules before it, then linked once; the program must agree with the whole-program build.
  writeFileSync(join(project, 'src/pair.grl'), 'module pair;\n\nuse util;\n\npub struct Pair<T> {\n    a: T,\n    b: T\n}\n\npub fn make<T>(a: T, b: T) -> Pair<T> {\n    return Pair { a: a, b: b };\n}\n\npub fn doubled(x: u64) -> u64 {\n    return util::twice(x) + 1;\n}\n');
  writeFileSync(join(project, 'src/main.grl'), 'use pair;\nuse util;\nuse vecs;\n\npub fn main() -> u64 {\n    p := pair::make<u64>(3, 4);\n    mut v = u64[5, 1, 3];\n    vecs::sort(&mut v);\n    println(v[0] * 100 + v[1] * 10 + v[2]);\n    println(p.a + p.b);\n    util::report("doubled", pair::doubled(10) + util::twice(v.len()));\n    return 0;\n}\n');
  build(['--whole-program', '-o', 'target/whole']);
  build(['-o', 'target/modules']);
  // `--per-module` asked for this build before it was the default; the alias must still mean it.
  build(['--per-module', '-o', 'target/alias']);
  const whole = run(join(project, 'target/whole'));
  const modules = run(join(project, 'target/modules'));
  const alias = run(join(project, 'target/alias'));
  assert.equal(whole.stdout, '135\n7\ndoubled = 27\n', 'per-module: unexpected whole-program output');
  assert.equal(modules.stdout, whole.stdout, 'per-module: the module-at-a-time build prints differently');
  assert.equal(modules.status, whole.status, 'per-module: exit status differs');
  assert.equal(alias.stdout, modules.stdout, 'per-module: --per-module and the default print differently');
  const built = moduleRuns(project, 'target/modules');
  for (const module of ['main', 'pair', 'util', 'vecs', 'order', 'core', 'runtime']) {
    assert.ok(built.includes(module), `per-module: no compiler run for module ${module} (${built.join(', ')})`);
  }
  // (The images cannot be compared byte for byte here: each object's symbol table names the assembly
  // file it was assembled from, and that path carries the image name.)
  assert.deepEqual(moduleRuns(project, 'target/alias'), built, 'per-module: --per-module and the default differ');
  console.log(`split: driver: grail build (${built.length} compiler runs: ${built.join(', ')}) agrees with --whole-program`);

  // A generic interface implementation read back from an interface file (`impl<T> Iterator for
  // Iter<T>` in iter) and closures emitted inside specialisations: the per-module build has to
  // rebuild the implementation's parameters from the file, and give those closures one binding.
  copyFileSync(join(root, 'book/examples/iterator-adapters.grl'), join(project, 'src/main.grl'));
  rmSync(join(project, 'src/pair.grl'), { force: true });
  rmSync(join(project, 'src/util.grl'), { force: true });
  build(['--whole-program', '-o', 'target/iter-whole']);
  const iterBuild = build(['-o', 'target/iter-modules']);
  assert.ok(!/changed binding/.test(iterBuild ?? ''), 'per-module: a symbol changed binding');
  assert.equal(run(join(project, 'target/iter-modules')).stdout, run(join(project, 'target/iter-whole')).stdout, 'per-module: iter adapters print differently');
  console.log('split: driver: a generic interface implementation from an interface file builds per module');

  // The same holds on the cross targets: the default is one run per module there too, and the
  // program it links makes the same answer as the whole-program build.
  for (const cross of ['aarch64', 'riscv64']) {
    const qemu = runner(cross)[0];
    if (cross !== hostTarget && spawnSync(qemu, ['--version'], { encoding: 'utf8' }).status !== 0) {
      console.log(`split: driver: ${cross} not run (no ${qemu})`);
      continue;
    }
    build(['--target', cross, '-o', `target/modules-${cross}`]);
    build(['--target', cross, '--whole-program', '-o', `target/whole-${cross}`]);
    const crossModules = execute(join(project, `target/modules-${cross}`), [], cross);
    const crossWhole = execute(join(project, `target/whole-${cross}`), [], cross);
    // `execute` hands back Buffers; the text is what is compared.
    const modulesOut = (crossModules.stdout ?? '').toString();
    const wholeOut = (crossWhole.stdout ?? '').toString();
    assert.equal(modulesOut, '135\n7\ndoubled = 27\n', `${cross}: unexpected per-module output`);
    assert.equal(modulesOut, wholeOut, `${cross}: the per-module build prints differently`);
    assert.equal(crossModules.status, crossWhole.status, `${cross}: exit status differs`);
    const ran = moduleRuns(project, `target/modules-${cross}`);
    assert.ok(ran.length > 1, `${cross}: the default build must run the compiler per module (${ran.join(', ')})`);
    console.log(`split: driver: ${cross}: grail build (${ran.length} compiler runs: ${ran.join(', ')}) agrees with --whole-program`);
  }
}

if (timing) {
  const pad = (s, n) => String(s).padStart(n);
  console.log('\ncase              parts   compile ms      assemble ms      link ms');
  for (const t of timings) {
    console.log(`${t.name.padEnd(16)} ${pad(t.parts, 5)}  ${pad(t.compile[0].toFixed(0), 6)} -> ${pad(t.compile[1].toFixed(0), 5)}  ${pad(t.assemble[0].toFixed(0), 6)} -> ${pad(t.assemble[1].toFixed(0), 5)}  ${pad(t.link[0].toFixed(0), 4)} -> ${pad(t.link[1].toFixed(0), 4)}`);
  }
}
console.log(`split: ${cases.length} cases and the driver agree (${parts} part files)`);
