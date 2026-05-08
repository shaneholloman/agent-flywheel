import { describe, expect, test } from 'bun:test';
import { resolve } from 'node:path';
import {
  buildAgentReadinessReport,
  type AgentReadinessCommandRunner,
  type AgentReadinessFileSystem,
  type CommandRunResult,
  type DirectoryEntryResult,
  type PathStatResult,
  type ReadDirResult,
  type ReadFileResult,
} from './agent-readiness-audit.js';

type FixtureEntry =
  | { kind: 'file'; content?: string; executable?: boolean; readable?: boolean }
  | { kind: 'directory'; readable?: boolean };

const HOME = '/home/test';
const PATH = '/bin';
const REDACTION_SAMPLE = ['opaque', 'credential', 'sample'].join('-');
const PROVIDERS = ['claude', 'codex', 'gemini'] as const;

class FixtureFileSystem implements AgentReadinessFileSystem {
  private readonly entries: Map<string, FixtureEntry>;

  constructor(entries: Record<string, FixtureEntry>) {
    this.entries = new Map(
      Object.entries(entries).map(([path, entry]) => [resolve(path), entry])
    );
  }

  stat(path: string): PathStatResult {
    const key = resolve(path);
    const entry = this.entries.get(key);
    if (entry?.kind === 'file') {
      if (entry.readable === false) {
        return { kind: 'unreadable', detail: 'permission denied' };
      }
      return { kind: 'file', executable: Boolean(entry.executable) };
    }
    if (entry?.kind === 'directory') {
      if (entry.readable === false) {
        return { kind: 'unreadable', detail: 'permission denied' };
      }
      return { kind: 'directory' };
    }
    return this.hasChildren(key) ? { kind: 'directory' } : { kind: 'missing' };
  }

  readFile(path: string): ReadFileResult {
    const key = resolve(path);
    const entry = this.entries.get(key);
    if (!entry) return { kind: 'missing' };
    if (entry.kind !== 'file' || entry.readable === false) {
      return { kind: 'unreadable', detail: 'permission denied' };
    }
    return { kind: 'ok', content: entry.content ?? '' };
  }

  readDir(path: string): ReadDirResult {
    const key = resolve(path);
    const entry = this.entries.get(key);
    if (entry?.kind === 'file') {
      return { kind: 'unreadable', detail: 'not a directory' };
    }
    if (entry?.kind === 'directory' && entry.readable === false) {
      return { kind: 'unreadable', detail: 'permission denied' };
    }

    const children = new Map<string, DirectoryEntryResult>();
    const prefix = `${key}/`;
    for (const [entryPath, child] of this.entries) {
      if (!entryPath.startsWith(prefix)) continue;
      const rest = entryPath.slice(prefix.length);
      const [name] = rest.split('/');
      if (!name) continue;
      const directPath = `${prefix}${name}`;
      const directEntry = this.entries.get(directPath);
      const kind = directEntry?.kind === 'file'
        ? 'file'
        : directEntry?.kind === 'directory' || entryPath !== directPath
          ? 'directory'
          : child.kind === 'file'
            ? 'file'
            : 'directory';
      children.set(name, { name, kind });
    }

    if (!entry && children.size === 0) return { kind: 'missing' };
    return {
      kind: 'ok',
      entries: Array.from(children.values()).sort((a, b) => a.name.localeCompare(b.name)),
    };
  }

  private hasChildren(path: string): boolean {
    const prefix = `${path}/`;
    for (const entryPath of this.entries.keys()) {
      if (entryPath.startsWith(prefix)) return true;
    }
    return false;
  }
}

class FixtureCommandRunner implements AgentReadinessCommandRunner {
  run(commandPath: string): CommandRunResult {
    return {
      status: 0,
      stdout: `${commandPath.split('/').at(-1)} 1.2.3\n`,
      stderr: '',
    };
  }
}

function executable(path: string): FixtureEntry {
  return { kind: 'file', executable: true, content: '#!/usr/bin/env bash\n' };
}

function jsonFile(value: unknown): FixtureEntry {
  return { kind: 'file', content: JSON.stringify(value) };
}

function profile(provider: string, name: string): Record<string, FixtureEntry> {
  return {
    [`${HOME}/.local/share/caam/profiles/${provider}/${name}/profile.json`]: jsonFile({
      name,
      provider,
      auth_mode: 'oauth',
    }),
  };
}

function baseEntries(): Record<string, FixtureEntry> {
  return {
    '/bin/claude': executable('/bin/claude'),
    '/bin/codex': executable('/bin/codex'),
    '/bin/gemini': executable('/bin/gemini'),
    '/bin/caam': executable('/bin/caam'),
    [`${HOME}/.claude/.credentials.json`]: jsonFile({ claudeAiOauth: { accessToken: REDACTION_SAMPLE } }),
    [`${HOME}/.codex/auth.json`]: jsonFile({ tokens: { access_token: REDACTION_SAMPLE } }),
    [`${HOME}/.gemini/settings.json`]: jsonFile({ selectedAuthType: 'oauth-personal' }),
    [`${HOME}/.gemini/oauth_creds.json`]: jsonFile({ access_token: REDACTION_SAMPLE }),
    [`${HOME}/.config/caam/config.json`]: jsonFile({
      default_profiles: {
        claude: 'work',
        codex: 'work',
        gemini: 'work',
      },
    }),
    ...profile('claude', 'work'),
    ...profile('codex', 'work'),
    ...profile('gemini', 'work'),
  };
}

