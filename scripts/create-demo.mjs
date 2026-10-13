import { existsSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

const root = fileURLToPath(new URL('../', import.meta.url));
const examples = path.join(root, 'examples');
const adapter = path.join(root, 'scripts', 'impose-pdf.mjs');
const files = {
  source: path.join(examples, 'mvp-source-20.pdf'),
  output: path.join(examples, 'mvp-imposed-20.pdf'),
  plan: path.join(examples, 'mvp-imposed-20.json'),
  svg: path.join(examples, 'mvp-imposed-20.svg'),
};

const force = process.argv.includes('--force');
if (!force && Object.values(files).some((file) => existsSync(file))) {
  throw new Error('demo files already exist; rerun with --force to regenerate them');
}
if (force) {
  for (const file of Object.values(files)) rmSync(file, { force: true });
}

const source = await PDFDocument.create();
const font = await source.embedFont(StandardFonts.Helvetica);
for (let i = 1; i <= 20; i += 1) {
  const page = source.addPage([600, 400]);
  page.drawRectangle({
    x: 18,
    y: 18,
    width: 564,
    height: 364,
    borderColor: rgb(0.15, 0.35, 0.65),
    borderWidth: 3,
  });
  page.drawText(`FoldLedger demo source page ${i}`, {
    x: 150,
    y: 190,
    size: 20,
    font,
    color: rgb(0.1, 0.1, 0.1),
  });
}
writeFileSync(files.source, await source.save());

const result = spawnSync(process.execPath, [
  adapter,
  '--input', files.source,
  '--output', files.output,
  '--plan', files.plan,
  '--svg', files.svg,
  '--signature', '16',
], { cwd: root, encoding: 'utf8', stdio: 'inherit' });
if (result.error) throw result.error;
if (result.status !== 0) throw new Error('PDF demo generation failed');
