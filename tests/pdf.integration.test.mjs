import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { PDFDocument, PDFName, StandardFonts, rgb } from 'pdf-lib';

const root = fileURLToPath(new URL('../', import.meta.url));
const script = path.join(root, 'scripts', 'impose-pdf.mjs');

async function fixture() {
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  for (let i = 0; i < 8; i += 1) {
    const page = pdf.addPage([200, 300]);
    page.drawRectangle({ x: 12, y: 12, width: 176, height: 276, borderColor: rgb(0.2, 0.4, 0.7), borderWidth: 2 });
    page.drawText(`source page ${i + 1}`, { x: 48, y: 145, size: 14, font, color: rgb(0.1, 0.1, 0.1) });
  }
  return pdf.save();
}

async function mixedFixture() {
  const pdf = await PDFDocument.create();
  pdf.addPage([200, 300]);
  pdf.addPage([210, 300]);
  return pdf.save();
}

function temp(t) {
  const dir = mkdtempSync(path.join(tmpdir(), 'foldledger-pdf-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test('PDF adapter creates a two-up booklet, plan and preview', async (t) => {
  const dir = temp(t);
  const input = path.join(dir, 'source.pdf');
  const output = path.join(dir, 'booklet.pdf');
  const plan = path.join(dir, 'booklet.json');
  const svg = path.join(dir, 'booklet.svg');
  const sourceBytes = await fixture();
  writeFileSync(input, sourceBytes);
  const result = spawnSync(process.execPath, [script, '--input', input, '--output', output, '--plan', plan, '--svg', svg], {
    cwd: root,
    encoding: 'utf8',
    timeout: 30000,
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const imposed = await PDFDocument.load(readFileSync(output));
  assert.equal(imposed.getPageCount(), 4);
  assert.deepEqual(imposed.getPage(0).getSize(), { width: 400, height: 300 });
  assert.notEqual(imposed.getPage(0).node.get(PDFName.of('Contents')), undefined);
  const planData = JSON.parse(readFileSync(plan, 'utf8'));
  assert.equal(planData.sheets.length, 2);
  assert.equal(planData.blanks, 0);
  assert.match(readFileSync(svg, 'utf8'), /FoldLedger booklet imposition/);
});

test('PDF adapter forwards selection and long-edge rotation', async (t) => {
  const dir = temp(t);
  const input = path.join(dir, 'source.pdf');
  const output = path.join(dir, 'selected.pdf');
  writeFileSync(input, await fixture());
  const result = spawnSync(process.execPath, [
    script, '--input', input, '--output', output, '--select', '1-2,5-6', '--signature', '4', '--duplex', 'long',
  ], { cwd: root, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const imposed = await PDFDocument.load(readFileSync(output));
  assert.equal(imposed.getPageCount(), 2);
  assert.equal(imposed.getPage(1).getRotation().angle, 180);
  const generated = readdirSync(dir).sort();
  assert.deepEqual(generated, ['selected.json', 'selected.pdf', 'selected.svg', 'source.pdf']);
});

test('PDF adapter rejects mixed page sizes and existing outputs', async (t) => {
  const dir = temp(t);
  const input = path.join(dir, 'mixed.pdf');
  const output = path.join(dir, 'mixed-booklet.pdf');
  writeFileSync(input, await mixedFixture());
  let result = spawnSync(process.execPath, [script, '--input', input, '--output', output], {
    cwd: root,
    encoding: 'utf8',
    timeout: 30000,
  });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /same size/);
  writeFileSync(output, 'keep');
  result = spawnSync(process.execPath, [script, '--input', input, '--output', output], {
    cwd: root,
    encoding: 'utf8',
    timeout: 30000,
  });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /already exists/);
  assert.deepEqual(readdirSync(dir).sort(), ['mixed-booklet.pdf', 'mixed.pdf']);
});
