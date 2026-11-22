import http from 'node:http';
import { readFile, realpath, stat } from 'node:fs/promises';
import { dirname, resolve, sep, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = await realpath(resolve(dirname(fileURLToPath(import.meta.url)), '../preview'));
const port = Number(process.env.IMPERATHEN_PORT ?? 4173);
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  throw new Error('IMPERATHEN_PORT must be an integer between 1024 and 65535.');
}
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml', '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.webp': 'image/webp' };

const server = http.createServer(async (req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' }).end();
    return;
  }
  try {
    const url = new URL(req.url ?? '/', 'http://localhost');
    const requested = decodeURIComponent(url.pathname);
    const candidate = resolve(root, `.${requested === '/' ? '/index.html' : requested}`);
    const actual = await realpath(candidate);
    if (!actual.startsWith(root + sep) || !(await stat(actual)).isFile()) {
      res.writeHead(404).end('Not found');
      return;
    }
    const body = await readFile(actual);
    res.writeHead(200, {
      'Content-Type': types[extname(actual)] ?? 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer'
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  } catch (error) {
    const status = error instanceof URIError || error instanceof TypeError ? 400 : 404;
    res.writeHead(status).end(status === 400 ? 'Bad request' : 'Not found');
  }
});
server.on('error', error => { console.error(error.message); process.exitCode = 1; });
server.listen(port, '127.0.0.1', () => console.log(`IMPERATHEN preview: http://127.0.0.1:${port}`));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
