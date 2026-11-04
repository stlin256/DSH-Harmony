export class NativeUiFixture {
  static readonly screens: string[] = [
    'launch', 'conversation', 'process', 'disclosure', 'sidebar', 'browser', 'preview', 'settings', 'lineage',
    'subagent', 'plugins', 'automation', 'more'
  ];
  static readonly states: string[] = [
    'iteration-notice', 'completed', 'live-change', 'attachments', 'streaming', 'stream-long', 'stream-burst-quiet', 'stream-reconnect', 'subagent-unavailable', 'empty', 'long-history',
    'showcase-plan', 'showcase-process', 'showcase-lineage', 'showcase-dark',
    'showcase-dark-process', 'showcase-subagent', 'showcase-approval',
    'secret-masked', 'stream-repaired', 'document-preview',
    'text-config-preview', 'delimited-preview', 'tsv-preview',
    'delimited-error-preview', 'binary-preview',
    'dock-send-idle', 'dock-queue-pending', 'dock-queue-authoritative',
    'dock-queue-many', 'dock-send-error', 'dock-material-quiet',
    'dock-material-elevated', 'interaction-approval', 'interaction-question',
    'permission-current-read-only', 'permission-current-workspace',
    'permission-current-full', 'permission-current-custom',
    'permission-menu', 'permission-menu-error', 'model-menu', 'permission-full-confirm',
    'permission-full-cancel', 'approval-workspace-once', 'approval-full-once',
    'approval-long-reason', 'approval-submitting', 'approval-ended',
    'approval-disconnected', 'permission-default-setting',
    'plan-subagent', 'plan-subagent-long-count', 'plan-dock-overlay', 'plan-off-error', 'subagent-continuable',
    'subagent-one-shot', 'subagent-unknown', 'subagent-parent-offline',
    'plugins-list', 'plugins-empty', 'plugins-error', 'plugins-detail',
    'plugins-restart', 'plugins-install-failed',
    'automation-list', 'automation-empty', 'automation-detail',
    'automation-editor', 'automation-history', 'automation-conflict',
    'more-actions',
    'disclosure-task-plan',
    'disclosure-process-reasoning', 'disclosure-process-read',
    'disclosure-process-search', 'disclosure-process-terminal',
    'disclosure-process-diff', 'disclosure-process-nested',
    'disclosure-process-malformed', 'disclosure-process-empty',
    'disclosure-process-oversized',
    'disclosure-process-web', 'disclosure-process-goal',
    'disclosure-process-job', 'disclosure-process-subagent',
    'disclosure-process-web-fetch', 'disclosure-process-job-lifecycle',
    'disclosure-process-read-image', 'disclosure-process-command',
    'disclosure-process-present', 'disclosure-process-image',
    'disclosure-process-question', 'disclosure-process-plugin',
    'disclosure-process-plan', 'disclosure-process-order',
    'disclosure-reasoning', 'disclosure-legacy-tool', 'disclosure-diff',
    'disclosure-background-notice', 'disclosure-queue',
    'disclosure-sidebar-more', 'disclosure-sidebar-group'
  ];
  static readonly themes: string[] = ['light', 'dark', 'system'];

  static screen(value: Object | undefined): string {
    return typeof value === 'string' && NativeUiFixture.screens.includes(value) ? value : 'conversation';
  }

  static state(value: Object | undefined): string {
    return typeof value === 'string' && NativeUiFixture.states.includes(value) ? value : 'completed';
  }

  static theme(value: Object | undefined): string {
    return typeof value === 'string' && NativeUiFixture.themes.includes(value) ? value : 'system';
  }
}
