import { test, expect, describe } from 'bun:test';
import { signingPlan, executeSigning, formatPlan, displayStep, resolveArg, redact } from './sign.mjs';
import { PLATFORMS } from './platforms.mjs';

const ALL_IDS = PLATFORMS.map(p => p.id);

function probe(names, env = {}) {
  return { env, which: name => names.includes(name) ? `/tools/${name}` : null, exec: () => null, exists: () => false };
}

const MAC_ENV = { APPLE_SIGNING_IDENTITY: 'Developer ID Application: Grail', APPLE_NOTARY_PROFILE: 'grail-notary' };
const WIN_ENV = { WINDOWS_CERT_FILE: 'grail.pfx', WINDOWS_CERT_PASSWORD: 'hunter2-secret', WINDOWS_TIMESTAMP_URL: 'http://timestamp.example' };

describe('signing plan safety', () => {
  test('every platform produces a printable plan without throwing', () => {
    for (const id of ALL_IDS) {
      const platform = PLATFORMS.find(p => p.id === id);
      const names = platform.signing.alternatives ?? [platform.signing.tool];
      const plan = signingPlan(id, { artifact: 'release.tar.gz', tree: 'release', binary: 'release/bin/grail', env: {}, probe: probe(names) });
      expect(plan.platform).toBe(id);
      expect(typeof formatPlan(plan)).toBe('string');
      for (const step of plan.steps) expect(typeof displayStep(step)).toBe('string');
    }
  });

  test('Linux is unsigned unless GRAIL_GPG_KEY is set', () => {
    const unsigned = signingPlan('linux-x86_64', { artifact: 'grail.tar.gz', env: {}, probe: probe(['gpg']) });
    expect(unsigned).toMatchObject({ status: 'unsigned', steps: [] });
    expect(unsigned.notes.join(' ')).toMatch(/GRAIL_GPG_KEY/);

    const signed = signingPlan('linux-x86_64', { artifact: 'grail.tar.gz', env: { GRAIL_GPG_KEY: 'ABC123' }, probe: probe(['gpg']) });
    expect(signed.status).toBe('ready');
    expect(signed.steps).toHaveLength(1);
    expect(displayStep(signed.steps[0])).toContain('--detach-sign');
    expect(displayStep(signed.steps[0])).toContain('$GRAIL_GPG_KEY');
    expect(formatPlan(signed)).not.toContain('ABC123');
  });

  test('Windows plan keeps certificate passwords out of text', () => {
    const plan = signingPlan('windows-x86_64', {
      artifact: 'grail-0.1.0-windows-x86_64.zip',
      binary: 'unpacked/bin/grail.exe',
      env: WIN_ENV,
      probe: probe(['signtool']),
    });
    expect(plan).toMatchObject({ kind: 'authenticode', status: 'ready', backend: 'implemented' });
    expect(plan.blocker).toMatch(/must not be executed/);
    const text = formatPlan(plan);
    expect(text).toContain('$WINDOWS_CERT_PASSWORD');
    expect(text).not.toContain('hunter2-secret');
    expect(text).not.toContain('grail.pfx');
    expect(plan.steps[0].argv).toContain('$WINDOWS_CERT_FILE');
    expect(plan.steps[0].argv).toContain('$WINDOWS_TIMESTAMP_URL');
  });

  test('Windows zip without an extracted binary is missing-input', () => {
    const plan = signingPlan('windows-x86_64', { artifact: 'grail.zip', env: WIN_ENV, probe: probe(['signtool']) });
    expect(plan.status).toBe('missing-input');
    expect(plan.steps).toEqual([]);
    expect(plan.notes.join(' ')).toMatch(/after extraction/);
  });

  test('missing credentials and tools are reported, not guessed', () => {
    const missingEnv = signingPlan('windows-x86_64', { binary: 'grail.exe', env: { WINDOWS_CERT_FILE: 'x' }, probe: probe(['signtool']) });
    expect(missingEnv.status).toBe('missing-credentials');
    expect(missingEnv.missingEnv).toEqual(['WINDOWS_CERT_PASSWORD', 'WINDOWS_TIMESTAMP_URL']);

    const missingTool = signingPlan('windows-x86_64', { binary: 'grail.exe', env: WIN_ENV, probe: probe([]) });
    expect(missingTool.status).toBe('missing-tool');
    expect(missingTool.missingTools).toEqual(['signtool']);
  });

  test('osslsigncode is used when signtool is absent', () => {
    const plan = signingPlan('windows-aarch64', { binary: 'grail.exe', env: WIN_ENV, probe: probe(['osslsigncode']) });
    expect(plan.steps[0].tool).toBe('osslsigncode');
    expect(displayStep(plan.steps[0])).toContain('-pkcs12 $WINDOWS_CERT_FILE');
  });

  test('macOS plan signs, builds a notary zip and submits it', () => {
    const plan = signingPlan('macos-aarch64', {
      artifact: 'grail-0.1.0-macos-aarch64.tar.gz',
      tree: 'unpacked/grail-0.1.0-macos-aarch64',
      env: MAC_ENV,
      probe: probe(['codesign', 'xcrun', 'ditto']),
    });
    expect(plan).toMatchObject({ status: 'ready', backend: 'blocked' });
    expect(plan.blocker).toMatch(/Mach-O/);
    const tools = plan.steps.map(step => step.tool);
    expect(tools).toEqual(['codesign', 'ditto', 'xcrun']);
    expect(displayStep(plan.steps[0])).toContain('--options runtime');
    expect(displayStep(plan.steps[2])).toContain('notarytool submit');
    expect(displayStep(plan.steps[2])).toContain('$APPLE_NOTARY_PROFILE');
    expect(formatPlan(plan)).not.toContain('Developer ID Application: Grail');
  });

  test('macOS without a tree or binary is missing-input', () => {
    const plan = signingPlan('macos-x86_64', { artifact: 'grail.tar.gz', env: MAC_ENV, probe: probe(['codesign', 'xcrun']) });
    expect(plan.status).toBe('missing-input');
    expect(plan.steps).toEqual([]);
  });
});

