import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const finalizeScript = path.join(scriptDir, 'finalize-release.sh');
const commit = 'a'.repeat(40);
const tag = 'v0.5.0';

const fakeGh = String.raw`#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');

const statePath = process.env.FAKE_GH_STATE;
const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
const args = process.argv.slice(2);

function save() {
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n');
}

function finish(value = '', status = 0) {
  save();
  if (value !== '') process.stdout.write(String(value) + '\n');
  process.exit(status);
}

function valueAfter(flag) {
  const index = args.indexOf(flag);
  return index === -1 ? undefined : args[index + 1];
}

function fields() {
  const result = {};
  for (let index = 0; index < args.length - 1; index += 1) {
    if (args[index] !== '-f' && args[index] !== '-F') continue;
    const separator = args[index + 1].indexOf('=');
    if (separator === -1) continue;
    result[args[index + 1].slice(0, separator)] = args[index + 1].slice(separator + 1);
  }
  return result;
}

function fail(message) {
  save();
  process.stderr.write(message + '\n');
  process.exit(1);
}

if (args[0] === 'release' && args[1] === 'create') {
  const releaseTag = args[2];
  const assetPaths = [];
  for (let index = 3; index < args.length && !args[index].startsWith('--'); index += 1) {
    assetPaths.push(args[index]);
  }
  const notesPath = valueAfter('--notes-file');
  let body = fs.readFileSync(notesPath, 'utf8');
  if (state.scenario === 'foreign_draft') body = 'foreign release body';
  const release = {
    id: String(state.nextReleaseId++),
    tag_name: releaseTag,
    draft: true,
    prerelease: true,
    body,
    assets: assetPaths.map((file, index) => ({
      id: 'asset-' + (index + 1),
      name: path.basename(file),
      size: fs.statSync(file).size,
      content: fs.readFileSync(file).toString('base64'),
    })),
  };
  state.releases.push(release);
  state.writes.push('release:create:' + release.id);
  finish();
}

if (args[0] !== 'api') fail('unsupported gh command: ' + args.join(' '));

const endpoint = args.find((argument) => argument.startsWith('repos/'));
const method = valueAfter('--method') || 'GET';
const jq = valueAfter('--jq') || '';
if (!endpoint) fail('missing API endpoint');

if (endpoint.endsWith('/git/refs') && method === 'POST') {
  const data = fields();
  const releaseTag = data.ref.replace('refs/tags/', '');
  state.tags[releaseTag] = data.sha;
  state.writes.push('tag:create:' + releaseTag);
  finish();
}

const deleteTag = endpoint.match(/\/git\/refs\/tags\/(.+)$/);
if (deleteTag && method === 'DELETE') {
  delete state.tags[deleteTag[1]];
  state.writes.push('tag:delete:' + deleteTag[1]);
  finish();
}

const readTag = endpoint.match(/\/git\/ref\/tags\/(.+)$/);
if (readTag) finish(state.tags[readTag[1]] || '');

if (endpoint.endsWith('/releases?per_page=100')) {
  if (state.scenario === 'draft_lookup_transient'
      && jq.includes('.draft == true')
      && (state.transientDraftLookupCount || 0) < 2) {
    state.transientDraftLookupCount = (state.transientDraftLookupCount || 0) + 1;
    finish();
  }
  if (state.scenario === 'draft_lookup_missing'
      && state.writes.some((entry) => entry.startsWith('release:create:'))) {
    finish();
  }
  const releases = state.releases.filter((release) =>
    release.tag_name === state.tag && (!jq.includes('.draft == true') || release.draft === true));
  finish(releases.map((release) => release.id).join('\n'));
}

const downloadAsset = endpoint.match(/\/releases\/assets\/([^/]+)$/);
if (downloadAsset) {
  const asset = state.releases.flatMap((release) => release.assets)
    .find((candidate) => candidate.id === downloadAsset[1]);
  if (!asset) fail('asset not found: ' + downloadAsset[1]);
  save();
  process.stdout.write(Buffer.from(asset.content, 'base64'));
  process.exit(0);
}

const releaseAssets = endpoint.match(/\/releases\/([^/]+)\/assets\?per_page=100$/);
if (releaseAssets) {
  const release = state.releases.find((candidate) => candidate.id === releaseAssets[1]);
  if (!release) fail('release not found: ' + releaseAssets[1]);
  if (jq === 'length') finish(release.assets.length);
  const nameMatch = jq.match(/\.name == "([^"]+)"/);
  const asset = nameMatch && release.assets.find((candidate) => candidate.name === nameMatch[1]);
  if (!asset) fail('asset query did not match: ' + jq);
  if (jq.endsWith('| .size')) {
    const size = (state.scenario === 'size_mismatch' || state.scenario === 'foreign_draft')
      ? asset.size + 1
      : asset.size;
    finish(size);
  }
  if (jq.endsWith('| .id')) finish(asset.id);
  fail('unsupported asset query: ' + jq);
}

const releaseEndpoint = endpoint.match(/\/releases\/([^/?]+)$/);
if (releaseEndpoint) {
  const release = state.releases.find((candidate) => candidate.id === releaseEndpoint[1]);
  if (!release) fail('release not found: ' + releaseEndpoint[1]);
  if (method === 'DELETE') {
    state.releases = state.releases.filter((candidate) => candidate.id !== release.id);
    state.writes.push('release:delete:' + release.id);
    finish();
  }
  if (method === 'PATCH') {
    release.draft = false;
    release.prerelease = true;
    state.writes.push('release:publish:' + release.id);
    if (state.scenario === 'patch_reports_failure') fail('simulated transport failure after PATCH');
    finish();
  }
  if (jq === '.draft') finish(String(release.draft));
  if (jq === '.body // ""') finish(release.body || '');
  fail('unsupported release query: ' + jq);
}

fail('unsupported API call: ' + args.join(' '));
`;

