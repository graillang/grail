// The offline shader flow: HLSL -> SPIR-V (Vulkan) and DXIL (D3D12), plus the reflection blob
// every backend consumes, its JSON form, and the layout hash.
//
//   node graphics/tools/shader.mjs --all              compile every graphics/shaders/**/<name>.<stage>.hlsl
//   node graphics/tools/shader.mjs <file.hlsl> [...]  compile the named files
//   node graphics/tools/shader.mjs --all --no-dxil    SPIR-V only (a Linux-only build)
//   node graphics/tools/shader.mjs --all --json-only  skip the binary blob, write .refl.json
//
// Reflection is extracted by parsing the compiled SPIR-V's decorations. That avoids
// -fspv-reflect, whose SPIR-V extensions the devices do not enable (see
// graphics/docs/shader-flow.md), and gives one description for all three backends from the
// source that was actually compiled.
//
// Dependencies: DXC 1.9.2609 (see docs/dependencies.md), spirv-val to validate the output,
// spirv-cross only for the Metal leg. DXC is resolved from $DXC, then Abundance's pinned
// tools cache, then PATH, so both engines compile with the same compiler.

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const shaderRoot = join(root, 'shaders');
const includeRoot = join(shaderRoot, 'include');
const outRoot = process.env.GRAIL_SHADER_OUT ?? resolve(root, '..', '.work', 'shaders');

const DXC_REQUIRED = '1.9.2609';
const STAGES = { vs: 'Vertex', ps: 'Fragment', cs: 'Compute', ms: 'Mesh', as: 'Task', lib: 'Library' };
const PROFILE = '6_6';

// The flag set documented in docs/shader-flow.md. Keep this the single definition: a
// second copy in a build file is how two builds come to disagree.
const SPIRV_FLAGS = [
  '-spirv', '-fspv-target-env=vulkan1.3', '-HV', '2021', '-enable-16bit-types',
  '-fvk-use-scalar-layout', '-Zpr', '-fspv-use-unknown-image-format', '-O3',
  '-Wno-conversion', '-Wno-ignored-attributes',
  '-I', includeRoot,
];
const DXIL_FLAGS = [
  '-HV', '2021', '-enable-16bit-types', '-Zpr', '-O3',
  '-Wno-conversion', '-Wno-ignored-attributes',
  '-I', includeRoot,
];

// ---------------------------------------------------------------------------------------
// Tool discovery
// ---------------------------------------------------------------------------------------
function findDxc() {
  if (process.env.DXC) return process.env.DXC;
  const cache = join(process.env.HOME ?? '', '.cache', 'abundance', 'engine-tools');
  if (existsSync(cache)) {
    for (const entry of readdirSync(cache)) {
      if (!entry.startsWith('dxc-')) continue;
      const candidate = join(cache, entry, 'bin', 'dxc');
      if (existsSync(candidate)) return candidate;
    }
  }
  return 'dxc'; // PATH; the version check below will say so if it is missing
}
function findTool(name) {
  const found = spawnSync('sh', ['-c', `command -v ${name}`], { encoding: 'utf8' });
  return found.status === 0 ? found.stdout.trim() : null;
}

function run(argv, what) {
  const result = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8' });
  if (result.error) throw new Error(`${what}: ${result.error.message}`);
  if (result.status !== 0) {
    throw new Error(`${what} failed (${result.status})\n${result.stdout ?? ''}${result.stderr ?? ''}`);
  }
  return result;
}

// ---------------------------------------------------------------------------------------
// SPIR-V parsing
//
// Only what reflection needs: decorations, type shapes, constants, variables and the entry
// point. Every read is bounded by the instruction's own word count, so a malformed module
// cannot walk off the end of the buffer.
// ---------------------------------------------------------------------------------------
const OP = {
  Name: 5, MemberName: 6, EntryPoint: 15, ExecutionMode: 16,
  TypeVoid: 19, TypeBool: 20, TypeInt: 21, TypeFloat: 22, TypeVector: 23, TypeMatrix: 24,
  TypeImage: 25, TypeSampler: 26, TypeSampledImage: 27, TypeArray: 28, TypeRuntimeArray: 29,
  TypeStruct: 30, TypePointer: 32, TypeFunction: 33, Constant: 43, ConstantComposite: 46,
  Variable: 59, Decorate: 71, MemberDecorate: 72,
};
const DECOR = { Binding: 33, DescriptorSet: 34, Offset: 35, Location: 30, BuiltIn: 11 };
const STORAGE = { UniformConstant: 0, Input: 1, Uniform: 2, Output: 3, PushConstant: 9, StorageBuffer: 12 };
const EXEC_MODEL = { 0: 'vs', 4: 'ps', 5: 'cs', 5267: 'as', 5268: 'ms' };

function readString(words, startWord, startByte = 0) {
  const bytes = [];
  for (let w = startWord; w < words.length; w++) {
    for (let b = w === startWord ? startByte : 0; b < 4; b++) {
      const byte = (words[w] >>> (b * 8)) & 0xff;
      if (byte === 0) return { text: Buffer.from(bytes).toString('utf8'), wordsUsed: w - startWord + 1 };
      bytes.push(byte);
    }
  }
  return { text: Buffer.from(bytes).toString('utf8'), wordsUsed: words.length - startWord };
}

