// Signing and notarization hooks.
//
// A plan is always safe to print: environment values are shown as `$NAME`,
// never resolved. `executeSigning` resolves them only when it runs a command.
// Windows and macOS lanes are distribution scaffolding until their compiler
// backends exist, so their plans report the backend blocker but still show the
// exact commands a release job will run once the backend lands.
import { spawnSync } from 'node:child_process';
import { createProbe, platformById } from './platforms.mjs';

export const SECRET_ENV = ['WINDOWS_CERT_PASSWORD', 'APPLE_ID_PASSWORD', 'APPLE_APP_PASSWORD', 'GRAIL_GPG_PASSPHRASE'];

export function envRef(name) {
  return `$${name}`;
}

export function resolveArg(arg, env = process.env) {
  if (typeof arg === 'string' && arg.startsWith('$') && /^\$[A-Z][A-Z0-9_]*$/.test(arg)) {
    const value = env[arg.slice(1)];
    if (value === undefined || value === '') throw new Error(`Missing signing environment variable ${arg.slice(1)}`);
    return value;
  }
  return arg;
}

function step(tool, argv, description, env = []) {
  return { tool, argv, description, env };
}

export function signingPlan(platform, options = {}) {
  const target = platformById(platform);
  const env = options.env ?? process.env;
  const probe = options.probe ?? { ...createProbe(env), env };
  const artifact = options.artifact ?? null;
  const tree = options.tree ?? null;
  const binary = options.binary ?? null;
  const name = target.signing.kind;
  const missingEnv = target.signing.requiredEnv.filter(key => !env[key]);
  const toolNames = target.signing.alternatives ?? [target.signing.tool];
  const found = toolNames.map(tool => ({ tool, path: probe.which(tool) })).filter(entry => entry.path);
  const steps = [];
  const notes = [];

  if (name === 'gpg') {
    if (!env.GRAIL_GPG_KEY) {
      return base(target, { artifact, tree, binary, name, status: 'unsigned', missingEnv: [], tools: found, steps, notes: ['Linux artifacts are unsigned unless GRAIL_GPG_KEY is set'] });
    }
    if (!artifact) {
      return base(target, { artifact, tree, binary, name, status: 'missing-input', missingEnv: [], tools: found, steps, notes: ['pass --artifact to sign a release archive'] });
    }
    steps.push(step('gpg', ['--batch', '--yes', '--detach-sign', '--armor', '--local-user', envRef('GRAIL_GPG_KEY'), artifact], `detached signature for ${artifact}`));
    notes.push(`signature is written next to the artifact as ${artifact}.asc`);
  } else if (name === 'authenticode') {
    const tool = found[0]?.tool ?? 'signtool';
    const input = binary ?? artifact;
    if (!input) {
      return base(target, { artifact, tree, binary, name, status: 'missing-input', missingEnv, tools: found, steps, notes: ['pass --binary (preferred) or --artifact to sign a PE file'] });
    }
    if (binary === null && artifact.endsWith('.zip')) {
      return base(target, { artifact, tree, binary, name, status: 'missing-input', missingEnv, tools: found, steps, notes: ['archives are signed after extraction: pass --binary <tree>/bin/grail.exe'] });
    }
    if (tool === 'osslsigncode') {
      steps.push(step('osslsigncode', ['sign', '-pkcs12', envRef('WINDOWS_CERT_FILE'), '-pass', envRef('WINDOWS_CERT_PASSWORD'), '-ts', envRef('WINDOWS_TIMESTAMP_URL'), '-in', input, '-out', `${input}.signed`], `Authenticode-sign ${input}`, ['WINDOWS_CERT_FILE', 'WINDOWS_CERT_PASSWORD', 'WINDOWS_TIMESTAMP_URL']));
      notes.push(`replace ${input} with ${input}.signed after signing`);
    } else {
      steps.push(step('signtool', ['sign', '/fd', 'SHA256', '/td', 'SHA256', '/tr', envRef('WINDOWS_TIMESTAMP_URL'), '/f', envRef('WINDOWS_CERT_FILE'), '/p', envRef('WINDOWS_CERT_PASSWORD'), input], `Authenticode-sign ${input}`, ['WINDOWS_CERT_FILE', 'WINDOWS_CERT_PASSWORD', 'WINDOWS_TIMESTAMP_URL']));
    }
  } else if (name === 'apple') {
    const binaryPath = binary ?? (tree ? `${tree}/bin/grail` : null);
    if (!binaryPath) {
      return base(target, { artifact, tree, binary, name, status: 'missing-input', missingEnv, tools: found, steps, notes: ['pass --tree <unpacked release> or --binary <path> so codesign can sign the binary'] });
    }
    steps.push(step('codesign', ['--force', '--options', 'runtime', '--timestamp', '--sign', envRef('APPLE_SIGNING_IDENTITY'), binaryPath], `codesign ${binaryPath}`));
    if (artifact) {
      const notaryZip = options.notarization ?? artifact.replace(/(?:\.tar\.gz|\.zip)$/, '-notary.zip');
      steps.push(step('ditto', ['-c', '-k', '--keepParent', binaryPath, notaryZip], 'create the notarization zip'));
      steps.push(step('xcrun', ['notarytool', 'submit', notaryZip, '--keychain-profile', envRef('APPLE_NOTARY_PROFILE'), '--wait'], `submit ${notaryZip} to the Apple notary service`));
      notes.push('Apple notarization tickets attach to .app/.dmg bundles, not bare CLI binaries; distribute the notarized archive and keep the submission log');
      if (options.dmg) steps.push(step('xcrun', ['stapler', 'staple', options.dmg], `staple the notarization ticket to ${options.dmg}`));
    } else {
      notes.push('pass --artifact to include notarization steps');
    }
  } else {
    return base(target, { artifact, tree, binary, name, status: 'unsupported', missingEnv, tools: found, steps, notes: [`no signing hook for ${name}`] });
  }

  const missingTools = steps.filter(entry => !probe.which(entry.tool)).map(entry => entry.tool);
  const status = missingEnv.length ? 'missing-credentials' : missingTools.length ? 'missing-tool' : 'ready';
  return base(target, { artifact, tree, binary, name, status, missingEnv, missingTools, tools: found, steps, notes });
}

