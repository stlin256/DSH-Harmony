import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const queryScript = join(root, 'scripts', 'device-ui-layout-query.py');
const python = process.platform === 'win32' ? 'python' : 'python3';

function hex(value) {
  return Buffer.from(value, 'utf8').toString('hex');
}

function query(layout, text) {
  return spawnSync(python, [
    queryScript,
    layout,
    '--find-text-hex',
    hex(text),
    '--target',
    'text',
    '--exact-text',
    '--expect-count',
    '1',
  ], {
    encoding: 'utf8',
    windowsHide: true,
  });
}

function queryRightmostBelow(layout, x, y) {
  return spawnSync(python, [
    queryScript,
    layout,
    '--rightmost-clickable-below',
    String(x),
    String(y),
    '--expect-count',
    '1',
  ], {
    encoding: 'utf8',
    windowsHide: true,
  });
}

function queryRightmostNear(layout, x, y, radius) {
  return spawnSync(python, [
    queryScript,
    layout,
    '--rightmost-clickable-near',
    String(x),
    String(y),
    String(radius),
    '--expect-count',
    '1',
  ], {
    encoding: 'utf8',
    windowsHide: true,
  });
}

test('layout query uses hint only when no visible text label exists', (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'dsh-layout-query-'));
  const layout = join(directory, 'layout.json');
  t.after(() => rmSync(directory, { recursive: true, force: true }));

  const rootNode = {
    attributes: {
      bounds: '[0,0][1080,2400]',
      visible: 'true',
    },
    children: [
      {
        attributes: {
          bounds: '[10,10][1000,100]',
          hint: 'composer hint',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[10,110][1000,200]',
          hint: 'composer hint',
          originalText: 'entered text',
          text: 'entered text',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[800,110][1000,200]',
          opacity: '0.000000',
          originalText: 'entered text',
          text: 'entered text',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[800,250][950,400]',
          clickable: 'true',
          enabled: 'true',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[10,700][220,800]',
          originalText: 'visible duplicate anchor',
          text: 'visible duplicate anchor',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[10,700][220,800]',
          opacity: '0.000000',
          originalText: 'visible duplicate anchor',
          text: 'visible duplicate anchor',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[900,720][1000,780]',
          clickable: 'true',
          enabled: 'true',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[10,500][1400,600]',
          originalText: 'partially visible long row',
          text: 'partially visible long row',
          visible: 'true',
        },
        children: [],
      },
      {
        attributes: {
          bounds: '[1300,700][1600,800]',
          originalText: 'fully clipped row',
          text: 'fully clipped row',
          visible: 'true',
        },
        children: [],
      },
    ],
  };
  writeFileSync(layout, JSON.stringify([rootNode]));

  const hint = query(layout, 'composer hint');
  assert.equal(hint.status, 0, hint.stderr);
  assert.equal(JSON.parse(hint.stdout).text, 'composer hint');

  const entered = query(layout, 'entered text');
  assert.equal(entered.status, 0, entered.stderr);
  assert.equal(JSON.parse(entered.stdout).text, 'entered text');

  const duplicateAnchor = query(layout, 'visible duplicate anchor');
  assert.equal(duplicateAnchor.status, 0, duplicateAnchor.stderr);
  assert.equal(JSON.parse(duplicateAnchor.stdout).count, 1);
  assert.equal(JSON.parse(duplicateAnchor.stdout).x, 115);
  assert.equal(JSON.parse(duplicateAnchor.stdout).y, 750);

  const near = queryRightmostNear(layout, 115, 750, 70);
  assert.equal(near.status, 0, near.stderr);
  assert.equal(JSON.parse(near.stdout).x, 950);
  assert.equal(JSON.parse(near.stdout).y, 750);

  const overflowing = query(layout, 'partially visible long row');
  assert.equal(overflowing.status, 0, overflowing.stderr);
  assert.equal(JSON.parse(overflowing.stdout).x, 545);
  assert.equal(JSON.parse(overflowing.stdout).y, 550);

  const clipped = query(layout, 'fully clipped row');
  assert.notEqual(clipped.status, 0);

  const send = queryRightmostBelow(layout, 600, 150);
  assert.equal(send.status, 0, send.stderr);
  assert.equal(JSON.parse(send.stdout).x, 875);
  assert.equal(JSON.parse(send.stdout).y, 325);
});
