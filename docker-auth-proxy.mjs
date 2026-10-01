// Bearer-token gate in front of supergateway.
//
// Usage: node docker-auth-proxy.mjs <command> [args...]
//
// Spawns <command> (supergateway listening on MCP_INTERNAL_PORT), then listens
// on MCP_PORT and forwards every request whose `Authorization: Bearer <token>`
// header matches MCP_AUTH_TOKEN. /healthz is forwarded without a token so
// container health checks keep working. Responses are streamed, so Streamable
// HTTP and SSE both work through the proxy.
import { spawn } from 'node:child_process';
import { createHash, timingSafeEqual } from 'node:crypto';
import http from 'node:http';

const token = process.env.MCP_AUTH_TOKEN ?? '';
const port = Number(process.env.MCP_PORT || 8000);
const internalPort = Number(process.env.MCP_INTERNAL_PORT || 8001);
const [command, ...args] = process.argv.slice(2);

if (!token || !command) {
  console.error('[auth-proxy] MCP_AUTH_TOKEN and a command to run are required');
  process.exit(1);
}

const digest = value => createHash('sha256').update(value).digest();
const expected = digest(token);

function isAuthorized(header) {
  const match = /^Bearer\s+(.+)$/i.exec(header ?? '');
  return match !== null && timingSafeEqual(digest(match[1].trim()), expected);
}

const child = spawn(command, args, { stdio: 'inherit' });
child.on('exit', (code, signal) => {
  console.error(`[auth-proxy] ${command} exited (${signal ?? code}); shutting down`);
  process.exit(code ?? 1);
});
for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) {
  process.on(signal, () => child.kill(signal));
}

const server = http.createServer((req, res) => {
  const path = (req.url ?? '/').split('?', 1)[0];
  if (path !== '/healthz' && !isAuthorized(req.headers.authorization)) {
    res.writeHead(401, {
      'Content-Type': 'application/json',
      'WWW-Authenticate': 'Bearer realm="mcp-mail-server"',
    });
    res.end(JSON.stringify({ error: 'unauthorized' }));
    return;
  }

  const headers = { ...req.headers };
  delete headers.authorization;
  const upstream = http.request(
    { host: '127.0.0.1', port: internalPort, method: req.method, path: req.url, headers },
    upstreamRes => {
      res.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    },
  );
  upstream.on('error', error => {
    if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: `upstream unavailable: ${error.message}` }));
  });
  res.on('close', () => upstream.destroy());
  req.pipe(upstream);
});

// Long-lived SSE / streaming responses must not be cut off by server timeouts.
server.requestTimeout = 0;
server.timeout = 0;
server.listen(port, () => {
  console.error(`[auth-proxy] Bearer authentication enabled on port ${port}`);
});