function reportFor(entries: Record<string, FixtureEntry>) {
  return buildAgentReadinessReport({
    home: HOME,
    env: {
      HOME,
      PATH,
    },
    pathEntries: [PATH],
    fileSystem: new FixtureFileSystem(entries),
    commandRunner: new FixtureCommandRunner(),
    generatedAt: '2026-01-01T00:00:00Z',
  });
}

describe('agent readiness audit', () => {
  test('passes authenticated fixture without leaking secret values', () => {
    const report = reportFor(baseEntries());

    expect(report.ok).toBe(true);
    expect(report.summary.fail).toBe(0);
    const toolsById = Object.fromEntries(report.tools.map((tool) => [tool.id, tool]));
    for (const provider of PROVIDERS) {
      const tool = toolsById[provider];
      expect(tool?.status).toBe('pass');
      expect(tool?.auth?.status).toBe('pass');
    }
    expect(report.tools.find((item) => item.id === 'caam')?.status).toBe('pass');
    expect(JSON.stringify(report)).not.toContain(REDACTION_SAMPLE);
  });

  test('warns when a CLI is present but auth is missing', () => {
    const entries = baseEntries();
    delete entries[`${HOME}/.codex/auth.json`];

    const report = reportFor(entries);
    const codex = report.tools.find((item) => item.id === 'codex');

    expect(report.ok).toBe(true);
    expect(codex?.status).toBe('warn');
    expect(codex?.auth?.status).toBe('warn');
    expect(codex?.nextActions.join('\n')).toContain('codex');
  });

  test('fails malformed auth or config JSON', () => {
    const entries = baseEntries();
    entries[`${HOME}/.codex/auth.json`] = { kind: 'file', content: '{not-json' };

    const report = reportFor(entries);
    const codex = report.tools.find((item) => item.id === 'codex');

    expect(report.ok).toBe(false);
    expect(codex?.status).toBe('fail');
    expect(codex?.auth?.detail).toContain('malformed JSON');
  });

  test('fails when an agent CLI is missing', () => {
    const entries = baseEntries();
    delete entries['/bin/gemini'];

    const report = reportFor(entries);
    const gemini = report.tools.find((item) => item.id === 'gemini');

    expect(report.ok).toBe(false);
    expect(gemini?.cli.status).toBe('fail');
    expect(gemini?.cli.detail).toContain('gemini was not found');
  });

  test('does not treat system binaries as ACFS command aliases', () => {
    const entries = {
      ...baseEntries(),
      '/usr/bin/cc': executable('/usr/bin/cc'),
    };
    const report = buildAgentReadinessReport({
      home: HOME,
      env: {
        HOME,
        PATH: '/usr/bin:/bin',
      },
      pathEntries: ['/usr/bin', '/bin'],
      fileSystem: new FixtureFileSystem(entries),
      commandRunner: new FixtureCommandRunner(),
      generatedAt: '2026-01-01T00:00:00Z',
    });
    const claude = report.tools.find((item) => item.id === 'claude');

    expect(claude?.cli.status).toBe('pass');
    expect(claude?.cli.aliases.cc).toBeUndefined();
  });

  test('fails stale CAAM defaults that point to absent profiles', () => {
    const entries = baseEntries();
    entries[`${HOME}/.config/caam/config.json`] = jsonFile({
      default_profiles: {
        claude: 'work',
        codex: 'missing-profile',
        gemini: 'work',
      },
    });

    const report = reportFor(entries);
    const caam = report.tools.find((item) => item.id === 'caam');
    const codexState = caam?.caam?.providers.find((provider) => provider.provider === 'codex');

    expect(report.ok).toBe(false);
    expect(caam?.status).toBe('fail');
    expect(codexState?.detail).toContain('stale');
  });

  test('reports unreadable config as unknown without exposing contents', () => {
    const entries = baseEntries();
    entries[`${HOME}/.gemini/settings.json`] = {
      kind: 'file',
      content: JSON.stringify({ credential: REDACTION_SAMPLE }),
      readable: false,
    };
    delete entries[`${HOME}/.gemini/oauth_creds.json`];

    const report = reportFor(entries);
    const gemini = report.tools.find((item) => item.id === 'gemini');

    expect(report.ok).toBe(true);
    expect(gemini?.status).toBe('unknown');
    expect(gemini?.auth?.status).toBe('unknown');
    expect(JSON.stringify(report)).not.toContain(REDACTION_SAMPLE);
  });
});