const fakeGit = String.raw`#!/usr/bin/env node
const fs = require('node:fs');

const state = JSON.parse(fs.readFileSync(process.env.FAKE_GH_STATE, 'utf8'));
const args = process.argv.slice(2);
const ref = args.at(-1);
if (args.includes('--tags')) {
  const tag = ref.replace('refs/tags/', '');
  if (!state.tags[tag]) process.exit(2);
  process.stdout.write(state.tags[tag] + '\t' + ref + '\n');
  process.exit(0);
}
if (args.includes('--heads')) {
  const tip = state.scenario === 'default_tip_moves' ? 'b'.repeat(40) : state.defaultTip;
  process.stdout.write(tip + '\t' + ref + '\n');
  process.exit(0);
}
process.stderr.write('unsupported git command: ' + args.join(' ') + '\n');
process.exit(1);
`;

const fakeStat = String.raw`#!/usr/bin/env node
const fs = require('node:fs');

const args = process.argv.slice(2);
if (args.length !== 3 || args[0] !== '-c' || args[1] !== '%s') {
  process.stderr.write('unsupported stat command: ' + args.join(' ') + '\n');
  process.exit(1);
}
process.stdout.write(String(fs.statSync(args[2]).size) + '\n');
`;

function createRelease({ id = '7', draft = true, body = 'existing release' } = {}) {
  return { id, tag_name: tag, draft, prerelease: true, body, assets: [] };
}

