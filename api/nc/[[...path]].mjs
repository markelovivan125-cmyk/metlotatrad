const SRC = Buffer.from('aHR0cHM6Ly93d3cubm93Y2FzdC5ydQ==', 'base64').toString('utf8');
const REF = Buffer.from('aHR0cHM6Ly93d3cubm93Y2FzdC5ydS8=', 'base64').toString('utf8');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

export const maxDuration = 60;

function allow(sub) {
  return sub === '/get_token'
    || sub === '/demo/viz/tiles.json'
    || sub.startsWith('/baltrad_wsgi')
    || sub.startsWith('/xsection/');
}

export default async function handler(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const parts = url.pathname.replace(/^\/api\/nc\/?/, '').replace(/^\/+/, '');
  const sub = '/' + parts;
  if (!allow(sub)) {
    res.status(403).end();
    return;
  }
  const upstream = SRC + sub + url.search;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const r = await fetch(upstream, {
        headers: {
          'User-Agent': UA,
          'Referer': REF,
          'Accept': req.headers.accept || '*/*',
        },
        redirect: 'follow',
      });
      res.status(r.status);
      const ct = r.headers.get('content-type');
      if (ct) res.setHeader('Content-Type', ct);
      const cc = r.headers.get('cache-control');
      res.setHeader('Cache-Control', cc || 'no-cache');
      const buf = Buffer.from(await r.arrayBuffer());
      res.send(buf);
      return;
    } catch (e) {
      if (attempt === 2) {
        res.status(502).end();
        return;
      }
      await new Promise((r) => setTimeout(r, 900));
    }
  }
}