function parseSpirv(buffer) {
  if (buffer.length < 20 || buffer.readUInt32LE(0) !== 0x07230203)
    throw new Error('not a SPIR-V module');
  const words = new Uint32Array(buffer.buffer, buffer.byteOffset, buffer.length >> 2);
  const mod = {
    names: new Map(), memberNames: new Map(), decorations: new Map(), memberOffsets: new Map(),
    memberBuiltIn: new Set(),
    types: new Map(), constants: new Map(), variables: [], entryPoint: null, localSize: null,
  };

  const u32 = (i) => words[i] >>> 0;
  const f32 = (i) => new Float32Array(Uint32Array.of(words[i]).buffer)[0];

  for (let i = 5; i < words.length;) {
    const wordCount = words[i] >>> 16;
    const opcode = words[i] & 0xffff;
    if (wordCount === 0) break;
    const args = words.subarray(i + 1, i + wordCount);
    switch (opcode) {
      case OP.Name: mod.names.set(u32(i + 1), readString(words, i + 2).text); break;
      case OP.MemberName: {
        const type = u32(i + 1), member = u32(i + 2);
        if (!mod.memberNames.has(type)) mod.memberNames.set(type, new Map());
        mod.memberNames.get(type).set(member, readString(words, i + 3).text);
        break;
      }
      case OP.EntryPoint: {
        const model = u32(i + 1), id = u32(i + 2);
        mod.entryPoint = { model, id, name: readString(words, i + 3).text };
        break;
      }
      case OP.ExecutionMode: {
        const mode = u32(i + 2);
        if (mode === 17) mod.localSize = [u32(i + 3), u32(i + 4), u32(i + 5)]; // LocalSize
        break;
      }
      case OP.TypeInt: mod.types.set(u32(i + 1), { kind: 'int', width: u32(i + 2), signed: u32(i + 3) === 1 }); break;
      case OP.TypeFloat: mod.types.set(u32(i + 1), { kind: 'float', width: u32(i + 2) }); break;
      case OP.TypeVector: mod.types.set(u32(i + 1), { kind: 'vec', component: u32(i + 2), count: u32(i + 3) }); break;
      case OP.TypeMatrix: mod.types.set(u32(i + 1), { kind: 'mat', column: u32(i + 2), columns: u32(i + 3) }); break;
      case OP.TypeArray: mod.types.set(u32(i + 1), { kind: 'array', element: u32(i + 2), lengthId: u32(i + 3) }); break;
      case OP.TypeRuntimeArray: mod.types.set(u32(i + 1), { kind: 'runtimearray', element: u32(i + 2) }); break;
      case OP.TypeStruct: {
        const members = [];
        for (let m = i + 2; m < i + wordCount; m++) members.push(u32(m));
        mod.types.set(u32(i + 1), { kind: 'struct', members });
        break;
      }
      case OP.TypePointer: mod.types.set(u32(i + 1), { kind: 'ptr', storage: u32(i + 2), pointee: u32(i + 3) }); break;
      case OP.TypeImage: mod.types.set(u32(i + 1), {
        kind: 'image', sampledType: u32(i + 2), dim: u32(i + 3), depth: u32(i + 4),
        arrayed: u32(i + 5), ms: u32(i + 6), sampled: u32(i + 7),
      }); break;
      case OP.TypeSampler: mod.types.set(u32(i + 1), { kind: 'sampler' }); break;
      case OP.TypeSampledImage: mod.types.set(u32(i + 1), { kind: 'sampledimage', image: u32(i + 2) }); break;
      case OP.Constant: {
        const typeId = u32(i + 1);
        const type = mod.types.get(typeId);
        let value = 0;
        if (type && type.kind === 'int') value = type.width === 64 ? Number(words[i + 3]) + Number(words[i + 4]) * 2 ** 32 : u32(i + 3);
        else if (type && type.kind === 'float' && type.width === 32) value = f32(i + 3);
        mod.constants.set(u32(i + 2), value);
        break;
      }
      case OP.Decorate: {
        const target = u32(i + 1), decoration = u32(i + 2);
        if (!mod.decorations.has(target)) mod.decorations.set(target, new Map());
        mod.decorations.get(target).set(decoration, decoration === DECOR.BuiltIn ? u32(i + 3) : u32(i + 3));
        break;
      }
      case OP.MemberDecorate: {
        const type = u32(i + 1), member = u32(i + 2), decoration = u32(i + 3);
        if (decoration === DECOR.BuiltIn) mod.memberBuiltIn.add(`${type}:${member}`);
        if (decoration === DECOR.Offset) {
          if (!mod.memberOffsets.has(type)) mod.memberOffsets.set(type, new Map());
          mod.memberOffsets.get(type).set(member, u32(i + 4));
        }
        break;
      }
      case OP.Variable: mod.variables.push({ typeId: u32(i + 1), id: u32(i + 2), storage: u32(i + 3) }); break;
      default: break;
    }
    i += wordCount;
  }
  mod.words = words;
  return mod;
}

// Byte size of a type, or null when it cannot be known statically (an unbounded array).
function typeSize(mod, typeId, depth = 0) {
  if (depth > 8) return null;
  const type = mod.types.get(typeId);
  if (!type) return null;
  switch (type.kind) {
    case 'int': case 'float': return type.width / 8;
    case 'vec': { const c = typeSize(mod, type.component, depth + 1); return c === null ? null : c * type.count; }
    case 'mat': { const c = typeSize(mod, type.column, depth + 1); return c === null ? null : c * type.columns; }
    case 'array': {
      const element = typeSize(mod, type.element, depth + 1);
      const count = mod.constants.get(type.lengthId);
      return element === null || count === undefined ? null : element * count;
    }
    case 'struct': {
      const offsets = mod.memberOffsets.get(typeId) ?? new Map();
      let end = 0;
      for (let m = 0; m < type.members.length; m++) {
        const offset = offsets.get(m);
        const size = typeSize(mod, type.members[m], depth + 1);
        if (offset === undefined || size === null) return null;
        end = Math.max(end, offset + size);
      }
      return end;
    }
    default: return null;
  }
}

