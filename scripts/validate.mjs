// Offline artifact checks only. This script does not execute Power Query M.
import {readFileSync, readdirSync, existsSync} from 'node:fs';
import {resolve, relative, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const expected = [
  '.gitignore', 'LICENSE', 'README.md', 'src/Connector.pq', 'src/LiveTransport.pq',
  'config/Config.example.pq', 'examples/DemoIssues.pq', 'examples/LiveIssues.pq',
  'examples/issues.ndjson', 'tests/ContractTests.pq', 'scripts/validate.mjs',
  'docs/architecture.md', 'docs/security.md', 'docs/validation.md'
];
function walk(dir) {
  return readdirSync(dir, {withFileTypes: true}).flatMap(e => {
    if (e.name === '.git' || e.name === 'node_modules') return [];
    const path = resolve(dir, e.name);
    return e.isDirectory() ? walk(path) : [relative(root, path).replaceAll('\\', '/')];
  });
}
const files = walk(root);
assert.deepEqual(files.sort(), expected.sort(), 'Unexpected or missing publication file');
let links = 0;
for (const path of files) {
  const text = readFileSync(resolve(root, path), 'utf8');
  assert(!text.includes('\u0000'), `Binary content: ${path}`);
  assert(!/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(text), `Private key: ${path}`);
  assert(!/\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16})\b/.test(text), `Token pattern: ${path}`);
  assert(!/https?:\/\/(?!tenant\.example\.invalid)[a-z0-9-]+\.xdr\.[a-z0-9.-]+/i.test(text), `Tenant address: ${path}`);
  assert(!/\b(?:\d{1,3}\.){3}\d{1,3}\b/.test(text), `IP address requires review: ${path}`);
  assert(!/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(text), `Email requires review: ${path}`);
  if (path.endsWith('.md')) {
    for (const match of text.matchAll(/\]\(([^)]+)\)/g)) {
      const target = match[1];
      if (/^https:\/\//.test(target)) continue;
      assert(existsSync(resolve(root, dirname(path), target.split('#')[0])), `Broken local link: ${path} -> ${target}`);
      links++;
    }
    assert.equal((text.match(/^```/gm) ?? []).length % 2, 0, `Unbalanced code fences: ${path}`);
  }
}
const config = readFileSync(resolve(root, 'config/Config.example.pq'), 'utf8');
for (const value of ['https://tenant.example.invalid', '<API_KEY>', '<API_KEY_ID>']) assert(config.includes(value));
const rows = readFileSync(resolve(root, 'examples/issues.ndjson'), 'utf8').trim().split(/\r?\n/).map(JSON.parse);
assert.equal(rows.length, 2);
assert.deepEqual(rows.map(r => r['xdm.issue.id']), ['SYNTH-001', 'SYNTH-002']);
assert.equal(new Date(rows[0]._time).toISOString(), '2026-01-01T00:00:00.000Z');
assert.equal(rows.reduce((sum, r) => sum + Number(r['xdm.issue.alert_count']), 0), 4);
const keys = ['xdm.issue.id', 'xdm.issue.severity', 'xdm.issue.status.progress', '_time', 'xdm.issue.alert_count', 'xdm.issue.is_excluded'];
for (const row of rows) assert.deepEqual(Object.keys(row).sort(), [...keys].sort());
const tests = readFileSync(resolve(root, 'tests/ContractTests.pq'), 'utf8');
assert.equal((tests.match(/Check\("/g) ?? []).length, 25);
assert(!/Web\.Contents/.test(tests), 'Contract tests must remain offline');
const ignore = readFileSync(resolve(root, '.gitignore'), 'utf8');
assert(!ignore.split(/\r?\n/).includes('*.pq'), 'Power Query source must remain tracked');
console.log(`PASS: ${files.length} allowlisted files, ${links} local links, 2 synthetic rows, 25 M test definitions.`);
console.log('Pattern checks passed; human disclosure review remains necessary. This static checker does not execute M.');
