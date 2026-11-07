import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import {
  NativeDirectoryEntry,
  NativeDirectoryListing,
  NativeFilePage
} from './NativeHarnessClient';
import {
  NativeStorageCandidate,
  NativeStorageOwner
} from './NativeStorageBudget';

const directoryProtocol: number = 1;
const textProtocol: number = 1;
const metadataQuota: number = 512 * 1024 * 1024;
const binaryQuota: number = 2 * 1024 * 1024 * 1024;
const binaryFileLimit: number = 64 * 1024 * 1024;
const textCacheLimit: number = 2 * 1024 * 1024;

function feedHash(text: string, first: number, second: number): number[] {
  let left = first;
  let right = second;
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    left = Math.imul(left ^ code, 16777619);
    right = Math.imul(right, 33) ^ code;
  }
  return [left >>> 0, right >>> 0];
}

export function textHash(value: string): string {
  const valueHash = feedHash(value, 2166136261, 5381);
  return valueHash[0].toString(16) + ':' + valueHash[1].toString(16) +
    ':' + value.length.toString(16);
}

function byteHash(value: Uint8Array): string {
  let left = 2166136261;
  let right = 5381;
  for (let index = 0; index < value.byteLength; index++) {
    const code = value[index];
    left = Math.imul(left ^ code, 16777619);
    right = Math.imul(right, 33) ^ code;
  }
  return (left >>> 0).toString(16) + ':' + (right >>> 0).toString(16) +
    ':' + value.byteLength.toString(16);
}

function byteEstimate(value: string): number {
  return value.length * 2;
}

export function nativeWorkspaceScopeId(scope: string): string {
  return textHash(scope);
}