const MEMBER_TYPES = {
  'float': 0, 'vec2f': 1, 'vec3f': 2, 'vec4f': 3, 'mat4x4f': 4,
  'int': 5, 'uint': 6, 'vec2i': 7, 'vec2u': 8, 'vec3u': 9, 'vec4u': 10, 'vec4i': 11,
  'struct': 12, 'mat2x2f': 13, 'mat3x3f': 14,
};
function memberTypeId(mod, typeId) {
  const type = mod.types.get(typeId);
  if (!type) return { id: MEMBER_TYPES.struct, name: 'unknown' };
  switch (type.kind) {
    case 'float': return type.width === 32 ? { id: MEMBER_TYPES.float, name: 'float' } : { id: MEMBER_TYPES.struct, name: `float${type.width}` };
    case 'int': return type.signed ? { id: MEMBER_TYPES.int, name: 'int' } : { id: MEMBER_TYPES.uint, name: 'uint' };
    case 'vec': {
      const c = mod.types.get(type.component);
      const base = c && c.kind === 'float' ? 'float' : c && c.signed ? 'int' : 'uint';
      const suffix = base === 'float' ? 'f' : base === 'int' ? 'i' : 'u';
      const key = `vec${type.count}${suffix}`;
      return { id: MEMBER_TYPES[key] ?? MEMBER_TYPES.struct, name: `${base}${type.count}` };
    }
    case 'mat': return { id: type.columns === 4 ? MEMBER_TYPES['mat4x4f'] : type.columns === 3 ? MEMBER_TYPES['mat3x3f'] : MEMBER_TYPES['mat2x2f'], name: `matrix${type.columns}` };
    case 'array': return { id: MEMBER_TYPES.struct, name: 'array' };
    case 'struct': return { id: MEMBER_TYPES.struct, name: 'struct' };
    default: return { id: MEMBER_TYPES.struct, name: type.kind };
  }
}

function bindingKind(mod, variable) {
  const pointer = mod.types.get(variable.typeId);
  if (!pointer || pointer.kind !== 'ptr') return null;
  if (variable.storage === STORAGE.PushConstant) return 6;
  const pointee = mod.types.get(pointer.pointee);
  if (!pointee) return null;
  if (pointee.kind === 'image') return pointee.sampled === 2 ? 1 : 0; // 2: read-write
  if (pointee.kind === 'sampler') return 2;
  if (pointee.kind === 'struct') return variable.storage === STORAGE.StorageBuffer ? 3 : 4;
  if (pointee.kind === 'array' || pointee.kind === 'runtimearray') {
    const element = mod.types.get(pointee.element);
    if (!element) return null;
    if (element.kind === 'image') return element.sampled === 2 ? 1 : 0;
    if (element.kind === 'sampler') return 2;
    if (element.kind === 'struct') return variable.storage === STORAGE.StorageBuffer ? 3 : 4;
  }
  return null;
}

function arraySize(mod, variable) {
  const pointer = mod.types.get(variable.typeId);
  if (!pointer) return 1;
  const pointee = mod.types.get(pointer.pointee);
  if (!pointee) return 1;
  if (pointee.kind === 'runtimearray') return 0; // unbounded: the bindless case
  if (pointee.kind === 'array') {
    const count = mod.constants.get(pointee.lengthId);
    return count === undefined ? 0 : count;
  }
  return 1; // a single binding, which a table does not use
}

// ---------------------------------------------------------------------------------------
// Reflection extraction
// ---------------------------------------------------------------------------------------
const FORMATS = {
  'float': 'R32_FLOAT', 'vec2f': 'R32G32_FLOAT', 'vec3f': 'R32G32B32A32_FLOAT',
  'vec4f': 'R32G32B32A32_FLOAT', 'uint': 'R32_UINT', 'vec2u': 'R32G32_UINT',
  'vec4u': 'R32G32B32A32_UINT',
};
const FORMAT_IDS = {
  R32_FLOAT: 14, R32G32_FLOAT: 16, R32G32B32A32_FLOAT: 17, R32_UINT: 13,
  R32G32_UINT: 15, R32G32B32A32_UINT: 18, R16G16B16A16_FLOAT: 11,
};

function vertexFormat(mod, typeId) {
  const type = mod.types.get(typeId);
  if (!type) return { name: 'R32G32B32A32_FLOAT', components: 4 };
  if (type.kind === 'vec') {
    const component = mod.types.get(type.component);
    const suffix = component && component.kind === 'float' ? 'f' : component && component.signed ? 'i' : 'u';
    const key = `vec${type.count}${suffix}`;
    return { name: FORMATS[key] ?? 'R32G32B32A32_FLOAT', components: type.count };
  }
  const scalar = memberTypeId(mod, typeId);
  return { name: FORMATS[scalar.name] ?? 'R32_FLOAT', components: 1 };
}

