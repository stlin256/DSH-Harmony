export class NativeUiFixture {
  static readonly screens: string[] = [
    'conversation', 'process', 'sidebar', 'browser', 'settings', 'lineage', 'subagent'
  ];
  static readonly states: string[] = [
    'completed', 'live-change', 'attachments', 'streaming', 'empty', 'long-history',
    'dock-send-idle', 'dock-queue-pending', 'dock-queue-authoritative',
    'dock-queue-many', 'dock-send-error', 'dock-material-quiet',
    'dock-material-elevated', 'interaction-approval', 'interaction-question',
    'plan-subagent', 'plan-off-error', 'subagent-continuable',
    'subagent-one-shot', 'subagent-unknown', 'subagent-parent-offline'
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
