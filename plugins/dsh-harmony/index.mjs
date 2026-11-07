import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import http from 'node:http';
import https from 'node:https';
import { resolve } from 'node:path';
import { homedir } from 'node:os';
import { writeFileSync, chmodSync, renameSync } from 'node:fs';
import { createRequire } from 'node:module';
import { createApp } from '../../gateway/src/app.mjs';
import { openStore } from '../../gateway/src/store.mjs';
import { createPushSender, flushJobs } from '../../gateway/src/push.mjs';
import { routingEvent } from '../pocket-notify/index.mjs';

export const name = 'dsh-harmony';
export const inject = ['webServer', 'connection'];
const pluginVersion = createRequire(import.meta.url)('./package.json').version;

/** Native mode uses Harness's public signed-cookie and launch-token API. */
export function hostIdentity(connection, req) {
  const rejection = connection.requestRejection(req);
  if (rejection) return { rejection };
  for (const item of (req.headers.cookie || '').split(';').slice(0, 32)) {
    const cookie = item.trim();
    if (!/^dsh-auth-[A-Za-z0-9_-]+=v1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(cookie)) continue;
    if (connection.requestRejection({ headers: { ...req.headers, cookie } })) continue;
    try {
      const value = cookie.slice(cookie.indexOf('=') + 1);
      const payload = JSON.parse(Buffer.from(value.split('.')[1], 'base64url').toString());
      if (Number.isSafeInteger(payload.expiresAt) && payload.expiresAt > Date.now()) return {
        owner: createHash('sha256').update('host:' + cookie).digest('hex'), expires: payload.expiresAt
      };
    } catch {}
  }
  return { rejection: 401 };
}