function extractReflection(mod, stage) {
  const strings = [];
  const intern = (text) => {
    const existing = strings.indexOf(text);
    if (existing >= 0) return existing;
    strings.push(text);
    return strings.length - 1;
  };
  // String table is encoded as NUL-separated text; the offset is the byte position.
  const stringOffsets = new Map();
  const bindings = [], members = [], vertices = [];
  let pushConstantSize = 0;

  const nameOf = (id, fallback) => mod.names.get(id) ?? fallback;

  for (const variable of mod.variables) {
    const kind = bindingKind(mod, variable);
    if (kind === null) continue;
    // Push constants are not a descriptor: they occupy no set or binding, so listing them in
    // the binding table would place them at an invented (0,0) and collide with the sampled-
    // image table. Their size goes on the stage record instead.
    if (kind === 6) {
      const pointer = mod.types.get(variable.typeId);
      pushConstantSize = (pointer ? typeSize(mod, pointer.pointee) : 0) ?? 0;
      continue;
    }
    const decor = mod.decorations.get(variable.id) ?? new Map();
    const set = decor.get(DECOR.DescriptorSet) ?? 0;
    const binding = decor.get(DECOR.Binding) ?? 0;

    let memberFirst = 0, memberCount = 0;
    const pointer = mod.types.get(variable.typeId);
    const pointee = pointer ? mod.types.get(pointer.pointee) : null;
    if (pointee && pointee.kind === 'struct' && (kind === 4 || kind === 3)) {
      const offsets = mod.memberOffsets.get(pointer.pointee) ?? new Map();
      const names = mod.memberNames.get(pointer.pointee) ?? new Map();
      memberFirst = members.length;
      for (let m = 0; m < pointee.members.length; m++) {
        const typeId = pointee.members[m];
        const mt = memberTypeId(mod, typeId);
        const nextOffset = offsets.get(m + 1);
        const size = nextOffset !== undefined
          ? nextOffset - offsets.get(m)
          : (typeSize(mod, typeId) ?? 0);
        members.push({
          name: nameOf(variable.id, '') === '' ? `member${m}` : `${nameOf(variable.id, 'block')}.${names.get(m) ?? `m${m}`}`,
          memberName: names.get(m) ?? `m${m}`,
          typeName: mt.name,
          type: mt.id,
          offset: offsets.get(m) ?? 0,
          size,
          arraySize: 1,
        });
        memberCount++;
      }
    }

    const typeName = pointee ? (mod.types.get(pointer.pointee)?.kind ?? 'opaque') : 'opaque';
    bindings.push({
      set, binding, kind,
      arraySize: arraySize(mod, variable),
      name: nameOf(variable.id, `set${set}_binding${binding}`),
      typeName,
      stageMask: 1 << stageIndex(stage),
      memberFirst, memberCount,
    });
  }

  // Vertex inputs are a vertex-stage concept: a fragment shader's Location-decorated inputs
  // describe what the rasteriser interpolates, not an attribute array the host binds. Treating
  // them as vertex attributes would have a pipeline ask for the wrong input layout.
  for (const variable of stage === 'vs' ? mod.variables : []) {
    if (variable.storage !== STORAGE.Input) continue;
    const decor = mod.decorations.get(variable.id) ?? new Map();
    if (decor.has(DECOR.BuiltIn)) continue;
    const location = decor.get(DECOR.Location);
    if (location === undefined) continue;
    // SV_VertexID arrives as an Input variable that may carry the built-in decoration on its
    // struct member rather than on the variable; either way it is not an attribute the host
    // binds, and treating it as one would make a pipeline ask for the wrong input layout.
    {
      const pointer = mod.types.get(variable.typeId);
      const pointee = pointer ? mod.types.get(pointer.pointee) : null;
      if (pointee && pointee.kind === 'struct' &&
          pointee.members.some((_, m) => mod.memberBuiltIn.has(`${pointer.pointee}:${m}`)))
        continue;
    }
    const pointer = mod.types.get(variable.typeId);
    const info = vertexFormat(mod, pointer?.pointee);
    vertices.push({
      semantic: nameOf(variable.id, `TEXCOORD${location}`),
      semanticIndex: 0,
      location,
      format: FORMAT_IDS[info.name] ?? FORMAT_IDS.R32G32B32A32_FLOAT,
      formatName: info.name,
      offset: 0,
      componentCount: info.components,
    });
  }

  bindings.sort((a, b) => (a.set - b.set) || (a.binding - b.binding));
  vertices.sort((a, b) => a.location - b.location);
  for (const b of bindings) {
    strings.indexOf(b.name) < 0 && strings.push(b.name);
    strings.indexOf(b.typeName) < 0 && strings.push(b.typeName);
  }
  for (const m of members) {
    !strings.includes(m.name) && strings.push(m.name);
    !strings.includes(m.typeName) && strings.push(m.typeName);
  }
  for (const v of vertices) !strings.includes(v.semantic) && strings.push(v.semantic);

  return { strings, bindings, members, vertices, pushConstantSize };
}
function stageIndex(stage) {
  return { vs: 0, ps: 1, cs: 2, ms: 3, as: 4, lib: 5 }[stage];
}

// ---------------------------------------------------------------------------------------
// Permutation domains
//
// A shader declares the defines it reacts to with a directive DXC ignores:
//
//     // grail:permutation GRAIL_QUALITY default=2 values=0,1,2
//
// The tool is the only place a permutation can come from, so a host cannot ask for a define
// the shader does not declare (gr_shader.h). The directive is a comment, so it cannot change
// what the shader compiles to.
// ---------------------------------------------------------------------------------------
const DIRECTIVE = /\/\/\s*grail:permutation\s+([A-Za-z_][A-Za-z0-9_]*)\s+default\s*=\s*(-?\d+)\s+values\s*=\s*(-?\d+(?:\s*,\s*-?\d+)*)/g;

function parsePermutationDomains(sourceText) {
  const domains = [];
  for (const match of sourceText.matchAll(DIRECTIVE)) {
    const values = match[3].split(',').map(v => Number(v.trim()));
    domains.push({ name: match[1], defaultValue: Number(match[2]), values });
  }
  return domains;
}

// The id must equal gr_permutation_name_id(): the low 32 bits of FNV-1a 64 over the name.
function permutationNameId(name) {
  let hash = FNV_OFFSET;
  hash = fnvBytes(hash, Buffer.from(name, 'utf8'));
  return Number(hash & 0xffffffffn);
}

// The key must equal gr_permutation_key(): entries sorted by name id, then each name and value
// folded in that order. Sorting is what makes enumeration order irrelevant.
function permutationKey(entries) {
  const sorted = [...entries].sort((a, b) => a.name - b.name);
  let hash = FNV_OFFSET;
  for (const entry of sorted) {
    hash = fnvU64(hash, entry.name);
    hash = fnvU64(hash, entry.value);
  }
  return hash;
}

// The cross product, bounded. A build that silently produced 100k shaders would be worse than
// one that refused, so exceeding the cap is an error with the count in it.
const PERMUTATION_LIMIT = 256;
function enumeratePermutations(domains) {
  if (domains.length === 0) return [ [] ];
  const total = domains.reduce((n, d) => n * Math.max(1, d.values.length), 1);
  if (total > PERMUTATION_LIMIT)
    throw new Error(`${total} permutations exceeds the limit of ${PERMUTATION_LIMIT}`);
  let combinations = [ [] ];
  for (const domain of domains) {
    const next = [];
    for (const combination of combinations)
      for (const value of domain.values)
        next.push([...combination, { name: permutationNameId(domain.name), define: domain.name, value }]);
    combinations = next;
  }
  return combinations;
}