/** Stable, order-independent metadata fingerprint for a directory response. */
export function nativeDirectoryFingerprint(entries: NativeDirectoryEntry[],
  truncated: boolean): string {
  const normalized = entries.map((entry: NativeDirectoryEntry): NativeDirectoryEntry => {
    const value = new NativeDirectoryEntry();
    value.name = entry.name;
    value.type = entry.type;
    value.size = entry.size === undefined ? -1 : entry.size;
    return value;
  });
  normalized.sort((left: NativeDirectoryEntry, right: NativeDirectoryEntry): number => {
    const leftKey = left.name + '\n' + left.type + '\n' + String(left.size);
    const rightKey = right.name + '\n' + right.type + '\n' + String(right.size);
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  let payload = truncated ? '1\n' : '0\n';
  normalized.forEach((entry: NativeDirectoryEntry): void => {
    payload += entry.name.length.toString(16) + ':' + entry.name + '\n' +
      entry.type + '\n' + String(entry.size) + '\n';
  });
  return textHash(payload);
}

function validDirectoryEntry(entry: NativeDirectoryEntry): boolean {
  return !!entry && typeof entry.name === 'string' && !!entry.name &&
    entry.name.length <= 255 &&
    (entry.type === 'file' || entry.type === 'directory' || entry.type === 'other') &&
    (entry.size === undefined || Number.isSafeInteger(entry.size) && entry.size >= -1);
}

export class NativeWorkspaceCachedDirectory {
  protocol: number = directoryProtocol;
  listing: NativeDirectoryListing = new NativeDirectoryListing();
  fingerprint: string = '';
  savedAt: number = 0;
}

export function nativeValidWorkspaceDirectoryCache(
  value: NativeWorkspaceCachedDirectory): boolean {
  if (!value || value.protocol !== directoryProtocol || !value.listing ||
    typeof value.listing.path !== 'string' || !Array.isArray(value.listing.entries) ||
    typeof value.listing.truncated !== 'boolean' ||
    !Number.isFinite(value.savedAt) || value.savedAt <= 0 ||
    !value.fingerprint) return false;
  if (!value.listing.entries.every((entry: NativeDirectoryEntry): boolean =>
    validDirectoryEntry(entry))) return false;
  return value.fingerprint === nativeDirectoryFingerprint(
    value.listing.entries, value.listing.truncated);
}

export class NativeWorkspaceCachedText {
  protocol: number = textProtocol;
  page: NativeFilePage = new NativeFilePage();
  checksum: string = '';
  savedAt: number = 0;
}

export function nativeWorkspaceTextChecksum(page: NativeFilePage): string {
  return textHash(page.absolutePath + '\n' + page.version + '\n' +
    String(page.offset) + '\n' + String(page.lines) + '\n' +
    String(page.eof) + '\n' + page.text);
}

export function nativeValidWorkspaceTextCache(value: NativeWorkspaceCachedText): boolean {
  if (!value || value.protocol !== textProtocol || !value.page ||
    typeof value.page.absolutePath !== 'string' ||
    typeof value.page.version !== 'string' || !value.page.version ||
    typeof value.page.text !== 'string' ||
    !Number.isSafeInteger(value.page.lines) || value.page.lines < 0 ||
    !Number.isSafeInteger(value.page.offset) || value.page.offset < 1 ||
    typeof value.page.eof !== 'boolean' ||
    !Number.isFinite(value.savedAt) || value.savedAt <= 0 ||
    !value.checksum) return false;
  return value.checksum === nativeWorkspaceTextChecksum(value.page);
}

export class NativeWorkspaceCachedBinary {
  bytes: Uint8Array = new Uint8Array();
  version: string = '';
  totalBytes: number = -1;
  checksum: string = '';
}

export class NativeWorkspaceDirectoryCacheEntry {
  listing: NativeDirectoryListing = new NativeDirectoryListing();
  fingerprint: string = '';
  savedAt: number = 0;
}

export class NativeWorkspaceTextCacheEntry {
  page: NativeFilePage = new NativeFilePage();
  savedAt: number = 0;
}

export class NativeWorkspaceCacheUsage {
  directory: number = 0;
  text: number = 0;
  binary: number = 0;
}

/**
 * Persistent, account-scoped workspace read cache. Metadata is encrypted in an
 * S3 relational store; binary previews use the app-private files directory.
 */
export class NativeWorkspaceCache {
  private static store: relationalStore.RdbStore | null = null;
  private static opening: Promise<relationalStore.RdbStore> | null = null;
  private static writes: Promise<void> = Promise.resolve();

  private static async database(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (NativeWorkspaceCache.store) return NativeWorkspaceCache.store;
    if (NativeWorkspaceCache.opening) return NativeWorkspaceCache.opening;
    const opening = relationalStore.getRdbStore(context, {
      name: 'dsh-harmony-workspace-cache.db',
      securityLevel: relationalStore.SecurityLevel.S3,
      encrypt: true
    }).then(async (store: relationalStore.RdbStore): Promise<relationalStore.RdbStore> => {
      await store.executeSql(`CREATE TABLE IF NOT EXISTS directory_cache(
        scope_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        path TEXT NOT NULL,
        payload TEXT NOT NULL,
        fingerprint TEXT NOT NULL,
        bytes INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(scope_id, session_id, path)
      )`);
      await store.executeSql(
        'CREATE INDEX IF NOT EXISTS workspace_directory_access ON directory_cache(updated_at)');
      await store.executeSql(`CREATE TABLE IF NOT EXISTS text_cache(
        scope_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        path TEXT NOT NULL,
        payload TEXT NOT NULL,
        version TEXT NOT NULL,
        bytes INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(scope_id, session_id, path)
      )`);
      await store.executeSql(
        'CREATE INDEX IF NOT EXISTS workspace_text_access ON text_cache(updated_at)');
      await store.executeSql(`CREATE TABLE IF NOT EXISTS binary_cache(
        scope_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        path TEXT NOT NULL,
        version TEXT NOT NULL,
        file_name TEXT NOT NULL,
        bytes INTEGER NOT NULL,
        total_bytes INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(scope_id, session_id, path)
      )`);
      await store.executeSql(
        'CREATE INDEX IF NOT EXISTS workspace_binary_access ON binary_cache(updated_at)');
      NativeWorkspaceCache.store = store;
      return store;
    }).finally((): void => { NativeWorkspaceCache.opening = null; });
    NativeWorkspaceCache.opening = opening;
    return opening;
  }

  private static binaryDirectory(context: common.UIAbilityContext): string {
    const path = context.filesDir + '/native-workspace-cache';
    if (!fileIo.accessSync(path)) fileIo.mkdirSync(path, true);
    return path;
  }

  private static binaryKey(scope: string, sessionId: string, path: string): string {
    return nativeWorkspaceScopeId(scope) + '-' +
      textHash(sessionId + '\n' + path).replace(/:/g, '-');
  }

  private static binaryPath(context: common.UIAbilityContext, scope: string,
    sessionId: string, path: string): string {
    return NativeWorkspaceCache.binaryDirectory(context) + '/' +
      NativeWorkspaceCache.binaryKey(scope, sessionId, path) + '.bin';
  }

  /** The only file names this cache ever unlinks are recomputed from the row's
   * own coordinates, so a tampered or restored database cannot point a
   * deletion at an arbitrary path (mirrors the loadBinary check). */
  private static isExpectedBinaryFileName(scopeId: string, sessionId: string,
    path: string, fileName: string): boolean {
    return fileName === scopeId + '-' +
      textHash(sessionId + '\n' + path).replace(/:/g, '-') + '.bin';
  }

  static async loadDirectory(context: common.UIAbilityContext, scope: string,
    sessionId: string, path: string): Promise<NativeWorkspaceDirectoryCacheEntry | null> {
    await NativeWorkspaceCache.writes.catch((): void => {});
    try {
      const store = await NativeWorkspaceCache.database(context);
      const result = await store.querySql(
        'SELECT payload FROM directory_cache WHERE scope_id=? AND session_id=? AND path=? LIMIT 1',
        [nativeWorkspaceScopeId(scope), sessionId, path]);
      let payload = '';
      try {
        if (!result.goToFirstRow()) return null;
        payload = result.getString(0);
      } finally {
        result.close();
      }
      const cached = JSON.parse(payload) as NativeWorkspaceCachedDirectory;
      if (!nativeValidWorkspaceDirectoryCache(cached)) {
        await NativeWorkspaceCache.removeEntry(context, scope, sessionId, path, true, false);
        return null;
      }
      NativeWorkspaceCache.touchDirectory(context, scope, sessionId, path);
      const value = new NativeWorkspaceDirectoryCacheEntry();
      value.listing = cached.listing;
      value.fingerprint = cached.fingerprint;
      value.savedAt = cached.savedAt;
      return value;
    } catch (_) {
      return null;
    }
  }

  static saveDirectory(context: common.UIAbilityContext, scope: string, sessionId: string,
    path: string, listing: NativeDirectoryListing): Promise<void> {
    const cached = new NativeWorkspaceCachedDirectory();
    cached.listing = listing;
    cached.fingerprint = nativeDirectoryFingerprint(listing.entries, listing.truncated);
    cached.savedAt = Date.now();
    const payload = JSON.stringify(cached);
    // One listing row is a single TEXT payload: oversized listings are not
    // persisted (the live listing still renders; truncated already signals it).
    if (payload.length > 2 * 1024 * 1024) return Promise.resolve();
    const scopeId = nativeWorkspaceScopeId(scope);
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      await store.executeSql(`INSERT INTO directory_cache(
        scope_id,session_id,path,payload,fingerprint,bytes,updated_at
      ) VALUES (?,?,?,?,?,?,?)
      ON CONFLICT(scope_id,session_id,path) DO UPDATE SET
        payload=excluded.payload,fingerprint=excluded.fingerprint,
        bytes=excluded.bytes,updated_at=excluded.updated_at`,
      [scopeId, sessionId, path, payload, cached.fingerprint, byteEstimate(payload), cached.savedAt]);
      await NativeWorkspaceCache.trimMetadata(store, scopeId);
    });
    NativeWorkspaceCache.writes = operation;
    return operation;
  }

  private static touchDirectory(context: common.UIAbilityContext, scope: string,
    sessionId: string, path: string): void {
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      await store.executeSql(`UPDATE directory_cache SET updated_at=?
        WHERE scope_id=? AND session_id=? AND path=?`,
      [Date.now(), nativeWorkspaceScopeId(scope), sessionId, path]);
    });
    NativeWorkspaceCache.writes = operation;
  }

  static async loadText(context: common.UIAbilityContext, scope: string,
    sessionId: string, path: string): Promise<NativeWorkspaceTextCacheEntry | null> {
    await NativeWorkspaceCache.writes.catch((): void => {});
    try {
      const store = await NativeWorkspaceCache.database(context);
      const result = await store.querySql(
        'SELECT payload FROM text_cache WHERE scope_id=? AND session_id=? AND path=? LIMIT 1',
        [nativeWorkspaceScopeId(scope), sessionId, path]);
      let payload = '';
      try {
        if (!result.goToFirstRow()) return null;
        payload = result.getString(0);
      } finally {
        result.close();
      }
      const cached = JSON.parse(payload) as NativeWorkspaceCachedText;
      if (!nativeValidWorkspaceTextCache(cached)) {
        await NativeWorkspaceCache.removeEntry(context, scope, sessionId, path, false, true);
        return null;
      }
      NativeWorkspaceCache.touchText(context, scope, sessionId, path);
      const value = new NativeWorkspaceTextCacheEntry();
      value.page = cached.page;
      value.savedAt = cached.savedAt;
      return value;
    } catch (_) {
      return null;
    }
  }

  static saveText(context: common.UIAbilityContext, scope: string, sessionId: string,
    path: string, page: NativeFilePage): Promise<void> {
    if (!page.version || page.text.length > textCacheLimit) return Promise.resolve();
    const cached = new NativeWorkspaceCachedText();
    cached.page = page;
    cached.checksum = nativeWorkspaceTextChecksum(page);
    cached.savedAt = Date.now();
    const payload = JSON.stringify(cached);
    const scopeId = nativeWorkspaceScopeId(scope);
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      await store.executeSql(`INSERT INTO text_cache(
        scope_id,session_id,path,payload,version,bytes,updated_at
      ) VALUES (?,?,?,?,?,?,?)
      ON CONFLICT(scope_id,session_id,path) DO UPDATE SET
        payload=excluded.payload,version=excluded.version,
        bytes=excluded.bytes,updated_at=excluded.updated_at`,
      [scopeId, sessionId, path, payload, page.version, byteEstimate(payload), cached.savedAt]);
      await NativeWorkspaceCache.trimMetadata(store, scopeId);
    });
    NativeWorkspaceCache.writes = operation;
    return operation;
  }

  private static touchText(context: common.UIAbilityContext, scope: string,
    sessionId: string, path: string): void {
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      await store.executeSql(`UPDATE text_cache SET updated_at=?
        WHERE scope_id=? AND session_id=? AND path=?`,
      [Date.now(), nativeWorkspaceScopeId(scope), sessionId, path]);
    });
    NativeWorkspaceCache.writes = operation;
  }

  static async loadBinary(context: common.UIAbilityContext, scope: string,
    sessionId: string, path: string): Promise<NativeWorkspaceCachedBinary | null> {
    await NativeWorkspaceCache.writes.catch((): void => {});
    const scopeId = nativeWorkspaceScopeId(scope);
    let fileName = '';
    let version = '';
    let bytes = -1;
    let totalBytes = -1;
    let checksum = '';
    try {
      const store = await NativeWorkspaceCache.database(context);
      const result = await store.querySql(
        `SELECT file_name,version,bytes,total_bytes,checksum FROM binary_cache
         WHERE scope_id=? AND session_id=? AND path=? LIMIT 1`,
        [scopeId, sessionId, path]);
      try {
        if (!result.goToFirstRow()) return null;
        fileName = result.getString(0);
        version = result.getString(1);
        bytes = result.getLong(2);
        totalBytes = result.getLong(3);
        checksum = result.getString(4);
      } finally {
        result.close();
      }
      const expectedPath = NativeWorkspaceCache.binaryKey(scope, sessionId, path) + '.bin';
      if (fileName !== expectedPath || !version || bytes <= 0 || bytes > binaryFileLimit ||
        totalBytes < 0 || !checksum) {
        await NativeWorkspaceCache.removeEntry(context, scope, sessionId, path, false, false, true);
        return null;
      }
      const absolute = NativeWorkspaceCache.binaryDirectory(context) + '/' + fileName;
      const file = fileIo.openSync(absolute, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(file.fd);
        if (Number(stat.size) !== bytes) throw new Error('Invalid cached binary length');
        const payload = new ArrayBuffer(bytes);
        let offset = 0;
        while (offset < bytes) {
          const count = fileIo.readSync(file.fd, payload, {
            offset: offset,
            length: bytes - offset
          });
          if (count <= 0) throw new Error('Incomplete cached binary');
          offset += count;
        }
        const valueBytes = new Uint8Array(payload);
        if (byteHash(valueBytes) !== checksum) throw new Error('Invalid cached binary checksum');
        const value = new NativeWorkspaceCachedBinary();
        value.bytes = valueBytes;
        value.version = version;
        value.totalBytes = totalBytes;
        value.checksum = checksum;
        NativeWorkspaceCache.touchBinary(context, scopeId, sessionId, path);
        return value;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (_) {
      await NativeWorkspaceCache.removeEntry(context, scope, sessionId, path, false, false, true);
      return null;
    }
  }

  static async saveBinary(context: common.UIAbilityContext, scope: string, sessionId: string,
    path: string, bytes: Uint8Array, version: string, totalBytes: number): Promise<void> {
    if (!version || !bytes.byteLength || bytes.byteLength > binaryFileLimit) return;
    const scopeId = nativeWorkspaceScopeId(scope);
    const fileName = NativeWorkspaceCache.binaryKey(scope, sessionId, path) + '.bin';
    const absolute = NativeWorkspaceCache.binaryDirectory(context) + '/' + fileName;
    const temporary = absolute + '.tmp-' + util.generateRandomUUID();
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(temporary,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, bytes.slice().buffer as ArrayBuffer);
      fileIo.closeSync(file);
      file = null;
      fileIo.renameSync(temporary, absolute);
      const checksum = byteHash(bytes);
      const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
        const store = await NativeWorkspaceCache.database(context);
        await store.executeSql(`INSERT INTO binary_cache(
          scope_id,session_id,path,version,file_name,bytes,total_bytes,checksum,updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?)
        ON CONFLICT(scope_id,session_id,path) DO UPDATE SET
          version=excluded.version,file_name=excluded.file_name,bytes=excluded.bytes,
          total_bytes=excluded.total_bytes,checksum=excluded.checksum,updated_at=excluded.updated_at`,
        [scopeId, sessionId, path, version, fileName, bytes.byteLength,
          Math.max(totalBytes, bytes.byteLength), checksum, Date.now()]);
        await NativeWorkspaceCache.trimBinary(store, context, scopeId);
      });
      NativeWorkspaceCache.writes = operation;
      await operation;
    } finally {
      if (file) fileIo.closeSync(file);
      try { if (fileIo.accessSync(temporary)) fileIo.unlinkSync(temporary); } catch (_) {}
    }
  }

  private static touchBinary(context: common.UIAbilityContext, scopeId: string,
    sessionId: string, path: string): void {
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      await store.executeSql(`UPDATE binary_cache SET updated_at=?
        WHERE scope_id=? AND session_id=? AND path=?`,
      [Date.now(), scopeId, sessionId, path]);
    });
    NativeWorkspaceCache.writes = operation;
  }

  static async removeEntry(context: common.UIAbilityContext, scope: string, sessionId: string,
    path: string, directory: boolean, text: boolean, binary: boolean = false): Promise<void> {
    const scopeId = nativeWorkspaceScopeId(scope);
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      if (directory) await store.executeSql(
        'DELETE FROM directory_cache WHERE scope_id=? AND session_id=? AND path=?',
        [scopeId, sessionId, path]);
      if (text) await store.executeSql(
        'DELETE FROM text_cache WHERE scope_id=? AND session_id=? AND path=?',
        [scopeId, sessionId, path]);
      if (binary) {
        await store.executeSql(
          'DELETE FROM binary_cache WHERE scope_id=? AND session_id=? AND path=?',
          [scopeId, sessionId, path]);
      }
      if (binary) {
        const absolute = NativeWorkspaceCache.binaryPath(context, scope, sessionId, path);
        try { if (fileIo.accessSync(absolute)) fileIo.unlinkSync(absolute); } catch (_) {}
      }
    });
    NativeWorkspaceCache.writes = operation;
    await operation;
  }

  static async clearSession(context: common.UIAbilityContext, scope: string,
    sessionId: string): Promise<void> {
    const scopeId = nativeWorkspaceScopeId(scope);
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      const files: string[] = [];
      const result = await store.querySql(
        'SELECT path,file_name FROM binary_cache WHERE scope_id=? AND session_id=?',
        [scopeId, sessionId]);
      try {
        while (result.goToNextRow()) {
          const rowPath = result.getString(0);
          const rowName = result.getString(1);
          if (NativeWorkspaceCache.isExpectedBinaryFileName(scopeId, sessionId, rowPath, rowName)) {
            files.push(rowName);
          }
        }
      } finally { result.close(); }
      await store.executeSql('DELETE FROM directory_cache WHERE scope_id=? AND session_id=?',
        [scopeId, sessionId]);
      await store.executeSql('DELETE FROM text_cache WHERE scope_id=? AND session_id=?',
        [scopeId, sessionId]);
      await store.executeSql('DELETE FROM binary_cache WHERE scope_id=? AND session_id=?',
        [scopeId, sessionId]);
      try {
        const directory = NativeWorkspaceCache.binaryDirectory(context);
        for (const name of files) {
          try { fileIo.unlinkSync(directory + '/' + name); } catch (_) {}
        }
      } catch (_) {}
    });
    NativeWorkspaceCache.writes = operation;
    await operation;
  }

  static async clearScope(context: common.UIAbilityContext, scope: string): Promise<void> {
    const scopeId = nativeWorkspaceScopeId(scope);
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      await store.executeSql('DELETE FROM directory_cache WHERE scope_id=?', [scopeId]);
      await store.executeSql('DELETE FROM text_cache WHERE scope_id=?', [scopeId]);
      await store.executeSql('DELETE FROM binary_cache WHERE scope_id=?', [scopeId]);
      const prefix = scopeId + '-';
      try {
        const directory = NativeWorkspaceCache.binaryDirectory(context);
        for (const name of fileIo.listFileSync(directory)) {
          if (name.startsWith(prefix)) {
            try { fileIo.unlinkSync(directory + '/' + name); } catch (_) {}
          }
        }
      } catch (_) {}
    });
    NativeWorkspaceCache.writes = operation;
    await operation;
  }

  /** Logical retained workspace bytes without touching LRU timestamps. */
  static async usageScope(context: common.UIAbilityContext,
    scope: string): Promise<NativeWorkspaceCacheUsage> {
    await NativeWorkspaceCache.writes.catch((): void => {});
    const store = await NativeWorkspaceCache.database(context);
    const scopeId = nativeWorkspaceScopeId(scope);
    const usage = new NativeWorkspaceCacheUsage();

    const directories = await store.querySql(
      'SELECT COALESCE(SUM(bytes),0) FROM directory_cache WHERE scope_id=?', [scopeId]);
    try {
      if (directories.goToFirstRow()) usage.directory = Math.max(0, directories.getLong(0));
    } finally {
      directories.close();
    }

    const texts = await store.querySql(
      'SELECT COALESCE(SUM(bytes),0) FROM text_cache WHERE scope_id=?', [scopeId]);
    try {
      if (texts.goToFirstRow()) usage.text = Math.max(0, texts.getLong(0));
    } finally {
      texts.close();
    }

    const binaries = await store.querySql(
      'SELECT COALESCE(SUM(bytes),0) FROM binary_cache WHERE scope_id=?', [scopeId]);
    try {
      if (binaries.goToFirstRow()) usage.binary = Math.max(0, binaries.getLong(0));
    } finally {
      binaries.close();
    }
    return usage;
  }

  /** Compact cache descriptors for the global LRU coordinator. */
  static async storageCandidates(context: common.UIAbilityContext): Promise<NativeStorageCandidate[]> {
    await NativeWorkspaceCache.writes.catch((): void => {});
    const store = await NativeWorkspaceCache.database(context);
    const rows = await store.querySql(
      `SELECT 'directory' AS owner,scope_id,session_id,path,bytes,updated_at
         FROM directory_cache
       UNION ALL
       SELECT 'text' AS owner,scope_id,session_id,path,bytes,updated_at
         FROM text_cache
       UNION ALL
       SELECT 'binary' AS owner,scope_id,session_id,path,bytes,updated_at
         FROM binary_cache
       ORDER BY 6 ASC`
    );
    const values: NativeStorageCandidate[] = [];
    try {
      while (rows.goToNextRow()) {
        const kind = rows.getString(0);
        const owner = kind === 'directory' ? NativeStorageOwner.workspaceDirectory :
          kind === 'text' ? NativeStorageOwner.workspaceText : NativeStorageOwner.workspaceBinary;
        values.push(new NativeStorageCandidate(owner, rows.getString(1), rows.getString(2),
          rows.getString(3), rows.getLong(4), rows.getLong(5)));
      }
    } finally {
      rows.close();
    }
    return values;
  }

  static async evictStorageCandidate(context: common.UIAbilityContext,
    candidate: NativeStorageCandidate): Promise<void> {
    let fileName = '';
    const operation = NativeWorkspaceCache.writes.catch((): void => {}).then(async (): Promise<void> => {
      const store = await NativeWorkspaceCache.database(context);
      if (candidate.owner === NativeStorageOwner.workspaceBinary) {
        const result = await store.querySql(
          `SELECT file_name FROM binary_cache
           WHERE scope_id=? AND session_id=? AND path=? LIMIT 1`,
          [candidate.scopeId, candidate.sessionId, candidate.key]);
        try {
          if (result.goToFirstRow()) fileName = result.getString(0);
        } finally {
          result.close();
        }
      }
      store.beginTransaction();
      try {
        if (candidate.owner === NativeStorageOwner.workspaceDirectory) {
          await store.executeSql(
            'DELETE FROM directory_cache WHERE scope_id=? AND session_id=? AND path=?',
            [candidate.scopeId, candidate.sessionId, candidate.key]);
        } else if (candidate.owner === NativeStorageOwner.workspaceText) {
          await store.executeSql(
            'DELETE FROM text_cache WHERE scope_id=? AND session_id=? AND path=?',
            [candidate.scopeId, candidate.sessionId, candidate.key]);
        } else if (candidate.owner === NativeStorageOwner.workspaceBinary) {
          await store.executeSql(
            'DELETE FROM binary_cache WHERE scope_id=? AND session_id=? AND path=?',
            [candidate.scopeId, candidate.sessionId, candidate.key]);
        }
        store.commit();
      } catch (error) {
        store.rollBack();
        throw error as Error;
      }
    });
    NativeWorkspaceCache.writes = operation;
    await operation;
    if (candidate.owner === NativeStorageOwner.workspaceBinary && !!fileName &&
      NativeWorkspaceCache.isExpectedBinaryFileName(candidate.scopeId, candidate.sessionId,
        candidate.key, fileName)) {
      try {
        const absolute = NativeWorkspaceCache.binaryDirectory(context) + '/' + fileName;
        if (fileIo.accessSync(absolute)) fileIo.unlinkSync(absolute);
      } catch (_) {}
    }
  }

  private static async trimMetadata(store: relationalStore.RdbStore, scopeId: string): Promise<void> {
    let total = 0;
    const totalRows = await store.querySql(
      `SELECT COALESCE(SUM(bytes),0) FROM (
        SELECT bytes FROM directory_cache WHERE scope_id=?
        UNION ALL SELECT bytes FROM text_cache WHERE scope_id=?
      )`, [scopeId, scopeId]);
    try {
      if (totalRows.goToFirstRow()) total = totalRows.getLong(0);
    } finally { totalRows.close(); }
    while (total > metadataQuota) {
      const rows = await store.querySql(
        `SELECT kind,session_id,path,bytes FROM (
          SELECT 'directory' AS kind,session_id,path,bytes,updated_at
            FROM directory_cache WHERE scope_id=?
          UNION ALL
          SELECT 'text' AS kind,session_id,path,bytes,updated_at
            FROM text_cache WHERE scope_id=?
        ) ORDER BY updated_at ASC LIMIT 64`, [scopeId, scopeId]);
      const kinds: string[] = [];
      const sessions: string[] = [];
      const paths: string[] = [];
      let removed = 0;
      try {
        while (rows.goToNextRow()) {
          kinds.push(rows.getString(0));
          sessions.push(rows.getString(1));
          paths.push(rows.getString(2));
          removed += rows.getLong(3);
        }
      } finally { rows.close(); }
      if (!kinds.length) break;
      for (let index = 0; index < kinds.length; index++) {
        await store.executeSql(
          kinds[index] === 'text' ?
            'DELETE FROM text_cache WHERE scope_id=? AND session_id=? AND path=?' :
            'DELETE FROM directory_cache WHERE scope_id=? AND session_id=? AND path=?',
          [scopeId, sessions[index], paths[index]]);
      }
      total -= removed;
    }
  }

  private static async trimBinary(store: relationalStore.RdbStore,
    context: common.UIAbilityContext, scopeId: string): Promise<void> {
    let total = 0;
    const totalRows = await store.querySql(
      'SELECT COALESCE(SUM(bytes),0) FROM binary_cache WHERE scope_id=?', [scopeId]);
    try {
      if (totalRows.goToFirstRow()) total = totalRows.getLong(0);
    } finally { totalRows.close(); }
    while (total > binaryQuota) {
      const rows = await store.querySql(
        `SELECT session_id,path,file_name,bytes FROM binary_cache
         WHERE scope_id=? ORDER BY updated_at ASC LIMIT 32`, [scopeId]);
      const sessions: string[] = [];
      const paths: string[] = [];
      const files: string[] = [];
      let removed = 0;
      try {
        while (rows.goToNextRow()) {
          sessions.push(rows.getString(0));
          paths.push(rows.getString(1));
          files.push(rows.getString(2));
          removed += rows.getLong(3);
        }
      } finally { rows.close(); }
      if (!paths.length) break;
      for (let index = 0; index < paths.length; index++) {
        const rowsToDelete = await store.querySql(
          'SELECT file_name FROM binary_cache WHERE scope_id=? AND session_id=? AND path=? LIMIT 1',
          [scopeId, sessions[index], paths[index]]);
        try {
          if (rowsToDelete.goToFirstRow()) files[index] = rowsToDelete.getString(0);
        } finally { rowsToDelete.close(); }
        await store.executeSql(
          'DELETE FROM binary_cache WHERE scope_id=? AND session_id=? AND path=?',
          [scopeId, sessions[index], paths[index]]);
        if (!NativeWorkspaceCache.isExpectedBinaryFileName(scopeId, sessions[index],
          paths[index], files[index])) continue;
        try {
          const absolute = NativeWorkspaceCache.binaryDirectory(context) + '/' + files[index];
          if (fileIo.accessSync(absolute)) fileIo.unlinkSync(absolute);
        } catch (_) {}
      }
      total -= removed;
    }
  }
}