export function apply(ctx, options = {}) {
  const db = openStore(resolve(options.dataFile || resolve(process.env.DSH_HOME || resolve(homedir(), '.dsh'), 'harmony.sqlite')));
  const upstream = ctx.webServer.getOrigin();
  if (process.env.DSH_HARMONY_LAUNCH_FILE) {
    const path = process.env.DSH_HARMONY_LAUNCH_FILE;
    const temp = path + '.new-' + process.pid;
    writeFileSync(temp, ctx.connection.authenticatedUrl(upstream + '/') + '\n', { mode: 0o600 });
    chmodSync(temp, 0o640); renameSync(temp, path);
  }
  const send = createPushSender(options.serviceAccount || process.env.HUAWEI_SERVICE_ACCOUNT, process.env.HUAWEI_CATEGORY || 'MARKETING', process.env.HUAWEI_TEST_MESSAGE !== 'false');
  const apps = new Map();
  const eventSecret = randomBytes(48).toString('base64url');
  let credential, credentialUntil = 0, exchange;
  const cookieFor = async () => {
    if (credential && credentialUntil > Date.now()) return credential;
    if (exchange) return exchange;
    exchange = new Promise((resolveCookie, reject) => {
      const target = new URL(ctx.connection.authenticatedUrl(upstream + '/'));
      const client = target.protocol === 'https:' ? https : http;
      const req = client.get(target, { timeout: 8000 }, res => {
        res.resume();
        const value = (res.headers['set-cookie'] || []).map(x => x.split(';')[0]).join('; ');
        if (res.statusCode !== 303 || !value) { reject(Error('Harness authentication unavailable')); return; }
        credential = value; credentialUntil = Date.now() + 240000; resolveCookie(value);
      });
      req.on('error', reject); req.on('timeout', () => req.destroy(Error('Authentication timeout')));
    }).finally(() => { exchange = null; });
    return exchange;
  };
  // Apps are pinned per trust: only requests that already passed the trust fence
  // may create one, and the event-recording owner app is never evicted.
  const pinned = new Set();
  const appFor = (origin, mode) => {
    const key = mode + ':' + origin;
    if (apps.has(key)) {
      const cached = apps.get(key);
      apps.delete(key); apps.set(key, cached);
      return cached;
    }
    if (apps.size >= 32) {
      for (const [oldestKey, oldest] of apps) {
        if (pinned.has(oldestKey)) continue;
        apps.delete(oldestKey); oldest.close(); break;
      }
    }
    const app = createApp({ db, origin, upstream, upstreamCookie: cookieFor, mode, eventSecret,
      pushConfigured: !!send, pluginVersion, proxySecret: process.env.DSH_HARMONY_PROXY_SECRET,
      authOrigin: process.env.DSH_HARMONY_AUTH_ORIGIN || '', hostAuthenticate: req => hostIdentity(ctx.connection, req) });
    apps.set(key, app);
    return app;
  };
  const loopbackPeer = address => ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(address);
  const proxySecretValid = req => loopbackPeer(req.socket.remoteAddress) &&
    typeof process.env.DSH_HARMONY_PROXY_SECRET === 'string' &&
    Buffer.from(String(req.headers['x-dsh-proxy-secret'] || '')).length === Buffer.from(process.env.DSH_HARMONY_PROXY_SECRET).length &&
    timingSafeEqual(Buffer.from(String(req.headers['x-dsh-proxy-secret'] || '')), Buffer.from(process.env.DSH_HARMONY_PROXY_SECRET));
  // Spoofed Host/Origin values must never reach appFor: they would fill the app
  // cache before the in-app trust fence runs.
  const trusted = req => req.headers['x-dsh-proxy-secret'] ? proxySecretValid(req) :
    hostIdentity(ctx.connection, req).rejection !== 403;
  const originFor = req => {
    if (req.headers['x-dsh-proxy-secret']) return process.env.DSH_HARMONY_PUBLIC_ORIGIN;
    const origin = req.headers.origin || `${ctx.webServer.protocol}//${req.headers.host}`;
    const url = new URL(origin);
    if (!['http:', 'https:'].includes(url.protocol) || url.origin !== origin || url.host !== req.headers.host) throw Error('Untrusted origin');
    return origin;
  };
  let loginBucket = 0, loginCount = 0;
  const login = async (req, res) => {
    const bucket = Math.floor(Date.now() / 60000);
    if (bucket !== loginBucket) { loginBucket = bucket; loginCount = 0; }
    if (++loginCount > 30) { res.writeHead(429); res.end(); return; }
    if (ctx.connection.requestRejection(req) === 403) { res.writeHead(403); res.end(); return; }
    const chunks = []; let size = 0;
    for await (const chunk of req) { size += chunk.length; if (size > 4096) { res.writeHead(413); res.end(); return; } chunks.push(chunk); }
    const { token } = JSON.parse(Buffer.concat(chunks).toString());
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{16,2048}$/.test(token)) { res.writeHead(401); res.end(); return; }
    let status, headers;
    ctx.connection.authorizeIndex({ method: 'GET', url: '/?token=' + encodeURIComponent(token), headers: req.headers }, {
      writeHead(code, values) { status = code; headers = values; }, end() {}
    });
    if (status !== 303 || !headers?.['set-cookie']) { res.writeHead(401); res.end(); return; }
    res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store', 'set-cookie': headers['set-cookie'] });
    res.end(JSON.stringify({ ok: true }));
  };
  const disposeRoute = ctx.webServer.register({ kind: 'prefix', path: '/pocket', handler: async (req, res) => {
    try {
      const origin = originFor(req);
      const proxy = !!req.headers['x-dsh-proxy-secret'];
      if (!proxy && req.url?.split('?')[0] === '/pocket/api/auth/native' && req.method === 'POST') {
        if (!req.headers.origin) { res.writeHead(403); res.end(); return; }
        await login(req, res); return;
      }
      if (!trusted(req)) { res.writeHead(403); res.end('Untrusted origin'); return; }
      appFor(origin, proxy ? 'proxy' : 'host').app(req, res);
    } catch { if (!res.headersSent) { res.writeHead(400); res.end('Connection unavailable'); } else res.destroy(); }
  } });
  const disposeUpgrade = ctx.webServer.registerUpgrade({ path: '/pocket/native/live', handler: async (req, socket, head) => {
    try {
      const origin = originFor(req);
      if (!trusted(req)) { socket.destroy(); return; }
      await appFor(origin, req.headers['x-dsh-proxy-secret'] ? 'proxy' : 'host').upgrade(req, socket, head);
    }
    catch { socket.destroy(); }
  } });
  // State and notifications stay in this plugin process; no relay is required.
  const owner = appFor(upstream, 'host');
  pinned.add('host:' + upstream);
  ctx.on('session/event', (session, event) => {
    const value = routingEvent(session, event);
    if (value && !(typeof session.inheritedEventCount === 'number' && event.seq < session.inheritedEventCount)) {
      const title = session.projections?.values?.title ?? session.title ?? '';
      try { owner.recordEvent({ ...value, ...(typeof title === 'string' ? { title } : {}) }); }
      catch { ctx.logger?.warn('Harmony event queue unavailable'); }
    }
  }, { global: true });
  let flushing = false, disposed = false;
  const timer = setInterval(async () => {
    if (flushing || disposed) return;
    flushing = true;
    try { owner.cleanup(); await flushJobs(db, send); }
    catch { ctx.logger?.warn('Harmony notification queue unavailable'); }
    finally { flushing = false; }
  }, 5000);
  timer.unref();
  ctx.effect(() => async () => {
    disposed = true; clearInterval(timer); disposeRoute(); disposeUpgrade();
    for (const app of apps.values()) app.close();
    while (flushing) await new Promise(resolve => setTimeout(resolve, 25));
    db.close();
  });
}