// ---------------------------------------------------------------------------------------
// The digest. Must match gr_reflect_compute_layout_hash() in src/grail_reflect.c exactly;
// graphics/src/grail_reflect_tool.c fails the build when the two disagree.
// ---------------------------------------------------------------------------------------
const FNV_OFFSET = 0xcbf29ce484222325n, FNV_PRIME = 0x100000001b3n, MASK64 = (1n << 64n) - 1n;
function fnvBytes(hash, buf) {
  for (const byte of buf) { hash = ((hash ^ BigInt(byte)) * FNV_PRIME) & MASK64; }
  return hash;
}
function fnvU64(hash, value) {
  let v = BigInt.asUintN(64, typeof value === 'bigint' ? value : BigInt(value));
  for (let i = 0; i < 8; i++) { hash = ((hash ^ ((v >> BigInt(i * 8)) & 0xffn)) * FNV_PRIME) & MASK64; }
  return hash;
}
function computeLayoutHash(refl) {
  // Every shift is BigInt. JavaScript's `|` and `<<` are 32-bit and signed, so
  // `offset << 24` for a member at 368 bytes wraps negative there while C computes the same
  // expression in uint64 — the two digests then disagree on any struct larger than 256 bytes.
  let h1 = FNV_OFFSET, h2 = 0x84222325cbf29ce4n;
  for (const b of refl.bindings) {
    const packed = (BigInt(b.set) << 24n) | (BigInt(b.binding) << 8n) | BigInt(b.kind);
    h1 = fnvU64(h1, packed);
    h1 = fnvU64(h1, b.arraySize);
    h2 = fnvU64(h2, b.memberCount);
    h2 = fnvBytes(h2, Buffer.from(b.name, 'utf8'));
  }
  for (const m of refl.members) {
    h1 = fnvU64(h1, (BigInt(m.offset) << 24n) | (BigInt(m.size) << 8n) | BigInt(m.type));
    h2 = fnvU64(h2, (BigInt(m.arraySize) << 16n) | 0n); // matrix_major is always row-major
  }
  for (const v of refl.vertices) {
    h1 = fnvU64(h1, (BigInt(v.location) << 32n) | (BigInt(v.format) << 8n) | BigInt(v.componentCount));
    h2 = fnvU64(h2, (BigInt(v.offset) << 16n) | BigInt(v.semanticIndex));
  }
  return [h1, h2];
}

