import { NativeMessage } from './NativeSessionModel';

export const NATIVE_DSH_UI_REPLY_MARKER: string = '[dsh-ui reply]';

export class NativeDshUiReply {
  kind: string = 'other';
  title: string = '';
  value: string = '';
  text: string = '';
  label: string = '';
}

function flattenTitle(value: string): string {
  return (value || '').replace(/\s*[\r\n]+\s*/g, ' ').trim();
}

function heading(title: string): string {
  const clean = flattenTitle(title);
  return clean ? NATIVE_DSH_UI_REPLY_MARKER + ' ' + clean : NATIVE_DSH_UI_REPLY_MARKER;
}

export function nativeDshUiChoiceReply(title: string, labels: string[]): string {
  const visible = labels.map((label: string): string => flattenTitle(label))
    .filter((label: string): boolean => !!label);
  if (!visible.length) return '';
  return heading(title) + '\n选择：' + visible.join('、');
}

export function nativeDshUiConfirmReply(title: string, confirmed: boolean,
  visibleLabel: string = ''): string {
  const label = flattenTitle(visibleLabel);
  const defaultLabel = confirmed ? '确认' : '取消';
  const verb = confirmed ? '确认' : '取消';
  return heading(title) + '\n' + verb + (label && label !== defaultLabel ? '：' + label : '');
}

export function nativeDshUiReply(source: string): NativeDshUiReply | null {
  const lines = (source || '').trimStart().split(/\r?\n/);
  if (!lines.length) return null;
  const head = lines[0].trim();
  if (!head.startsWith(NATIVE_DSH_UI_REPLY_MARKER)) return null;
  const result = new NativeDshUiReply();
  result.title = flattenTitle(head.slice(NATIVE_DSH_UI_REPLY_MARKER.length));
  let body = '';
  for (let index = 1; index < lines.length; index++) {
    const value = lines[index].trim();
    if (value) {
      body = value;
      break;
    }
  }
  const match = /^(选择|确认|取消|Select|Confirm|Cancel)\s*(?:[：:]\s*(.*))?$/.exec(body);
  if (!match) {
    result.value = flattenTitle(body);
    result.text = body ? head + '\n' + body : head;
    result.label = result.value || '已回复';
    return result;
  }
  const verb = match[1];
  result.value = flattenTitle(match[2] || '');
  result.text = body ? head + '\n' + body : head;
  if (verb === '选择' || verb === 'Select') {
    result.kind = 'choice';
    result.label = '已选择' + (result.value ? '：' + result.value : '');
  } else if (verb === '确认' || verb === 'Confirm') {
    result.kind = 'confirm';
    result.label = result.value ? '已确认：' + result.value : '已确认';
  } else {
    result.kind = 'cancel';
    result.label = result.value ? '已取消：' + result.value : '已取消';
  }
  return result;
}

export function nativeDshUiReplyLabel(source: string): string {
  const reply = nativeDshUiReply(source);
  return reply ? reply.label : '';
}

export function nativeDshUiCanReply(rows: NativeMessage[], messageId: string,
  running: boolean, waiting: boolean): boolean {
  if (running || waiting || !messageId) return false;
  const index = rows.findIndex((row: NativeMessage): boolean => row.id === messageId);
  if (index < 0) return false;
  for (let cursor = index + 1; cursor < rows.length; cursor++) {
    const row = rows[cursor];
    if (row.role === 'user') return false;
    if (row.role === 'assistant' && !!row.text.trim()) return false;
  }
  return true;
}
