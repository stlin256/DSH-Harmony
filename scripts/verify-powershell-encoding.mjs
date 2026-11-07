import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Windows PowerShell 5.1 decodes a BOM-less script as the active ANSI code page.
// Every device driver contains Chinese fixture markers, so a missing UTF-8 BOM
// turns the script into a parse error on the exact host that runs the suite.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scripts = join(root, 'scripts');
const failures = [];
let checked = 0;

for (const name of readdirSync(scripts)) {
  if (extname(name) !== '.ps1') continue;
  const path = join(scripts, name);
  if (!statSync(path).isFile()) continue;
  checked += 1;
  const bytes = readFileSync(path);
  const hasBom = bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf;
  if (!hasBom) {
    failures.push(name + ' is missing a UTF-8 BOM (Windows PowerShell 5.1 would decode it as ANSI)');
    continue;
  }
  const text = bytes.subarray(3).toString('utf8');
  if (text.includes('\uFFFD')) {
    failures.push(name + ' contains undecodable bytes after the BOM');
  }
}

if (!checked) failures.push('no PowerShell scripts were found under scripts/');

if (failures.length) {
  for (const failure of failures) console.error('FAIL ' + failure);
  process.exit(1);
}
console.log('PowerShell script encoding contract passed (' + checked + ' scripts).');