describe('signing execution', () => {
  test('dry-run never invokes a command', () => {
    let calls = 0;
    const plan = signingPlan('linux-x86_64', { artifact: 'x.tar.gz', env: { GRAIL_GPG_KEY: 'KEY' }, probe: probe(['gpg']) });
    const result = executeSigning(plan, { execute: false, run: () => { calls += 1; } });
    expect(calls).toBe(0);
    expect(result.executed).toBe(false);
    expect(result.results).toHaveLength(1);
  });

  test('execution resolves secrets only for the child process', () => {
    let captured = null;
    const plan = signingPlan('linux-x86_64', { artifact: 'x.tar.gz', env: { GRAIL_GPG_KEY: 'TOP-SECRET-KEY' }, probe: probe(['gpg']) });
    const result = executeSigning(plan, { execute: true, env: { GRAIL_GPG_KEY: 'TOP-SECRET-KEY' }, run: (tool, argv) => { captured = [tool, ...argv]; return { status: 0 }; } });
    expect(captured).toContain('TOP-SECRET-KEY');
    expect(result.executed).toBe(true);
    expect(JSON.stringify(result)).not.toContain('TOP-SECRET-KEY');
  });

  test('blocked backends and incomplete plans refuse execution', () => {
    const blocked = signingPlan('windows-aarch64', { binary: 'grail.exe', env: WIN_ENV, probe: probe(['signtool']) });
    expect(() => executeSigning(blocked, { execute: true, env: WIN_ENV, run: () => ({ status: 0 }) })).toThrow(/ARM64 PE code generation/);
    const incomplete = signingPlan('linux-x86_64', { artifact: 'x.tar.gz', env: {}, probe: probe(['gpg']) });
    expect(() => executeSigning(incomplete, { execute: true, env: {}, run: () => ({ status: 0 }) })).toThrow(/unsigned/);
  });

  test('resolveArg only expands declared environment references', () => {
    expect(resolveArg('$TOKEN', { TOKEN: 'value' })).toBe('value');
    expect(resolveArg('literal', {})).toBe('literal');
    expect(() => resolveArg('$TOKEN', {})).toThrow(/Missing signing environment variable TOKEN/);
  });

  test('redact removes configured secrets', () => {
    expect(redact('key=REDACT-ME', { WINDOWS_CERT_PASSWORD: 'REDACT-ME' })).toBe('key=$WINDOWS_CERT_PASSWORD');
    expect(redact('key=REDACT-ME', {})).toBe('key=REDACT-ME');
  });
});