function runScenario(t, scenario, { releases = [], tags = {}, defaultArtifacts = false } = {}) {
  const root = mkdtempSync(path.join(tmpdir(), 'jeliya-finalize-release-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const bin = path.join(root, 'bin');
  const artifactDir = path.join(root, defaultArtifacts ? 'dist' : 'candidate-artifacts');
  const runnerTemp = path.join(root, 'runner');
  mkdirSync(bin);
  mkdirSync(artifactDir);
  mkdirSync(runnerTemp);
  writeFileSync(path.join(bin, 'gh'), fakeGh, { mode: 0o755 });
  writeFileSync(path.join(bin, 'git'), fakeGit, { mode: 0o755 });
  writeFileSync(path.join(bin, 'stat'), fakeStat, { mode: 0o755 });
  for (let index = 1; index <= 10; index += 1) {
    writeFileSync(path.join(artifactDir, `artifact-${String(index).padStart(2, '0')}.bin`), `bytes-${index}\n`);
  }

  const statePath = path.join(root, 'state.json');
  const state = {
    scenario,
    tag,
    defaultTip: commit,
    nextReleaseId: 42,
    releases,
    tags,
    writes: [],
  };
  writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n');

  const args = defaultArtifacts ? [finalizeScript] : [finalizeScript, artifactDir];
  const result = spawnSync('bash', args, {
    cwd: root,
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: `${bin}:${process.env.PATH}`,
      FAKE_GH_STATE: statePath,
      GH_TOKEN: 'test-token',
      JELIYA_RELEASE_LOOKUP_DELAY_SECONDS: '0',
      RELEASE_TAG: tag,
      RELEASE_BODY: 'Release body',
      GITHUB_RUN_ID: '1234',
      GITHUB_RUN_ATTEMPT: '2',
      GITHUB_REPOSITORY: 'example/jeliya',
      GITHUB_SHA: commit,
      DEFAULT_BRANCH: 'main',
      RUNNER_TEMP: runnerTemp,
    },
  });
  return { result, state: JSON.parse(readFileSync(statePath, 'utf8')) };
}

function failureMessage(result) {
  return `status=${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`;
}

test('publishes an entirely verified artifact set and supports the default dist directory', (t) => {
  const { result, state } = runScenario(t, 'success', { defaultArtifacts: true });
  assert.equal(result.status, 0, failureMessage(result));
  assert.equal(state.tags[tag], commit);
  assert.equal(state.releases.length, 1);
  assert.equal(state.releases[0].draft, false);
  assert.equal(state.releases[0].assets.length, 10);
  assert.match(state.releases[0].body, /<!-- jeliya-release-run:1234:2 -->/);
  assert.deepEqual(state.writes, ['tag:create:v0.5.0', 'release:create:42', 'release:publish:42']);
});

test('refuses a pre-existing release without mutating it or its tag', (t) => {
  const existing = createRelease();
  const { result, state } = runScenario(t, 'success', {
    releases: [existing],
    tags: { [tag]: commit },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /already exists .* refusing to mutate it/);
  assert.deepEqual(state.releases, [existing]);
  assert.deepEqual(state.tags, { [tag]: commit });
  assert.deepEqual(state.writes, []);
});

test('refuses a pre-existing tag without creating or deleting a release', (t) => {
  const { result, state } = runScenario(t, 'success', {
    tags: { [tag]: commit },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /tag .* already exists; refusing to mutate it/);
  assert.deepEqual(state.releases, []);
  assert.deepEqual(state.tags, { [tag]: commit });
  assert.deepEqual(state.writes, []);
});

test('removes only its owned draft and tag when verification fails', (t) => {
  const { result, state } = runScenario(t, 'size_mismatch');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /remote asset mismatch/);
  assert.deepEqual(state.releases, []);
  assert.deepEqual(state.tags, {});
  assert.deepEqual(state.writes, [
    'tag:create:v0.5.0',
    'release:create:42',
    'release:delete:42',
    'tag:delete:v0.5.0',
  ]);
});

test('recovers an owned draft after two transiently empty post-create lookups', (t) => {
  const { result, state } = runScenario(t, 'draft_lookup_transient');
  assert.equal(result.status, 0, failureMessage(result));
  assert.equal(state.releases.length, 1);
  assert.equal(state.releases[0].draft, false);
  assert.equal(state.tags[tag], commit);
  assert.equal(state.transientDraftLookupCount, 2);
  assert.deepEqual(state.writes, [
    'tag:create:v0.5.0',
    'release:create:42',
    'release:publish:42',
  ]);
});

test('preserves a draft and tag when release lookup stays ambiguous', (t) => {
  const { result, state } = runScenario(t, 'draft_lookup_missing');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /could not reconcile .* preserving its tag/);
  assert.equal(state.releases.length, 1);
  assert.equal(state.releases[0].draft, true);
  assert.equal(state.tags[tag], commit);
  assert.deepEqual(state.writes, ['tag:create:v0.5.0', 'release:create:42']);
});

test('reconciles success when PATCH publishes but its response is lost', (t) => {
  const { result, state } = runScenario(t, 'patch_reports_failure');
  assert.equal(result.status, 0, failureMessage(result));
  assert.match(result.stderr, /reconciled lost PATCH response/);
  assert.equal(state.releases.length, 1);
  assert.equal(state.releases[0].draft, false);
  assert.equal(state.tags[tag], commit);
  assert.deepEqual(state.writes, ['tag:create:v0.5.0', 'release:create:42', 'release:publish:42']);
});

test('cleans its draft and tag when the default branch moves before PATCH', (t) => {
  const { result, state } = runScenario(t, 'default_tip_moves');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /default branch moved during publication/);
  assert.deepEqual(state.releases, []);
  assert.deepEqual(state.tags, {});
  assert.deepEqual(state.writes, [
    'tag:create:v0.5.0',
    'release:create:42',
    'release:delete:42',
    'tag:delete:v0.5.0',
  ]);
});

test('preserves a foreign draft and the associated tag during cleanup', (t) => {
  const { result, state } = runScenario(t, 'foreign_draft');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /is not owned by this run; preserving it/);
  assert.equal(state.releases.length, 1);
  assert.equal(state.releases[0].draft, true);
  assert.equal(state.releases[0].body, 'foreign release body');
  assert.equal(state.tags[tag], commit);
  assert.deepEqual(state.writes, ['tag:create:v0.5.0', 'release:create:42']);
});