// ---------------------------------------------------------------------------------------
// Blob writing. The layout is gr_reflect_blob_header in include/grail/grail_shader.h.
// ---------------------------------------------------------------------------------------
// sizeof(gr_reflect_blob_header): 136. The C tool checks header_size against its own
// sizeof and refuses the blob, so a drift here fails the build instead of the renderer.
const HEADER_SIZE = 136;
function writeBlob({ container, stage, bytecode, refl, entryPoint, source, compiler, flags, layoutHash, domains = [] }) {
  const encoder = new TextEncoder();
  const names = buffer => Buffer.from(buffer, 'utf8');
  const parts = [];

  const header = Buffer.alloc(HEADER_SIZE);
  const writeU64 = (value, offset) => header.writeBigUInt64LE(BigInt.asUintN(64, BigInt(value)), offset);

  // Bytecode first after the header, 8-byte aligned (the header is a multiple of 8).
  const bytecodeOffset = HEADER_SIZE;
  const bytecodeLength = bytecode.length;

  // Then the string section: NUL-terminated, offsets from the start of the section.
  const stringSection = [];
  const offsets = new Map();
  let cursor = 0;
  const addString = (text) => {
    if (offsets.has(text)) return offsets.get(text);
    const bytes = names(text);
    offsets.set(text, cursor);
    stringSection.push(bytes, Buffer.from([0]));
    cursor += bytes.length + 1;
    return offsets.get(text);
  };
  addString(''); // offset 0 is the empty string, so a zeroed field is never a wild pointer
  const entryOffset = addString(entryPoint);
  const sourceOffset = addString(source);
  const compilerOffset = addString(compiler);
  const flagsOffset = addString(flags);
  const bindingNameOffsets = refl.bindings.map(b => addString(b.name));
  const bindingTypeOffsets = refl.bindings.map(b => addString(b.typeName));
  const memberNameOffsets = refl.members.map(m => addString(m.name));
  const memberTypeOffsets = refl.members.map(m => addString(m.typeName));
  const vertexSemanticOffsets = refl.vertices.map(v => addString(v.semantic));
  // gr_reflect_define: name, default_value, value_count, values (a comma-separated string).
  const defineRecords = domains.slice(0, 16).map(d => ({
    nameOffset: addString(d.name),
    defaultValue: d.defaultValue,
    valuesOffset: addString(d.values.join(',')),
    valueCount: d.values.length,
  }));
  const stringBuffer = Buffer.concat(stringSection);

  // Tables, each 4-byte aligned.
  const REH = 32, REM = 24, REV = 24, RES = 44; // sizeof(gr_reflect_binding/member/vertex/stage)
  const bindingBuffer = Buffer.alloc(refl.bindings.length * REH);
  refl.bindings.forEach((b, i) => {
    const o = i * REH;
    bindingBuffer.writeUInt16LE(b.set, o);
    bindingBuffer.writeUInt16LE(b.binding, o + 2);
    bindingBuffer.writeUInt16LE(b.kind, o + 4);
    bindingBuffer.writeUInt16LE(b.arraySize, o + 6);
    bindingBuffer.writeUInt32LE(bindingNameOffsets[i], o + 8);
    bindingBuffer.writeUInt32LE(bindingTypeOffsets[i], o + 12);
    bindingBuffer.writeUInt32LE(b.stageMask, o + 16);
    bindingBuffer.writeUInt32LE(b.memberFirst, o + 20);
    bindingBuffer.writeUInt32LE(b.memberCount, o + 24);
  });
  const memberBuffer = Buffer.alloc(refl.members.length * REM);
  refl.members.forEach((m, i) => {
    const o = i * REM;
    memberBuffer.writeUInt32LE(memberNameOffsets[i], o);
    memberBuffer.writeUInt32LE(memberTypeOffsets[i], o + 4);
    memberBuffer.writeUInt32LE(m.offset, o + 8);
    memberBuffer.writeUInt32LE(m.size, o + 12);
    memberBuffer.writeUInt16LE(m.type, o + 16);
    memberBuffer.writeUInt16LE(m.arraySize, o + 18);
    memberBuffer.writeUInt16LE(0, o + 20); // row-major
  });
  const vertexBuffer = Buffer.alloc(refl.vertices.length * REV);
  refl.vertices.forEach((v, i) => {
    const o = i * REV;
    vertexBuffer.writeUInt32LE(vertexSemanticOffsets[i], o);
    vertexBuffer.writeUInt32LE(v.semanticIndex, o + 4);
    vertexBuffer.writeUInt32LE(v.location, o + 8);
    vertexBuffer.writeUInt32LE(v.format, o + 12);
    vertexBuffer.writeUInt32LE(v.offset, o + 16);
    vertexBuffer.writeUInt32LE(v.componentCount, o + 20);
  });
  const stageBuffer = Buffer.alloc(RES);
  const localSize = [1, 1, 1];
  stageBuffer.writeUInt16LE(stageIndex(stage), 0);
  stageBuffer.writeUInt16LE(0, 2);
  stageBuffer.writeUInt32LE(localSize[0], 4);
  stageBuffer.writeUInt32LE(localSize[1], 8);
  stageBuffer.writeUInt32LE(localSize[2], 12);
  // push_constant_offset, push_constant_size live at bytes 28 and 32 of gr_reflect_stage.
  stageBuffer.writeUInt32LE(0, 28);
  stageBuffer.writeUInt32LE(refl.pushConstantSize ?? 0, 32);

  let offset = HEADER_SIZE + bytecodeLength;
  const align = (n) => { const pad = (n - (offset % n)) % n; if (pad) { parts.push(Buffer.alloc(pad)); offset += pad; } };
  // Every table is 4-byte aligned: the reader checks each offset and refuses an unaligned
  // one, because a misaligned record would be a misaligned 64-bit load on some targets.
  const place = (buffer) => {
    align(4);
    const at = offset;
    parts.push(buffer);
    offset += buffer.length;
    return at;
  };
  const stringOffset = place(stringBuffer);
  const bindingOffset = place(bindingBuffer);
  const memberOffset = place(memberBuffer);
  const vertexOffset = place(vertexBuffer);
  const stageOffset = place(stageBuffer);
  const defineBuffer = Buffer.alloc(defineRecords.length * 16);
  defineRecords.forEach((d, i) => {
    const o = i * 16;
    defineBuffer.writeUInt32LE(d.nameOffset, o);
    defineBuffer.writeUInt32LE(d.defaultValue, o + 4);
    defineBuffer.writeUInt32LE(d.valueCount, o + 8);
    defineBuffer.writeUInt32LE(d.valuesOffset, o + 12);
  });
  const defineOffset = place(defineBuffer);

  header.writeUInt32LE(0x46455247, 0);      // 'GREF'
  header.writeUInt16LE(1, 4);               // version
  header.writeUInt16LE(HEADER_SIZE, 6);
  header.writeUInt32LE(container, 8);
  header.writeUInt32LE(stageIndex(stage), 12);
  header.writeUInt32LE(0, 16);              // flags
  writeU64(offset, 24);                     // blob_length (patched below when parts are done)
  writeU64(bytecodeOffset, 32);
  writeU64(bytecodeLength, 40);
  header.writeUInt32LE(entryOffset, 48);
  header.writeUInt32LE(sourceOffset, 52);
  header.writeUInt32LE(compilerOffset, 56);
  header.writeUInt32LE(flagsOffset, 60);
  header.writeUInt32LE(stringOffset, 64);
  header.writeUInt32LE(stringBuffer.length, 68);
  header.writeUInt32LE(bindingOffset, 72);
  header.writeUInt32LE(refl.bindings.length, 76);
  header.writeUInt32LE(memberOffset, 80);
  header.writeUInt32LE(refl.members.length, 84);
  header.writeUInt32LE(vertexOffset, 88);
  header.writeUInt32LE(refl.vertices.length, 92);
  header.writeUInt32LE(stageOffset, 96);
  header.writeUInt32LE(1, 100);
  header.writeUInt32LE(defineOffset, 104);
  header.writeUInt32LE(defineRecords.length, 108);
  writeU64(layoutHash[0], 112);
  writeU64(layoutHash[1], 120);

  const blob = Buffer.concat([header, bytecode, ...parts]);
  blob.writeBigUInt64LE(BigInt(blob.length), 24); // the exact final length
  return blob;
}

// ---------------------------------------------------------------------------------------
// Compilation
// ---------------------------------------------------------------------------------------
function findShaders() {
  const out = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) { walk(full); continue; }
      if (entry.endsWith('.hlsl')) out.push(full);
    }
  };
  walk(shaderRoot);
  return out.sort();
}

function stageOf(file) {
  const match = file.match(/\.([a-z]+)\.hlsl$/);
  if (!match) return null;
  return STAGES[match[1]] ? match[1] : null;
}

