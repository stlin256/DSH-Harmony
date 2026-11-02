import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDir, '..');
const sourcePath = join(
  root,
  'harmony/entry/src/main/ets/pages/Index.ets',
);
const source = readFileSync(sourcePath, 'utf8');

function functionBody(signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} is missing`);
  const open = source.indexOf('{', start + signature.length);
  assert.notEqual(open, -1, `${signature} has no body`);
  let depth = 0;
  for (let index = open; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}') depth -= 1;
    if (depth === 0) return source.slice(open + 1, index);
  }
  throw new Error(`${signature} has an unterminated body`);
}

const aboutToAppear = functionBody('aboutToAppear(): void');
assert.match(
  aboutToAppear,
  /this\.applyKeyboardAvoidMode\(\);/,
  'initial native layout must set keyboard avoidance before loading preferences',
);

const initialize = functionBody('private async initialize(): Promise<void>');
assert.match(
  initialize,
  /this\.uiMode\s*=\s*'native';\s*this\.applyKeyboardAvoidMode\(\);/,
  'showcase mode must set native avoidance explicitly',
);
assert.match(
  initialize,
  /this\.uiMode\s*=\s*modeResolution\.mode;\s*this\.applyKeyboardAvoidMode\(\);/,
  'saved native mode must not depend on an unchanged @Watch callback',
);

const modeChanged = functionBody('private modeChanged(): void');
assert.match(
  modeChanged,
  /this\.applyKeyboardAvoidMode\(\);/,
  'switching between native and web must reapply keyboard avoidance',
);

const applyKeyboardAvoidMode = functionBody(
  'private applyKeyboardAvoidMode(): void',
);
assert.match(
  applyKeyboardAvoidMode,
  /setKeyboardAvoidMode\(\s*this\.uiMode\s*===\s*'native'\s*\?\s*KeyboardAvoidMode\.RESIZE\s*:\s*KeyboardAvoidMode\.OFFSET\s*\)/,
  'native pages must resize instead of translating the whole page',
);

console.log('Keyboard avoidance source contract passed.');
