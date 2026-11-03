/**
 * Content-aware sizing for native tables. Values are display estimates, not
 * font metrics: wide CJK/emoji glyphs count as two half-width units.
 */
function nativeTableWideCode(code: number): boolean {
  return code >= 0x1100 &&
    (code <= 0x115f ||
      code === 0x2329 || code === 0x232a ||
      (code >= 0x2e80 && code <= 0xa4cf) ||
      (code >= 0xac00 && code <= 0xd7a3) ||
      (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xfe10 && code <= 0xfe19) ||
      (code >= 0xfe30 && code <= 0xfe6f) ||
      (code >= 0xff00 && code <= 0xff60) ||
      (code >= 0xffe0 && code <= 0xffe6) ||
      (code >= 0x1f300 && code <= 0x1faff));
}

export function nativeTableTextUnits(value: string): number {
  let widest = 0;
  value.split('\n').forEach((line: string): void => {
    let units = 0;
    for (let index = 0; index < line.length; index++) {
      const code = line.charCodeAt(index);
      if (code >= 0xd800 && code <= 0xdbff) {
        units += 2;
        index++;
      } else if (code === 9) {
        units += 2;
      } else {
        units += nativeTableWideCode(code) ? 2 : 1;
      }
    }
    widest = Math.max(widest, units);
  });
  return widest;
}

export function nativeTableColumnWidth(values: string[],
  minimum: number = 72, maximum: number = 220): number {
  let units = 0;
  values.forEach((value: string): void => {
    units = Math.max(units, nativeTableTextUnits(value));
  });
  const measured = 20 + Math.ceil(units * 6.7);
  return Math.max(minimum, Math.min(maximum, measured));
}

export function nativeAdaptiveTableWidths(headers: string[], rows: string[][],
  minimum: number = 72, maximum: number = 220): number[] {
  const widths: number[] = [];
  for (let column = 0; column < headers.length; column++) {
    const values: string[] = [headers[column] || ''];
    rows.forEach((row: string[]): void => {
      values.push(column < row.length ? row[column] : '');
    });
    widths.push(nativeTableColumnWidth(values, minimum, maximum));
  }
  return widths;
}

export function nativeTableRowNumberWidth(rowCount: number): number {
  const digits = Math.max(1, String(Math.max(1, rowCount)).length);
  return Math.max(52, Math.min(72, 28 + digits * 7));
}