// Compiles one variant of a shader. `defines` are the -D flags of a permutation, and `suffix`
// distinguishes the outputs ("" for the default variant). Everything a variant needs is derived
// here, so the base build and every permutation go through exactly the same flags.
function buildVariant(file, stage, options, { suffix = '', defines = [], dxc, dxcVersion }) {
  const rel = relative(shaderRoot, file).replace(/\.hlsl$/, '');
  mkdirSync(join(outRoot, dirname(rel)), { recursive: true });
  const base = join(outRoot, rel) + suffix;
  const profile = ['-T', `${stage}_${PROFILE}`];
  const entry = stage === 'lib' ? [] : ['-E', 'main'];
  const defineFlags = defines.map(d => `-D${d.name}=${d.value}`);
  const spvFlags = [...SPIRV_FLAGS, ...defineFlags, ...profile, ...entry];
  const dxilFlags = [...DXIL_FLAGS, ...defineFlags, ...profile, ...entry];

  const spvPath = `${base}.spv`;
  const dxilPath = `${base}.dxil`;
  const label = relative(root, file) + (defines.length ? ` [${defines.map(d => `${d.name}=${d.value}`).join(' ')}]` : '');

  run([dxc, ...spvFlags, '-Fo', spvPath, file], `dxc (spirv) ${label}`);
  let dxil = null;
  if (!options.noDxil) {
    try {
      run([dxc, ...dxilFlags, '-Fo', dxilPath, file], `dxc (dxil) ${label}`);
      dxil = readFileSync(dxilPath);
    } catch (error) {
      // A missing dxil.dll is a normal state on a machine without it: the SPIR-V is still
      // valid, so report and continue rather than failing the whole build.
      process.stderr.write(`  dxil failed (continuing with SPIR-V only): ${String(error.message).split('\n')[0]}\n`);
    }
  }

  const spirv = readFileSync(spvPath);
  if (process.env.SPIRV_VAL !== '0') {
    const val = findTool('spirv-val');
    if (val) run([val, '--target-env', 'vulkan1.3', spvPath], `spirv-val ${relative(root, spvPath)}`);
  }

  const mod = parseSpirv(spirv);
  const refl = extractReflection(mod, stage);
  const layoutHash = computeLayoutHash(refl);

  // The Metal leg. There is no Metal compiler for HLSL, so MSL comes from SPIRV-Cross over the
  // SPIR-V DXC just produced. Argument buffers carry the same set/binding layout; see
  // docs/shader-flow.md "Metal".
  let metal = null;
  if (options.metal) {
    const cross = findTool('spirv-cross');
    if (!cross) {
      process.stderr.write('  spirv-cross not found: skipping MSL for ' +
                           `${relative(root, file)} (install SPIRV-Cross to enable the Metal leg)\n`);
    } else {
      const mslPath = `${base}.msl`;
      try {
        run([cross, spvPath, '--msl', '--msl-version', '30000', '--output', mslPath],
            `spirv-cross (msl) ${label}`);
        metal = mslPath;
      } catch (error) {
        process.stderr.write(`  spirv-cross failed: ${String(error.message).split('\n')[0]}\n`);
      }
    }
  }

  return {
    rel, base, spvPath, dxilPath, spirv, dxil, mod, refl, layoutHash, metal, dxcVersion,
    // The digest of the bytecode, which is what differs between permutations. The layout hash
    // is a property of the shader's declarations and must NOT differ; the two are deliberately
    // separate so a test can prove they measure different things.
    spirvSha256: createHash('sha256').update(spirv).digest('hex'),
    dxilSha256: dxil ? createHash('sha256').update(dxil).digest('hex') : null,
  };
}

function frameConstantsSize(refl) {
  const block = refl.bindings.find(b => b.set === 1 && b.binding === 0);
  if (!block || block.memberCount === 0) return null;
  const last = refl.members[block.memberFirst + block.memberCount - 1];
  return last.offset + last.size;
}

