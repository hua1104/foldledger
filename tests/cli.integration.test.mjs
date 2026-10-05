import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../', import.meta.url));
const cli = path.join(root, '_build/js/debug/build/cmd/main/main.js');
function run(args, status = 0) {
  const result = spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, status, result.stderr || result.stdout || String(result.error));
  return result;
}
function temp(t) {
  const dir = mkdtempSync(path.join(tmpdir(), 'foldledger-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test('8-page plan matches a known booklet and stdout is valid JSON', () => {
  const p = JSON.parse(run(['--pages','8','--json']).stdout);
  assert.deepEqual(p.sheets.map(s => [s.front,s.back]), [[[8,1],[2,7]],[[6,3],[4,5]]]);
  assert.equal(p.blanks,0);
  assert.equal(p.schema_version,1);
});

test('selected pages preserve source indices, right binding and back rotation', () => {
  const p = JSON.parse(run(['--pages','40','--select','21-24,1','--binding','right','--duplex','long','--json']).stdout);
  assert.deepEqual(p.selected,[21,22,23,24,1]);
  assert.deepEqual(p.sheets[0].front,[21,0]);
  assert.deepEqual(p.sheets[0].back,[0,22]);
  assert.equal(p.blanks,3);
  assert.ok(p.sheets.every(s => s.back_rotation === 180));
});

test('10000-page plan conserves every source page exactly once', () => {
  const p = JSON.parse(run(['--pages','10000','--signature','64','--json']).stdout);
  const pages = p.sheets.flatMap(s => [...s.front,...s.back]).filter(Boolean).sort((a,b)=>a-b);
  assert.deepEqual(pages,Array.from({length:10000},(_,i)=>i+1));
  assert.equal(p.sheets.length,2500);
});

test('writes deterministic JSON and bounded accessible SVG', t => {
  const dir = temp(t), json = path.join(dir,'plan.json'), svg = path.join(dir,'preview.svg');
  run(['--pages','20','--out',json,'--svg',svg]);
  const p = JSON.parse(readFileSync(json,'utf8'));
  assert.equal(p.signatures,2);
  assert.deepEqual(p.sheets[4].front,[20,17]);
  assert.equal(readFileSync(json,'utf8').trim(),run(['--pages','20','--json']).stdout.trim());
  const image = readFileSync(svg,'utf8');
  assert.match(image,/<title id="title">/);
  assert.match(image,/preview 5 of 5 sheets/);
  assert.match(image,/<\/svg>/);
});

test('rejects malformed, duplicate, out-of-range and overflowing arguments', () => {
  for (const args of [[],['--pages'],['--pages','0'],['--pages','-1'],['--pages','1.2'],['--pages','999999999999999999999'],['--pages','10','--select','1,1'],['--pages','10','--select','9-2'],['--pages','10','--signature','6'],['--pages','10','--binding','up'],['--pages','10','--duplex','side'],['--pages','4','--pages','8'],['--pages','8','--unknown']]) {
    assert.match(run(args,2).stderr,/foldledger:/);
  }
});

test('validation finishes before any output is written', t => {
  const dir = temp(t);
  run(['--pages','8','--select','1,1','--out',path.join(dir,'bad.json')],2);
  assert.deepEqual(readdirSync(dir),[]);
});

test('existing output is preserved and other requested output stays absent', t => {
  const dir = temp(t), json = path.join(dir,'plan.json'), svg = path.join(dir,'preview.svg');
  writeFileSync(svg,'keep me');
  run(['--pages','8','--out',json,'--svg',svg],2);
  assert.equal(readFileSync(svg,'utf8'),'keep me');
  assert.deepEqual(readdirSync(dir),['preview.svg']);
});

test('same output paths and missing parent are rejected without partial output', t => {
  const dir = temp(t), output = path.join(dir,'same');
  run(['--pages','8','--out',output,'--svg',output],2);
  run(['--pages','8','--out',output,'--svg',path.join(dir,'missing','preview.svg')],2);
  assert.deepEqual(readdirSync(dir),[]);
});

test('help and version require no document', () => {
  assert.match(run(['--help']).stdout,/not a transformed PDF/);
  assert.match(run(['--version']).stdout,/foldledger 0\.1\.0/);
});
