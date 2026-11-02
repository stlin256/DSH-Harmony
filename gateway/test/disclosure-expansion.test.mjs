import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const componentRoot = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);
const serviceRoot = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const scriptsRoot = new URL('../../scripts/', import.meta.url);
const readComponent = (name) => readFileSync(new URL(name, componentRoot), 'utf8');
const readService = (name) => readFileSync(new URL(name, serviceRoot), 'utf8');
const readScript = (name) => readFileSync(new URL(name, scriptsRoot), 'utf8');

test('disclosure workbench mounts production components and covers every family', () => {
  const fixture = readService('NativeUiFixture.ets');
  const workbench = readComponent('NativeDisclosureFixture.ets');
  const workspace = readComponent('NativeWorkspace.ets');
  const driver = readScript('device-ui-disclosure-e2e.ps1');

  const states = [...fixture.matchAll(/'disclosure-[\w-]+'/g)]
    .map((match) => match[0].slice(1, -1));
  assert.equal(new Set(states).size, states.length,
    'disclosure fixture states must have stable unique names');
  assert.ok(states.includes('disclosure-sidebar-more'));
  assert.ok(states.includes('disclosure-sidebar-group'));

  assert.match(workspace, /showcaseScreen === 'disclosure'/);
  assert.match(workspace, /NativeDisclosureFixture\(\{[\s\S]{0,120}storeShowcaseState/);
  assert.match(workbench, /NativeTaskDock\(\{/);
  assert.match(workbench, /NativeProcessView\(\{/);
  assert.match(workbench, /NativeMessageView\(\{/);
  assert.match(workbench, /NativeDiffBlock\(\{/);
  assert.match(workbench, /NativeBackgroundNoticeView\(\{/);
  assert.match(workbench, /NativeQueueDock\(\{/);

  for (const state of states) {
    assert.ok(driver.includes(state), `device driver missing ${state}`);
  }
});

test('disclosure headers expose synchronized expanded accessibility state', () => {
  const process = readComponent('NativeProcessView.ets');
  const step = readComponent('NativeProcessStepView.ets');
  const tool = readComponent('NativeToolCallView.ets');
  const message = readComponent('NativeMessageView.ets');
  const diff = readComponent('NativeDiffBlock.ets');
  const queue = readComponent('NativeQueueDock.ets');
  const workspace = readComponent('NativeWorkspace.ets');

  assert.match(process, /this\.expanded \? '收起工作过程' : '展开工作过程'/);
  assert.match(step, /\(this\.expanded \? '收起' : '展开'\)/);
  assert.match(tool, /this\.expanded \? '收起工具详情' : '展开工具详情'/);
  assert.match(tool, /this\.expanded \? '收起嵌套工具详情' : '展开嵌套工具详情'/);
  assert.match(message, /this\.reasoningOpen \? '收起思考过程' : '展开思考过程'/);
  assert.match(message, /this\.toolOpen \? '收起工具结果' : '展开工具结果'/);
  assert.match(message,
    /this\.toolOpen = this\.message\.currentTurn \|\| this\.message\.flat/);
  assert.doesNotMatch(message, /aboutToAppear\(\): void \{[\s\S]{0,180}this\.toolOpen = true/);
  assert.match(diff, /ForEach\(this\.shownRows\(\),[\s\S]{0,180}row\.kind[\s\S]{0,120}row\.text/);
  assert.doesNotMatch(diff, /ForEach\(this\.shownRows\(\),[\s\S]{0,180}=> index\.toString\(\)\)/);
  const driver = readScript('device-ui-disclosure-e2e.ps1');
  assert.match(driver,
    /\$fileName = \(\$normalized -split '\/'\)\[-1\][\s\S]{0,180}Query-Node \$layout \$fileName/,
    'Diff controls are anchored by the filename-first header');
  assert.match(queue, /this\.expanded\(\) \? '收起排队消息' : '展开排队消息'/);
  assert.match(workspace, /this\.moreOpen \? '收起更多' : '展开更多'/);
  assert.match(workspace, /collapsedGroups\.includes\(entry\.workspaceId\) \? '展开工作区 ' : '收起工作区 '/);
});

test('tool disclosure fixtures exercise the distinct structured renderers', () => {
  const fixture = readComponent('NativeDisclosureFixture.ets');
  const expectedFamilies = [
    'read',
    'grep',
    'exec_command',
    'edit',
    'web_search',
    'get_goal',
    'job_output',
    'subagent',
    'present',
    'generated_image',
    'read_image',
    'web_fetch',
    'job_lifecycle',
    'slash_command',
    'ask_user_question',
    'plugin_view',
    'todo_write'
  ];

  for (const family of expectedFamilies) {
    assert.ok(fixture.includes(`'${family}'`), `missing structured fixture family ${family}`);
  }
  assert.match(fixture, /disclosureMiddleVisibleOnlyExpanded/);
  assert.match(fixture, /nestedDisclosureVisibleOnlyExpanded/);
  assert.match(fixture, /background-notice-body-only/);
  assert.match(fixture, /queue-expanded-row-one/);
});