function compile(file, options) {
  const stage = stageOf(file);
  if (!stage) throw new Error(`${relative(root, file)} has no stage suffix (<name>.<vs|ps|cs|ms|as|lib>.hlsl)`);
  const dxc = findDxc();
  const version = run([dxc, '--version'], 'dxc --version').stdout;
  const dxcVersion = (version.match(/\((\d+\.\d+\.\d+\.\d+)\)/) ?? [])[1] ?? DXC_REQUIRED;

  const sourceText = readFileSync(file, 'utf8');
  const domains = parsePermutationDomains(sourceText);
  const v = buildVariant(file, stage, options, { dxc, dxcVersion });
  const { refl, mod, layoutHash } = v;

  const inputs = refl.vertices.length;
  const quoted = value => `0x${value.toString(16).padStart(16, '0')}`;

  // Every permutation is compiled for real, not just enumerated: one SPIR-V and one DXIL per
  // combination, each with its own reflection blob, so a pipeline for a combination can be
  // created without the host ever compiling anything at run time.
  const combinations = enumeratePermutations(domains);
  const buildVariants = domains.length > 0 && !options.noPermutationBuild;
  const variants = [];
  if (buildVariants) {
    for (const combo of combinations) {
      const key = permutationKey(combo);
      const suffix = `.${key.toString(16).padStart(16, '0')}`;
      const defines = combo.map(e => ({ name: e.define, value: e.value }));
      const variant = buildVariant(file, stage, options, { suffix, defines, dxc, dxcVersion });

      // A permutation must not change the layout. If it did, the host's structs would be
      // wrong for that combination only, which is the hardest kind of layout bug to find.
      const variantLayout = variant.layoutHash;
      const layoutStable = variantLayout[0] === layoutHash[0] && variantLayout[1] === layoutHash[1];

      let blobBytes = null;
      if (!options.jsonOnly) {
        const blob = writeBlob({
          container: 0, stage, bytecode: variant.spirv, refl: variant.refl,
          entryPoint: mod.entryPoint?.name ?? 'main',
          source: relative(root, file), compiler: `dxc ${dxcVersion}`,
          flags: [...SPIRV_FLAGS, ...defines.map(d => `-D${d.name}=${d.value}`)].join(' '),
          layoutHash: variantLayout, domains,
        });
        writeFileSync(`${variant.base}.refl.bin`, blob);
        blobBytes = blob.length;
      }
      variants.push({
        key: quoted(key),
        defines: Object.fromEntries(combo.map(e => [e.define, e.value])),
        spirv_sha256: variant.spirvSha256,
        dxil_sha256: variant.dxilSha256,
        spirv_bytes: variant.spirv.length,
        layout_hash: quoted(variantLayout[0]) + quoted(variantLayout[1]).slice(2),
        layout_hash_stable: layoutStable,
        blob_bytes: blobBytes,
      });
    }
  }

  const json = {
    entry_point: mod.entryPoint?.name ?? 'main',
    stage,
    container: 'spirv',
    local_size: mod.localSize,
    source: relative(root, file),
    compiler: `dxc ${dxcVersion}`,
    flags: [...SPIRV_FLAGS, '-Fo', relative(root, v.spvPath)].join(' '),
    layout_hash: quoted(layoutHash[0]) + quoted(layoutHash[1]).slice(2),
    spirv_sha256: v.spirvSha256,
    dxil_sha256: v.dxilSha256,
    bindings: refl.bindings.map(b => ({
      set: b.set, binding: b.binding, name: b.name, kind: [
        'sampled_image', 'storage_image', 'sampler', 'storage_buffer', 'uniform_buffer',
        'acceleration_structure', 'push_constants'][b.kind],
      array_size: b.arraySize === 0 ? 'unbounded' : b.arraySize,
      members: b.memberCount,
    })),
    vertex_inputs: refl.vertices.map(x => ({
      semantic: x.semantic, location: x.location, format: x.formatName, components: x.componentCount,
    })),
    frame_constants_size: frameConstantsSize(refl),
    push_constants_bytes: refl.pushConstantSize ?? 0,
    // The declared domains, so a test can check that the build without flags equals the
    // combination whose flags are the declared defaults.
    domains: domains.map(d => ({ name: d.name, default: d.defaultValue, values: d.values })),
    permutations: combinations.map(combo => ({
      key: quoted(permutationKey(combo)),
      defines: Object.fromEntries(combo.map(e => [e.define, e.value])),
    })),
    variants,
    members: refl.members.map(m => ({ name: m.name, type: m.typeName, offset: m.offset, size: m.size })),
  };

  writeFileSync(`${v.base}.refl.json`, `${JSON.stringify(json, null, 2)}\n`);
  let blobBytes = null;
  if (!options.jsonOnly) {
    const blob = writeBlob({
      container: 0, stage, bytecode: v.spirv, refl,
      entryPoint: mod.entryPoint?.name ?? 'main',
      source: relative(root, file), compiler: `dxc ${dxcVersion}`,
      flags: [...SPIRV_FLAGS].join(' '), layoutHash, domains,
    });
    writeFileSync(`${v.base}.refl.bin`, blob);
    blobBytes = blob.length;
  }

  return {
    shader: relative(root, file), stage, spvPath: v.spvPath, json, blobBytes, inputs,
    metal: v.metal, domains, variants,
  };
}

function main(argv) {
  const files = [];
  const options = {
    noDxil: false, jsonOnly: false, all: false, metal: false, permutations: false,
    noPermutationBuild: false,
  };
  for (const arg of argv) {
    if (arg === '--all') options.all = true;
    else if (arg === '--no-dxil') options.noDxil = true;
    else if (arg === '--json-only') options.jsonOnly = true;
    else if (arg === '--metal') options.metal = true;
    else if (arg === '--permutations') options.permutations = true;
    else if (arg === '--no-permutation-build') options.noPermutationBuild = true;
    else if (arg.startsWith('-')) { process.stderr.write(`unknown option ${arg}\n`); return 2; }
    else files.push(resolve(arg));
  }
  if (!options.all && files.length === 0) {
    process.stderr.write('usage: shader.mjs --all | shader.mjs <file.hlsl>... [--no-dxil] [--json-only]\n');
    return 2;
  }

  const targets = options.all ? findShaders() : files;
  let failed = 0;
  for (const file of targets) {
    try {
      const result = compile(file, options);
      const block = result.json.frame_constants_size;
      process.stdout.write(
        `${result.shader}  [${result.stage}]  ` +
        `${result.json.bindings.length} bindings, ${result.inputs} vertex inputs` +
        `${block !== null ? `, frame constants ${block} B` : ''}` +
        `${result.json.push_constants_bytes ? `, push constants ${result.json.push_constants_bytes} B` : ''}` +
        `${result.blobBytes !== null ? `, blob ${result.blobBytes} B` : ''}` +
        `${result.domains.length ? `, ${result.json.permutations.length} permutations` : ''}` +
        `${result.variants.length ? ` (${new Set(result.variants.map(x => x.spirv_sha256)).size} distinct SPIR-V)` : ''}\n`);
      if (options.permutations) {
        for (const domain of result.domains)
          process.stdout.write(
            `    domain ${domain.name} id=0x${permutationNameId(domain.name).toString(16).padStart(8, '0')}` +
            ` default=${domain.defaultValue} values=[${domain.values.join(',')}]\n`);
      }
      for (const d of result.json.permutations.slice(0, options.permutations ? undefined : 0))
        process.stdout.write(`    perm ${d.key}  ${JSON.stringify(d.defines)}\n`);
      for (const b of result.json.bindings)
        process.stdout.write(`    set ${b.set} binding ${b.binding}  ${b.name}  ${b.kind}${b.array_size === 'unbounded' ? '[]' : `[${b.array_size}]`}\n`);
    } catch (error) {
      failed++;
      process.stderr.write(`${file}: ${error.message}\n`);
    }
  }
  if (failed) {
    process.stderr.write(`${failed} of ${targets.length} shaders failed\n`);
    return 1;
  }
  process.stdout.write(`${targets.length} shader(s) -> ${relative(process.cwd(), outRoot)}\n`);
  return 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exit(main(process.argv.slice(2)));
}
export { parseSpirv, extractReflection, computeLayoutHash, writeBlob, findShaders };
