import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);

function load(name) {
  const source = readFileSync(new URL(name + '.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS
    }
  });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, {
    module,
    exports: module.exports,
    console,
    require: id => {
      if (!id.startsWith('./') || !existsSync(new URL(id.slice(2) + '.ets', services))) {
        throw Error('Unexpected dependency: ' + id);
      }
      return load(id.slice(2));
    }
  });
  return module.exports;
}

const model = load('NativeSessionModel');
const structured = load('NativeToolStructured');

function tool(name, args = {}, fields = {}) {
  return Object.assign(new model.NativeMessage(), {
    id: fields.id || 'call-' + name,
    callId: fields.callId || fields.id || 'call-' + name,
    role: 'tool',
    toolName: name,
    phase: fields.phase || 'result',
    status: fields.status || 'success',
    args: JSON.stringify(args),
    metaRaw: fields.metaRaw || '',
    output: fields.output || '',
    error: fields.error || '',
    failed: fields.failed === true,
    outcome: fields.outcome || '',
    images: fields.images || []
  });
}

test('read parses a strict ordered metadata window and workspace-relative path', () => {
  const view = structured.nativeToolStructured(tool('read', {
    file_path: '/workspace/project/src/app.ts',
    offset: 4,
    limit: 3
  }, {
    metaRaw: JSON.stringify({
      path: '/workspace/project/src/app.ts',
      offset: 4,
      totalLines: 120,
      lang: 'typescript',
      lines: [
        { number: 4, text: 'const a = 1;' },
        { number: 5, text: '' },
        { number: 6, text: 'export { a };' }
      ]
    })
  }), '/workspace/project');

  assert.equal(view.family, 'read');
  assert.equal(view.displayPath, 'src/app.ts');
  assert.equal(view.summary, 'src/app.ts');
  assert.equal(view.read.valid, true);
  assert.equal(view.read.offset, 4);
  assert.equal(view.read.limit, 3);
  assert.equal(view.read.totalLines, 120);
  assert.equal(view.read.language, 'typescript');
  assert.deepEqual(Array.from(view.read.lines, line => [line.number, line.text]), [
    [4, 'const a = 1;'],
    [5, ''],
    [6, 'export { a };']
  ]);
  assert.equal(view.showRawOutput, false);
});

test('read rejects malformed line records and falls back to one bounded numbered run', () => {
  const malformed = structured.nativeToolStructured(tool('read', {
    path: 'src/error.ts'
  }, {
    metaRaw: JSON.stringify({
      lines: [
        { number: 1, text: 'ok' },
        { number: 2 }
      ]
    }),
    output: '1: first\n2: second\nnot numbered'
  }), '/workspace/project');
  assert.equal(malformed.read.valid, true);
  assert.deepEqual(Array.from(malformed.read.lines, line => line.text), ['first', 'second']);

  const brokenRun = structured.nativeToolStructured(tool('read', {
    path: 'src/error.ts'
  }, {
    output: '1: first\n3: skipped\n'
  }), '/workspace/project');
  assert.equal(brokenRun.read.valid, false);
  assert.equal(brokenRun.bodyStructured, false);
  assert.equal(brokenRun.showRawOutput, true);
});

test('search validates path and match metadata without inventing partial results', () => {
  const matches = structured.nativeToolStructured(tool('grep', {
    pattern: 'TODO',
    path: '/workspace/project/src',
    include: '*.ts'
  }, {
    metaRaw: JSON.stringify({
      total: 2,
      matches: [
        {
          path: '/workspace/project/src/a.ts',
          matches: [{ lineNumber: 8, line: '// TODO one' }]
        },
        {
          path: '/workspace/project/src/b.ts',
          matches: [{ lineNumber: 12, line: '// TODO two' }]
        }
      ]
    })
  }), '/workspace/project');
  assert.equal(matches.family, 'search');
  assert.equal(matches.search.valid, true);
  assert.equal(matches.search.total, 2);
  assert.deepEqual(Array.from(matches.search.files, file => file.display),
    ['src/a.ts', 'src/b.ts']);
  assert.equal(matches.showRawOutput, false);

  const invalid = structured.nativeToolStructured(tool('grep', {
    pattern: 'TODO'
  }, {
    metaRaw: JSON.stringify({
      matches: [
        { path: 'src/a.ts', matches: [{ lineNumber: 8, line: 'valid' }] },
        { path: 'src/b.ts', matches: [{ lineNumber: 0, line: 'invalid' }] }
      ]
    }),
    output: 'complete raw result'
  }));
  assert.equal(invalid.search.valid, false);
  assert.equal(invalid.showRawOutput, true);

  const paths = structured.nativeToolStructured(tool('glob', {
    pattern: '**/*.ets',
    path: '/workspace/project'
  }, {
    metaRaw: JSON.stringify({
      paths: ['/workspace/project/src/a.ets', '/workspace/project/src/b.ets']
    })
  }), '/workspace/project');
  assert.deepEqual(Array.from(paths.search.paths, file => file.display),
    ['src/a.ets', 'src/b.ets']);
});

