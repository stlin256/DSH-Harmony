/**
 * Repairs only the unfinished Markdown tail while a reply is streaming.
 * Stored text is never changed, and completed input is returned unchanged.
 */
class NativeStreamOpener {
  marker: string = '';
  at: number = 0;
}

class NativeInlineState {
  openCode: number = -1;
  codeRun: number = 0;
  openLinkTarget: number = -1;
  openImage: number = -1;
  dangling: number = -1;
  openers: NativeStreamOpener[] = [];
}

function isSpace(value: string): boolean {
  return value === ' ' || value === '\t' || value === '\n' || value === '\r' ||
    value === '\u00A0' || value === '\u3000';
}

function isPunctuation(value: string): boolean {
  if (!value) return false;
  const code = value.charCodeAt(0);
  if (code < 0x80) return /[!-/:-@\[-`{-~]/.test(value);
  return (code >= 0x3000 && code <= 0x303F) || (code >= 0xFF00 && code <= 0xFF65) ||
    code === 0x2014 || code === 0x2026;
}

function closingRun(text: string, from: number, run: number): number {
  let cursor = from;
  while (cursor < text.length) {
    const close = text.indexOf('`', cursor);
    if (close < 0) return -1;
    let length = 0;
    while (close + length < text.length && text.charAt(close + length) === '`') length++;
    if (length === run) return close;
    cursor = close + length;
  }
  return -1;
}

function addDelimiter(state: NativeInlineState, text: string, index: number, character: string): number {
  let run = 0;
  while (index + run < text.length && text.charAt(index + run) === character) run++;
  const before = index === 0 ? '\n' : text.charAt(index - 1);
  const after = index + run < text.length ? text.charAt(index + run) : '\n';
  const leftFlanking = !isSpace(after) &&
    (!isPunctuation(after) || isSpace(before) || isPunctuation(before));
  const rightFlanking = !isSpace(before) &&
    (!isPunctuation(before) || isSpace(after) || isPunctuation(after));
  let canOpen = leftFlanking;
  let canClose = rightFlanking;
  if (character === '_') {
    canOpen = leftFlanking && (!rightFlanking || isPunctuation(before));
    canClose = rightFlanking && (!leftFlanking || isPunctuation(after));
  }
  const markers: string[] = [];
  if (character === '~' && run === 2) {
    markers.push('~~');
  } else if (character !== '~' && run === 1) {
    markers.push(character);
  } else if (character !== '~' && run === 2) {
    markers.push(character + character);
  } else if (character !== '~' && run >= 3) {
    markers.push(character + character, character);
  }
  let used = false;
  markers.forEach((marker: string): void => {
    let open = -1;
    if (canClose) {
      for (let index = state.openers.length - 1; index >= 0; index--) {
        if (state.openers[index].marker === marker) {
          open = index;
          break;
        }
      }
    }
    if (open >= 0) {
      state.openers.splice(open, state.openers.length - open);
      used = true;
    } else if (canOpen) {
      const opener = new NativeStreamOpener();
      opener.marker = marker;
      opener.at = index;
      state.openers.push(opener);
      used = true;
    }
  });
  if (!used && text.substring(index + run).trim().length === 0) state.dangling = index;
  return index + run;
}

function scanInline(text: string): NativeInlineState {
  const state = new NativeInlineState();
  const brackets: number[] = [];
  let index = 0;
  while (index < text.length) {
    const character = text.charAt(index);
    if (character === '\\' && index + 1 < text.length) {
      index += 2;
      continue;
    }
    if (character === '`') {
      let run = 0;
      while (index + run < text.length && text.charAt(index + run) === '`') run++;
      const close = closingRun(text, index + run, run);
      if (close < 0) {
        state.openCode = index;
        state.codeRun = run;
        break;
      }
      index = close + run;
      continue;
    }
    if (character === '*' || character === '_' || character === '~') {
      index = addDelimiter(state, text, index, character);
      continue;
    }
    if (character === '[') {
      brackets.push(index);
    } else if (character === ']' && brackets.length) {
      const label = brackets[brackets.length - 1];
      brackets.pop();
      if (index + 1 < text.length && text.charAt(index + 1) === '(') {
        const close = text.indexOf(')', index + 2);
        const line = text.indexOf('\n', index + 2);
        if (close < 0 || (line >= 0 && line < close)) {
          if (label > 0 && text.charAt(label - 1) === '!') state.openImage = label - 1;
          else state.openLinkTarget = index + 1;
          break;
        }
        index = close + 1;
        continue;
      }
    }
    index++;
  }
  brackets.forEach((value: number): void => {
    if (value > 0 && text.charAt(value - 1) === '!') {
      if (state.openImage < 0 || value - 1 < state.openImage) state.openImage = value - 1;
    }
  });
  return state;
}

function inlineCut(text: string, state: NativeInlineState): number {
  let at = text.length;
  if (state.dangling >= 0 && state.dangling < at) at = state.dangling;
  if (state.openImage >= 0 && state.openImage < at) at = state.openImage;
  if (state.openCode >= 0 && state.openCode < at &&
    text.substring(state.openCode + state.codeRun).trim().length === 0) {
    at = state.openCode;
  }
  const scanned = state.openCode >= 0 ? state.openCode :
    state.openLinkTarget >= 0 ? state.openLinkTarget : at;
  const tag = /<[A-Za-z/!][^<>\n]*$/.exec(text.substring(0, Math.min(scanned, at)));
  if (tag && tag.index < at) at = tag.index;
  state.openers.forEach((opener: NativeStreamOpener): void => {
    if (opener.at < at && text.substring(opener.at + opener.marker.length, at).trim().length === 0) {
      at = Math.min(at, opener.at);
    }
  });
  return at;
}

function repairInline(tail: string): string {
  let text = tail;
  let state = scanInline(text);
  for (let guard = 0; guard < 8; guard++) {
    const cut = inlineCut(text, state);
    if (cut >= text.length) break;
    text = text.substring(0, cut).trimEnd();
    state = scanInline(text);
  }
  if (state.openLinkTarget >= 0) {
    text = text.substring(0, state.openLinkTarget) + '(#)';
  }
  if (state.openCode < 0 && state.openers.length === 0) return text;
  let output = text.trimEnd();
  if (state.openCode >= 0) {
    for (let index = 0; index < state.codeRun; index++) output += '`';
  }
  for (let index = state.openers.length - 1; index >= 0; index--) {
    output += state.openers[index].marker;
  }
  return output;
}

function partialLine(line: string): boolean {
  return /^[ \t]*(?:>[ \t]?)*[ \t]*(?:#{1,6}|[-*+]|\d{1,9}[.)]|=+|-{2}|_{1,2}|\*{2}|`{1,2}|~{1,2}|>|\${1,2})?[ \t]*$/.test(line);
}

function dropPartialLastLine(tail: string): string {
  const line = tail.lastIndexOf('\n');
  const last = tail.substring(line + 1);
  if (!last || !partialLine(last)) return tail;
  return line < 0 ? '' : tail.substring(0, line);
}

function tableCells(line: string): string[] {
  let value = line.trim().replace(/^(?:>[ \t]?)*/, '').trim();
  if (value.startsWith('|')) value = value.substring(1);
  if (value.endsWith('|') && !value.endsWith('\\|')) value = value.substring(0, value.length - 1);
  if (!value.trim()) return [];
  return value.split(/(?<!\\)\|/);
}

function delimiterCell(value: string): boolean {
  return /^\s*:?-{3,}:?\s*$/.test(value);
}

function unfinishedTableAt(tail: string): number {
  const clean = tail.replace(/\n+$/, '');
  const lines = clean.split('\n');
  let first = lines.length;
  while (first > 0 && /^[ \t]*(?:>[ \t]?)*[ \t]*\|/.test(lines[first - 1])) first--;
  if (first === lines.length && first > 0 &&
    /^[ \t]*(?:>[ \t]?)*[ \t]*:?-/.test(lines[lines.length - 1])) {
    first--;
    while (first > 0 && /^[ \t]*(?:>[ \t]?)*[ \t]*\|/.test(lines[first - 1])) first--;
  }
  if (first >= lines.length || !/^[ \t]*(?:>[ \t]?)*[ \t]*\|/.test(lines[first])) return -1;
  let offset = 0;
  for (let index = 0; index < first; index++) offset += lines[index].length + 1;
  if (first + 1 >= lines.length) return offset;
  const header = tableCells(lines[first]);
  const delimiter = tableCells(lines[first + 1]);
  if (delimiter.length < header.length ||
    !delimiter.every((value: string): boolean => delimiterCell(value))) {
    return offset;
  }
  return -1;
}

function repairTail(text: string, tail: string): string {
  let value = tail;
  const table = unfinishedTableAt(value);
  if (table >= 0) value = value.substring(0, table).trimEnd();
  value = dropPartialLastLine(value);
  value = repairInline(value);
  return value.trim().length === 0 ? '' : value;
}

export function nativeRepairStreamingMarkdown(text: string): string {
  if (!text) return text;
  const lines = text.split('\n');
  let offset = 0;
  let lastBlockStart = 0;
  let openFenceCharacter = '';
  let openFenceLength = 0;
  let openFenceLineStart = -1;
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    const trim = line.trim();
    if (openFenceCharacter) {
      const close = /^[ \t]*(?:>[ \t]?)*[ \t]*(`{3,}|~{3,})[ \t]*$/.exec(line);
      if (close && close[1].charAt(0) === openFenceCharacter &&
        close[1].length >= openFenceLength) {
        openFenceCharacter = '';
        openFenceLength = 0;
        openFenceLineStart = -1;
        lastBlockStart = offset + line.length + 1;
      }
    } else {
      const fence = /^[ \t]*(?:>[ \t]?)*[ \t]*(`{3,}|~{3,})(.*)$/.exec(line);
      if (fence) {
        openFenceCharacter = fence[1].charAt(0);
        openFenceLength = fence[1].length;
        openFenceLineStart = offset;
      } else if (!trim) {
        lastBlockStart = offset + line.length + 1;
      }
    }
    offset += line.length + 1;
  }
  if (openFenceCharacter) {
    if (text.indexOf('\n', openFenceLineStart) < 0) {
      return text.substring(0, openFenceLineStart).trimEnd();
    }
    return text;
  }
  if (lastBlockStart > text.length) lastBlockStart = text.length;
  const head = text.substring(0, lastBlockStart);
  const tail = text.substring(lastBlockStart);
  const repaired = repairTail(text, tail);
  if (!repaired.trim()) return head.trimEnd();
  return head + repaired;
}