function base(platform, details) {
  return {
    schema: 1,
    platform: platform.id,
    kind: details.name,
    artifact: details.artifact,
    tree: details.tree,
    binary: details.binary,
    status: details.status,
    backend: platform.tier === 'planned' ? 'blocked' : 'implemented',
    blocker: platform.blocker,
    missingEnv: details.missingEnv ?? [],
    missingTools: details.missingTools ?? [],
    tools: details.tools ?? [],
    steps: details.steps ?? [],
    notes: details.notes ?? [],
  };
}

export function displayStep(entry) {
  return [entry.tool, ...entry.argv].join(' ');
}

export function formatPlan(plan) {
  const lines = [
    `platform: ${plan.platform}`,
    `kind: ${plan.kind}`,
    `status: ${plan.status}`,
    ...(plan.blocker ? [`blocked: ${plan.blocker}`] : []),
    ...(plan.missingEnv.length ? [`missing environment: ${plan.missingEnv.join(', ')}`] : []),
    ...(plan.missingTools.length ? [`missing tools: ${plan.missingTools.join(', ')}`] : []),
    ...(plan.steps.length ? ['steps:'] : ['steps: none']),
    ...plan.steps.map(step => `  ${displayStep(step)}`),
    ...plan.notes.map(note => `note: ${note}`),
  ];
  return `${lines.join('\n')}\n`;
}

export function executeSigning(plan, options = {}) {
  const execute = options.execute ?? false;
  const env = options.env ?? process.env;
  const run = options.run ?? ((tool, args) => spawnSync(tool, args, { env, encoding: 'utf8' }));
  if (!execute) return { executed: false, results: plan.steps.map(entry => ({ tool: entry.tool, description: entry.description })) };
  if (plan.backend === 'blocked') throw new Error(`Cannot sign: ${plan.blocker}`);
  if (plan.status !== 'ready') throw new Error(`Cannot sign: ${plan.status}`);
  const results = [];
  for (const entry of plan.steps) {
    // Resolve secrets only here, immediately before the process starts. The
    // resolved argv is never returned or logged.
    const argv = entry.argv.map(arg => resolveArg(arg, env));
    const result = run(entry.tool, argv);
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`${entry.tool} failed (${result.signal ?? result.status})`);
    results.push({ tool: entry.tool, description: entry.description, status: result.status });
  }
  return { executed: true, results };
}

export function redact(value, env = process.env) {
  let text = String(value);
  for (const name of SECRET_ENV) {
    const secret = env[name];
    if (secret && secret.length >= 4) text = text.split(secret).join(`$${name}`);
  }
  return text;
}