test('terminal parses arguments, background state and settled process facts', () => {
  const finished = structured.nativeToolStructured(tool('bash', {
    command: 'npm test',
    workdir: '/workspace/project',
    timeoutMs: 45000
  }, {
    metaRaw: JSON.stringify({
      cwd: '/workspace/project/packages/app',
      exitCode: 1,
      signal: 'SIGTERM',
      truncated: true
    }),
    output: 'complete output'
  }), '/workspace/project');
  assert.equal(finished.family, 'terminal');
  assert.equal(finished.summary, 'npm test');
  assert.equal(finished.fields.find(field => field.label === '目录').value, 'packages/app');
  assert.equal(finished.fields.find(field => field.label === '超时').value, '45 秒');
  assert.equal(finished.fields.find(field => field.label === '退出码').tone, 'danger');
  assert.equal(finished.fields.find(field => field.label === '信号').value, 'SIGTERM');
  assert.equal(finished.showRawOutput, true);

  const background = structured.nativeToolStructured(tool('exec_command', {
    cmd: 'npm run dev',
    run_in_background: true
  }), '/workspace/project');
  assert.equal(background.fields.find(field => field.label === '状态').value,
    '已启动后台任务');
  assert.equal(background.fields.some(field => field.label === '退出码'), false);
});

test('web and source facts accept only strict HTTP(S) URLs and fixed status shapes', () => {
  const search = structured.nativeToolStructured(tool('web_search', {
    queries: ['harmony os', 'arkui']
  }, {
    metaRaw: JSON.stringify({
      truncated: true,
      answer: 'answer',
      sources: [{
        url: 'https://example.com/a',
        title: 'Example',
        snippet: 'Snippet',
        publishedAt: '2026-11-01'
      }]
    })
  }));
  assert.equal(search.family, 'web');
  assert.equal(search.summary, 'harmony os, arkui');
  assert.equal(search.sources.length, 1);
  assert.equal(search.sources[0].title, 'Example');
  assert.equal(search.fields.find(field => field.label === '状态').value, '结果已截断');

  const invalid = structured.nativeToolStructured(tool('web_search', {
    query: 'query'
  }, {
    metaRaw: JSON.stringify({
      sources: [{ url: 'javascript:alert(1)', title: 'bad' }]
    }),
    output: 'raw search output'
  }));
  assert.equal(invalid.sources.length, 0);
  assert.equal(invalid.showRawOutput, true);

  const fetch = structured.nativeToolStructured(tool('web_fetch', {
    url: 'https://example.com'
  }, {
    metaRaw: JSON.stringify({
      url: 'https://example.com/result',
      statusCode: 404
    })
  }));
  assert.equal(fetch.fields.find(field => field.label === 'HTTP').tone, 'danger');
  assert.equal(fetch.fields.find(field => field.label === '地址').value,
    'https://example.com/result');
});

test('read_image exposes only authoritative attachment facts', () => {
  const view = structured.nativeToolStructured(tool('read_image', {
    file_path: '/workspace/project/assets/preview.webp'
  }, {
    images: [{
      attachmentId: 'image-a',
      mediaType: 'image/webp',
      bytes: 2048,
      width: 1280,
      height: 720,
      name: 'preview.webp'
    }]
  }), '/workspace/project');
  assert.equal(view.family, 'image');
  assert.equal(view.displayPath, 'assets/preview.webp');
  assert.equal(view.bodyStructured, true);
  assert.equal(view.image.count, 1);
  assert.equal(view.image.mediaType, 'image/webp');
  assert.equal(view.image.width, 1280);
  assert.equal(view.image.height, 720);
  assert.equal(view.image.bytes, 2048);
  assert.equal(view.showRawOutput, false);

  const failed = structured.nativeToolStructured(tool('read_image', {
    file_path: 'assets/preview.webp'
  }, {
    failed: true,
    status: 'error',
    images: [{ mediaType: 'image/webp', bytes: 2048, width: 1280, height: 720 }]
  }));
  assert.equal(failed.bodyStructured, false);
  assert.equal(failed.image.count, 0);
});

