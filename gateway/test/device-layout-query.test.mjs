import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const queryScript = join(root, 'scripts', 'device-ui-layout-query.py');
const taskDockAssertScript = join(root, 'scripts', 'device-ui-task-dock-assert.py');
const mockFixtureScript = join(root, 'scripts', 'device-ui-mock.ps1');
const python = process.platform === 'win32' ? 'python' : 'python3';

function hex(value) {
  return Buffer.from(value, 'utf8').toString('hex');
}

test('mock fixture readiness tolerates transient layout dump failures', () => {
  const source = readFileSync(mockFixtureScript, 'utf8');
  assert.match(source, /Require two valid[\s\S]*renders from one process/);
  assert.match(source, /tolerate transient dump failures/);
  assert.match(source, /readyEvidenceCount/);
  assert.match(source, /remote JSON file is fully flushed/);
  assert.match(source, /Get-Content -Raw -Encoding UTF8/);
});

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

function taskDockLayout({ dockBottom, item = null, messageY = 500, listTop = 300 }) {
  const taskText = {
    attributes: {
      bounds: '[50,310][180,350]',
      text: '任务计划',
      visible: 'true',
    },
    children: [],
  };
  const taskButton = {
    attributes: {
      accessibilityText: '展开任务计划',
      bounds: '[24,300][1056,364]',
      clickable: 'true',
      visible: 'true',
    },
    children: [taskText],
  };
  const dockChildren = [taskButton];
  if (item) {
    dockChildren.push({
      attributes: {
        bounds: '[40,500][800,550]',
        text: item,
        visible: 'true',
      },
      children: [],
    });
  }
  return {
    attributes: {
      bounds: '[0,0][1080,2400]',
      visible: 'true',
    },
    children: [
      {
        attributes: {
          bounds: `[0,${listTop}][1080,2200]`,
          type: 'List',
          visible: 'true',
        },
        children: [
          {
            attributes: {
              bounds: `[20,${listTop}][900,${Math.max(listTop, dockBottom)}]`,
              type: 'ListItem',
              visible: 'true',
            },
            children: [],
          },
          {
            attributes: {
              bounds: `[20,${messageY}][900,${messageY + 80}]`,
              text: 'fixture message',
              type: 'ListItem',
              visible: 'true',
            },
            children: [],
          },
        ],
      },
      {
        attributes: {
          bounds: `[0,300][1080,${dockBottom}]`,
          visible: 'true',
        },
        children: dockChildren,
      },
    ],
  };
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

test('task Dock assertion requires an overlay that does not reflow the transcript', (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'dsh-task-dock-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const collapsed = join(directory, 'collapsed.json');
  const expanded = join(directory, 'expanded.json');
  const scrolled = join(directory, 'scrolled.json');
  const inFlow = join(directory, 'in-flow.json');
  writeFileSync(collapsed, JSON.stringify([taskDockLayout({ dockBottom: 364 })]));
  writeFileSync(expanded, JSON.stringify([taskDockLayout({
    dockBottom: 700,
    item: '检查隐私与账户入口',
  })]));
  writeFileSync(scrolled, JSON.stringify([taskDockLayout({
    dockBottom: 700,
    item: '检查隐私与账户入口',
    messageY: 420,
  })]));
  writeFileSync(inFlow, JSON.stringify([taskDockLayout({
    dockBottom: 364,
    listTop: 372,
  })]));

  const passing = spawnSync(python, [
    taskDockAssertScript,
    '--collapsed',
    collapsed,
    '--expanded',
    expanded,
    '--scrolled',
    scrolled,
  ], {
    encoding: 'utf8',
    windowsHide: true,
  });
  assert.equal(passing.status, 0, passing.stderr);
  assert.equal(JSON.parse(passing.stdout).transcriptList[1], 300);

  const failing = spawnSync(python, [
    taskDockAssertScript,
    '--collapsed',
    inFlow,
    '--expanded',
    inFlow,
  ], {
    encoding: 'utf8',
    windowsHide: true,
  });
  assert.notEqual(failing.status, 0);
  assert.match(failing.stderr, /not anchored at the transcript top/);
});
