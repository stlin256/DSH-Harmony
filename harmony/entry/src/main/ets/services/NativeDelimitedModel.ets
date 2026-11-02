export class NativeDelimitedTable {
  rows: string[][] = [];
  columnCount: number = 0;
  truncatedRows: boolean = false;
  truncatedColumns: boolean = false;
  truncatedCells: boolean = false;
  incomplete: boolean = false;
  error: string = '';
}

class NativeDelimitedParser {
  private result: NativeDelimitedTable = new NativeDelimitedTable();
  private text: string = '';
  private delimiter: string = ',';
  private rowLimit: number = 200;
  private columnLimit: number = 32;
  private cellLimit: number = 4096;
  private allowIncomplete: boolean = false;
  private row: string[] = [];
  private value: string = '';
  private quoted: boolean = false;
  private closedQuote: boolean = false;
  private rowStarted: boolean = false;
  private index: number = 0;

  constructor(source: string, format: string, maxRows: number, maxColumns: number,
    maxCellCharacters: number, allowIncomplete: boolean) {
    this.text = source && source.charCodeAt(0) === 0xFEFF ? source.slice(1) : source;
    this.delimiter = format.toLowerCase() === 'tsv' ? '\t' : ',';
    this.rowLimit = Math.max(1, Math.floor(maxRows));
    this.columnLimit = Math.max(1, Math.floor(maxColumns));
    this.cellLimit = Math.max(1, Math.floor(maxCellCharacters));
    this.allowIncomplete = allowIncomplete;
  }

  private appendCharacter(character: string): void {
    this.rowStarted = true;
    if (this.value.length < this.cellLimit) this.value += character;
    else this.result.truncatedCells = true;
  }

  private appendField(): void {
    if (this.row.length < this.columnLimit) this.row.push(this.value);
    else this.result.truncatedColumns = true;
    this.value = '';
    this.closedQuote = false;
    this.rowStarted = true;
  }

  private appendRow(): boolean {
    this.appendField();
    this.result.columnCount = Math.max(this.result.columnCount, this.row.length);
    if (this.result.rows.length >= this.rowLimit) {
      this.result.truncatedRows = true;
      return false;
    }
    this.result.rows.push(this.row);
    this.row = [];
    this.rowStarted = false;
    return true;
  }

  private parseQuoted(character: string): void {
    if (character === '"') {
      if (this.text.charAt(this.index + 1) === '"') {
        this.appendCharacter('"');
        this.index += 2;
      } else {
        this.quoted = false;
        this.closedQuote = true;
        this.index++;
      }
    } else if (character === '\r' || character === '\n') {
      this.appendCharacter('\n');
      this.index += character === '\r' && this.text.charAt(this.index + 1) === '\n' ? 2 : 1;
    } else {
      this.appendCharacter(character);
      this.index++;
    }
  }

  private parseClosedQuote(character: string): void {
    if (character === this.delimiter) {
      this.appendField();
      this.index++;
    } else if (character === '\r' || character === '\n') {
      this.index += character === '\r' && this.text.charAt(this.index + 1) === '\n' ? 2 : 1;
      this.appendRow();
    } else if (character === ' ' || (character === '\t' && this.delimiter === ',')) {
      this.index++;
    } else {
      this.result.error = '表格中存在无法解析的引号';
    }
  }

  private parseUnquoted(character: string): void {
    if (character === '"') {
      if (this.value.length === 0) {
        this.quoted = true;
        this.rowStarted = true;
        this.index++;
      } else {
        this.result.error = '表格中存在无法解析的引号';
      }
    } else if (character === this.delimiter) {
      this.appendField();
      this.index++;
    } else if (character === '\r' || character === '\n') {
      this.index += character === '\r' && this.text.charAt(this.index + 1) === '\n' ? 2 : 1;
      this.appendRow();
    } else {
      this.appendCharacter(character);
      this.index++;
    }
  }

  parse(): NativeDelimitedTable {
    if (!this.text.length) return this.result;
    while (this.index < this.text.length && !this.result.error && !this.result.truncatedRows) {
      const character = this.text.charAt(this.index);
      if (this.quoted) this.parseQuoted(character);
      else if (this.closedQuote) this.parseClosedQuote(character);
      else this.parseUnquoted(character);
    }
    if (this.result.error || this.result.truncatedRows) return this.result;
    if (this.quoted) {
      this.result.incomplete = this.allowIncomplete;
      if (!this.allowIncomplete) this.result.error = '表格包含未闭合的引号';
      return this.result;
    }
    if (this.rowStarted || this.value.length > 0 || this.row.length > 0) this.appendRow();
    return this.result;
  }
}

/**
 * Project a bounded RFC 4180 table from a text page. The retained source is
 * never modified; only presentation cells are limited.
 */
export function nativeDelimitedTable(source: string, format: string,
  maxRows: number = 200, maxColumns: number = 32, maxCellCharacters: number = 4096,
  allowIncomplete: boolean = false): NativeDelimitedTable {
  return new NativeDelimitedParser(source, format, maxRows, maxColumns,
    maxCellCharacters, allowIncomplete).parse();
}
