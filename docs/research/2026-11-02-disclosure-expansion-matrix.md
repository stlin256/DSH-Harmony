# Disclosure expansion coverage research

Date: 2026-11-02

Pinned interaction reference:
[`NATIVE-INTERACTION-SPEC.md`](../NATIVE-INTERACTION-SPEC.md)

Design baseline:
[`2026-11-01-dsh-harmony-design-system.md`](../design/2026-11-01-dsh-harmony-design-system.md)

## Current gap

The existing 68-scene Mock suite proves that top-level screens render. It does
not prove the expanded state of every disclosure:

- The `process` scene force-opens the outer work-process container, but the
  transcript is bottom-anchored. Its final screenshot exposes only the last
  operation preview.
- The Dock driver checks the queue count but does not open a multi-item queue.
- The turn-file-change driver does expand and collapse four files.
- Plan, reasoning, tool and Diff tests are primarily source contracts.

This leaves rendering failures in the body of a disclosure invisible even when
the collapsed header passes.

## Source inventory

| Disclosure | Production owner | Current device proof |
| --- | --- | --- |
| Task plan | `NativeTaskDock.ets` | Collapsed only |
| Work process | `NativeProcessView.ets` | Outer container forced open, incomplete body proof |
| Process operation | `NativeProcessStepView.ets` | No complete matrix |
| Tool call body | `NativeToolCallView.ets` | No complete matrix |
| Nested tool call | `NativeNestedToolRow` in `NativeToolCallView.ets` | Missing |
| Direct reasoning / legacy tool | `NativeMessageView.ets` | Missing |
| Long Diff | `NativeDiffBlock.ets` | Missing |
| Turn file changes | `NativeTurnChangesView.ets` | Expanded four-file pass exists |
| Background notice | `NativeBackgroundNoticeView.ets` | Missing |
| Queue | `NativeQueueDock.ets` | Header only |
| Sidebar More | `NativeWorkspace.ets` | Automatically opened static state only |
| Workspace group | `NativeWorkspace.ets` | No collapse/reopen assertion |

## Structured body families

`NativeToolStructured.ets` validates and projects these body families:

- read and line-numbered code;
- image metadata and media;
- search paths and line matches;
- terminal command, cwd and exit code;
- web sources and answer text;
- goal progress and blocker;
- background job state;
- subagent identity and runs;
- slash command result;
- job lifecycle;
- presented files;
- question and options;
- file edit metadata;
- todo plan;
- generic raw content;
- plugin/DSH UI views.

The manual disclosure matrix must at least exercise the rendering branches that
have distinct layout: code, search, terminal, web, fields, present/plugin,
image metadata and nested operations.

## Risks

1. A compound transcript scrolls to its bottom before capture, hiding expanded
   content.
2. Nested `Scroll` containers can consume the click or hide the bottom of a
   long body.
3. Disclosure IDs that include projection order can move the open state after
   one row is added.
4. Long filesystem paths can displace the filename or hide trailing actions.
5. A fixed expanded height can clip the last line when large fonts are active.
6. Header-only screenshots can pass while arrow direction or accessibility text
   is wrong.

## Decision

Use a Mock-only disclosure workbench that mounts the production components in a
single scrollable surface. Each state opens one disclosure family from a known
header and keeps the rest of the screen stable. The driver captures the
collapsed baseline, clicks the control, asserts expanded-only content, captures
the result and verifies the process remains alive.

The workbench is test infrastructure, not a second product design. It reuses the
real components, semantic tokens and real interaction handlers.
