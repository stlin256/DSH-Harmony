function formatValue(value: Object, depth: number): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) {
    const rows = (value as Object[]).map((item: Object, index: number): string => {
      const text = formatValue(item, depth + 1);
      if (!text) return '';
      return typeof item === 'object' && !Array.isArray(item) ?
        (index + 1).toString() + '. ' + text.replace(/\n/g, '\n   ') : text;
    }).filter((text: string): boolean => !!text);
    return rows.join('\n');
  }
  const record = value as Record<string, Object>;
  const rows: string[] = [];
  Object.keys(record).forEach((key: string): void => {
    const item = record[key];
    if (item === null || item === undefined || item === '') return;
    const text = formatValue(item, depth + 1);
    if (!text) return;
    rows.push(typeof item === 'object' && !Array.isArray(item) ?
      key + ':\n  ' + text.replace(/\n/g, '\n  ') : key + ': ' + text.replace(/\n/g, ' · '));
  });
  return rows.join(depth === 0 ? '\n' : '\n');
}

/**
 * Convert a complete JSON-looking payload into readable native text. Ordinary
 * prose and fenced examples are returned unchanged.
 */
export function nativeStructuredText(value: string): string {
  const text = (value || '').trim();
  if (!text || !/^[\[{]/.test(text)) return value || '';
  try {
    const parsed = JSON.parse(text) as Object;
    const formatted = formatValue(parsed, 0).trim();
    if (formatted) return formatted.slice(0, 16384);
  } catch (_) {}
  return value || '';
}