test('goal, job and agent families expose known stable facts', () => {
  const goal = structured.nativeToolStructured(tool('get_goal', {}, {
    output: JSON.stringify({
      goal: {
        objective: 'Ship parser',
        phase: 'running',
        blockedReason: 'Review',
        roundsStarted: 2,
        maxGoalRounds: 5,
        ref: { revision: 7 }
      },
      roundsStarted: 3
    })
  }));
  assert.equal(goal.family, 'goal');
  assert.equal(goal.summary, 'Ship parser');
  assert.equal(goal.fields.find(field => field.label === '轮次').value, '3 / 5');
  assert.equal(goal.fields.find(field => field.label === '修订').value, '7');

  const job = structured.nativeToolStructured(tool('job_output', {
    job_id: 'job-7'
  }, {
    metaRaw: JSON.stringify({
      state: 'failed',
      command: 'pnpm test',
      exitCode: 2
    })
  }));
  assert.equal(job.summary, 'job-7');
  assert.equal(job.fields.find(field => field.label === '状态').value, 'failed');
  assert.equal(job.fields.find(field => field.label === '退出码').value, '2');

  const agent = structured.nativeToolStructured(tool('subagent', {
    description: 'Audit parser'
  }, {
    metaRaw: JSON.stringify({ subagentId: 'agent-4', state: 'running' })
  }));
  assert.equal(agent.summary, 'Audit parser');
  assert.equal(agent.fields.find(field => field.label === '子代理').value, 'agent-4');

  const workflow = structured.nativeToolStructured(tool('workflow', {
    name: 'review',
    description: 'Review all surfaces'
  }, {
    metaRaw: JSON.stringify({ state: 'running', runs: 4 })
  }));
  assert.equal(workflow.summary, 'Review all surfaces');
  assert.equal(workflow.fields.find(field => field.label === '名称').value, 'review');
  assert.equal(workflow.fields.find(field => field.label === '运行').value, '4');
});

test('present keeps valid declarations in order and resolves display independently', () => {
  const view = structured.nativeToolStructured(tool('present', {
    files: [
      {
        path: '/workspace/project/artifacts/report.pdf',
        description: 'Final report'
      },
      { path: '' },
      {
        path: '/workspace/project/src/main.ets',
        description: 'Source'
      }
    ]
  }), '/workspace/project');
  assert.equal(view.family, 'present');
  assert.equal(view.parsed, true);
  assert.deepEqual(Array.from(view.presented, file => ({
    path: file.path,
    display: file.display,
    name: file.name,
    description: file.description
  })), [{
    path: '/workspace/project/artifacts/report.pdf',
    display: 'artifacts/report.pdf',
    name: 'report.pdf',
    description: 'Final report'
  }, {
    path: '/workspace/project/src/main.ets',
    display: 'src/main.ets',
    name: 'main.ets',
    description: 'Source'
  }]);
  assert.equal(view.summary, 'report.pdf、main.ets');
});

test('failed success-shaped metadata never claims completion facts', () => {
  const view = structured.nativeToolStructured(tool('grep', {
    pattern: 'secret'
  }, {
    status: 'error',
    failed: true,
    outcome: 'failed',
    metaRaw: JSON.stringify({
      matches: [{ path: 'src/a.ts', matches: [{ lineNumber: 1, line: 'secret' }] }]
    }),
    output: 'AUTO_REVIEW_DENIED'
  }));
  assert.equal(view.search.valid, false);
  assert.equal(view.bodyStructured, false);
  assert.equal(view.showRawArguments, true);
  assert.equal(view.showRawOutput, true);
});

test('group summary de-duplicates successful paths and retains failures separately', () => {
  const summary = structured.nativeToolGroupSummary([
    tool('read', { path: 'src/a.ts' }),
    tool('read', { path: 'src/a.ts' }, { id: 'call-read-2' }),
    tool('edit', { path: 'src/a.ts', oldText: 'a', newText: 'b' }),
    tool('edit', { path: 'src/b.ts', oldText: 'a', newText: 'b' }, {
      id: 'call-edit-failed',
      status: 'error',
      failed: true,
      outcome: 'failed'
    }),
    tool('bash', { command: 'npm test' }),
    tool('web_search', { query: 'harmony' })
  ]);
  assert.equal(summary.total, 6);
  assert.equal(summary.readFiles, 1);
  assert.equal(summary.editedFiles, 1);
  assert.equal(summary.failed, 1);
  assert.match(summary.label, /执行 1 条命令/);
  assert.match(summary.label, /修改 1 个文件/);
  assert.match(summary.label, /读取 1 个文件/);
  assert.match(summary.label, /1 失败/);
});

test('generic tools preserve malformed arguments and result output', () => {
  const view = structured.nativeToolStructured(Object.assign(tool('custom_tool', {}, {
    output: 'complete result'
  }), {
    args: '{"title":"partial"'
  }));
  assert.equal(view.family, 'generic');
  assert.equal(view.parsed, true);
  assert.equal(view.summary, 'partial');
  assert.equal(view.showRawArguments, true);
  assert.equal(view.showRawOutput, true);

  const completeButMalformed = structured.nativeToolStructured(Object.assign(tool('read', {}, {
    output: 'complete result'
  }), {
    args: '{"path":"src/a.ts"} trailing'
  }));
  assert.equal(completeButMalformed.family, 'read');
  assert.equal(completeButMalformed.bodyStructured, false);
  assert.equal(completeButMalformed.parsed, true);
  assert.notEqual(completeButMalformed.summary, 'src/a.ts',
    'closed-looking scalar fragments must not be recovered from malformed complete JSON');
});

