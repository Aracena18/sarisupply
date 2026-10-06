import { createServer } from 'node:http';
import { Readable } from 'node:stream';

export function createGatewayServer(handler: (request: Request) => Promise<Response>) {
  return createServer(async (incoming, outgoing) => {
    try {
      const headers = new Headers();
      for (const [name, value] of Object.entries(incoming.headers)) {
        if (Array.isArray(value)) value.forEach((part) => headers.append(name, part));
        else if (value !== undefined) headers.set(name, value);
      }
      const method = incoming.method ?? 'GET';
      const init: RequestInit & { duplex?: string } = { method, headers };
      if (method !== 'GET' && method !== 'HEAD') {
        init.body = Readable.toWeb(incoming) as ReadableStream<Uint8Array>;
        init.duplex = 'half';
      }
      const response = await handler(new Request(
        new URL(incoming.url ?? '/', 'http://gateway.internal'), init,
      ));
      outgoing.writeHead(response.status, Object.fromEntries(response.headers));
      outgoing.end(Buffer.from(await response.arrayBuffer()));
    } catch {
      // Do not log request bodies, tokens, PINs or credentials on transport errors.
      outgoing.writeHead(500, { 'content-type': 'application/json', 'cache-control': 'no-store' });
      outgoing.end(JSON.stringify({ error: { code: 'internal', message: 'Unexpected server error' } }));
    }
  });
}
