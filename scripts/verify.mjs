import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const cwd = fileURLToPath(new URL('../', import.meta.url));
const moon = process.platform === 'win32' ? 'moon.exe' : 'moon';
const commands = [
  [moon,['version']],
  [moon,['fmt','--check']],
  [moon,['check','--deny-warn']],
  [moon,['test','--deny-warn']],
  [moon,['build','--target','js','cmd/main']],
  [process.execPath,['--test','tests/cli.integration.test.mjs']],
];
for (const [command,args] of commands) {
  const result = spawnSync(command,args,{cwd,stdio:'inherit'});
  if (result.error) console.error(result.error.message);
  if (result.status !== 0) process.exit(result.status || 1);
}
console.log('FoldLedger verification passed.');
