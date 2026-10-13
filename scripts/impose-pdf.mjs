import { readFile, writeFile, mkdtemp, rm, rename, stat } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PDFDocument, PDFName, degrees, rgb } from 'pdf-lib';

const root = fileURLToPath(new URL('../', import.meta.url));
const planner = path.join(root, '_build', 'js', 'debug', 'build', 'cmd', 'main', 'main.js');
const valueOptions = new Set([
  '--input', '--output', '--plan', '--svg', '--select', '--signature', '--binding', '--duplex',
]);

function fail(message) {
  console.error(`foldledger-pdf: ${message}`);
  process.exitCode = 2;
}

function help() {
  console.log('FoldLedger PDF MVP');
  console.log('node scripts/impose-pdf.mjs --input source.pdf --output booklet.pdf');
  console.log('--plan PATH and --svg PATH default to the output basename with matching extensions.');
  console.log('--select, --signature, --binding and --duplex are forwarded to the MoonBit planner.');
}

function parseArgs(argv) {
  const options = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') return { help: true };
    if (!valueOptions.has(arg)) throw new Error(`unknown option: ${arg}`);
    if (options[arg] !== undefined) throw new Error(`duplicate option: ${arg}`);
    const value = argv[i + 1];
    if (value === undefined || value.startsWith('--') || value === '') {
      throw new Error(`missing value for ${arg}`);
    }
    options[arg] = value;
    i += 1;
  }
  if (!options['--input']) throw new Error('--input is required');
  if (!options['--output']) throw new Error('--output is required');
  return options;
}

function plannerArgs(pageCount, options, svgPath) {
  const args = ['--pages', String(pageCount), '--json', '--svg', svgPath];
  for (const name of ['--select', '--signature', '--binding', '--duplex']) {
    if (options[name] !== undefined) args.push(name, options[name]);
  }
  return args;
}

async function existingFile(pathname) {
  try {
    await stat(pathname);
    return true;
  } catch (error) {
    if (error.code === 'ENOENT') return false;
    throw error;
  }
}

async function requireParent(pathname) {
  try {
    const parent = await stat(path.dirname(pathname));
    if (!parent.isDirectory()) throw new Error(`output parent is not a directory: ${path.dirname(pathname)}`);
  } catch (error) {
    if (error.code === 'ENOENT') throw new Error(`output parent does not exist: ${path.dirname(pathname)}`);
    throw error;
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    help();
    return;
  }

  const inputPath = path.resolve(options['--input']);
  const outputPath = path.resolve(options['--output']);
  const planPath = path.resolve(options['--plan'] ?? outputPath.replace(/\.pdf$/i, '') + '.json');
  const svgPath = path.resolve(options['--svg'] ?? outputPath.replace(/\.pdf$/i, '') + '.svg');
  const targets = [outputPath, planPath, svgPath];
  if (new Set(targets.map((p) => process.platform === 'win32' ? p.toLowerCase() : p)).size !== targets.length) {
    throw new Error('output paths must be different');
  }
  for (const target of targets) {
    await requireParent(target);
    if (await existingFile(target)) throw new Error(`output already exists: ${target}`);
  }
  if (!(await existingFile(inputPath))) throw new Error(`input file does not exist: ${inputPath}`);
  if (!(await existingFile(planner))) {
    throw new Error('MoonBit planner is not built; run npm run build:planner first');
  }

  const source = await PDFDocument.load(await readFile(inputPath));
  const sourcePages = source.getPages();
  if (sourcePages.length < 1 || sourcePages.length > 10000) {
    throw new Error('input PDF must contain 1..10000 pages');
  }
  const firstSize = sourcePages[0].getSize();
  for (let i = 1; i < sourcePages.length; i += 1) {
    const size = sourcePages[i].getSize();
    if (size.width !== firstSize.width || size.height !== firstSize.height) {
      throw new Error(`all input pages must have the same size; page ${i + 1} differs`);
    }
  }

  const temporary = await mkdtemp(path.join(tmpdir(), 'foldledger-pdf-'));
  const stagedPdf = path.join(temporary, 'output.pdf');
  const stagedPlan = path.join(temporary, 'plan.json');
  const stagedSvg = path.join(temporary, 'preview.svg');
  const created = [];
  try {
    const result = spawnSync(process.execPath, [planner, ...plannerArgs(sourcePages.length, options, stagedSvg)], {
      cwd: root,
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
    });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error((result.stderr || result.stdout || 'planner failed').trim());
    const planText = result.stdout.trim();
    const plan = JSON.parse(planText);
    if (plan.source_pages !== sourcePages.length) throw new Error('planner returned an inconsistent source page count');
    const output = await PDFDocument.create();
    output.setTitle('FoldLedger booklet imposition');
    output.setSubject('Generated from a FoldLedger booklet plan');
    const embedded = new Map();
    const width = firstSize.width;
    const height = firstSize.height;

    async function drawSlot(page, number, x) {
      if (number === 0) return;
      if (!Number.isInteger(number) || number < 1 || number > sourcePages.length) {
        throw new Error(`planner returned invalid source page ${number}`);
      }
      // A valid PDF page may have no Contents stream. It is already blank, so
      // leave the white output background in place instead of asking pdf-lib
      // to embed an empty page.
      if (sourcePages[number - 1].node.get(PDFName.of('Contents')) === undefined) return;
      let embeddedPage = embedded.get(number);
      if (!embeddedPage) {
        embeddedPage = await output.embedPage(sourcePages[number - 1]);
        embedded.set(number, embeddedPage);
      }
      page.drawPage(embeddedPage, { x, y: 0, width, height });
    }

    async function addFace(face, rotation) {
      const page = output.addPage([width * 2, height]);
      page.drawRectangle({ x: 0, y: 0, width: width * 2, height, color: rgb(1, 1, 1) });
      await drawSlot(page, face[0], 0);
      await drawSlot(page, face[1], width);
      if (rotation !== 0) page.setRotation(degrees(rotation));
    }

    for (const sheet of plan.sheets) {
      await addFace(sheet.front, 0);
      await addFace(sheet.back, sheet.back_rotation);
    }
    await writeFile(stagedPdf, await output.save());
    await writeFile(stagedPlan, `${JSON.stringify(plan)}\n`, 'utf8');
    const svg = await readFile(stagedSvg);
    if (plan.sheets.length * 2 !== output.getPageCount()) {
      throw new Error('generated PDF page count does not match the plan');
    }

    for (const [staged, target] of [[stagedPdf, outputPath], [stagedPlan, planPath], [stagedSvg, svgPath]]) {
      if (await existingFile(target)) throw new Error(`output appeared during generation: ${target}`);
      await rename(staged, target);
      created.push(target);
    }
    console.log(`Created ${outputPath}`);
    console.log(`Created ${planPath}`);
    console.log(`Created ${svgPath} (${svg.length} bytes)`);
  } catch (error) {
    for (const target of created) {
      try { await rm(target, { force: true }); } catch { /* best effort cleanup */ }
    }
    throw error;
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

try {
  await main();
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
