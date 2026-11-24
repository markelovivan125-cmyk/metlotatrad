// Замена для api/nc/[[...path]].mjs (который на проде не матчит многовложенные пути).
// Весь путь приходит в query-параметре p через rewrites в vercel.json,
// поэтому функция не зависит от req.url и от файлового роутера Vercel.
const SRC = Buffer.from('aHR0cHM6Ly93d3cubm93Y2FzdC5ydQ==', 'base64').toString('utf8'); // https://www.nowcast.ru
const REF = Buffer.from('aHR0cHM6Ly93d3cubm93Y2FzdC5ydS8=', 'base64').toString('utf8'); // https://www.nowcast.ru/
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

export const maxDuration = 60;

function allow(sub) {
  return sub === '/get_token'
    || sub === '/demo/viz/tiles.json'
    || sub.startsWith('/baltrad_wsgi/')
    || sub.startsWith('/xsection/');
}

export default async function handler(req, res) {
  // 1) путь из rewrite (?p=demo/viz/tiles.json)
  let p = req.query?.p;
  if (Array.isArray(p)) p = p.join('/');
  // 2) fallback: вытащить из req.url независимо от префикса (/nc/..., /api/nc/...)
  if (!p) {
    const pathname = String(req.url || '').split('?')[0];
    const m = pathname.match(/(?:^|\/)nc\/(.*)$/);
    p = m ? m[1] : '';
  }
  const sub = '/' + String(p).split('/').filter(Boolean).join('/');
  if (sub === '/' || !allow(sub)) {
    res.status(403).end();
    return;
  }
  // оригинальный query (без p=...) нужен для baltrad_wsgi/xsection (например token=...)
  const rawQ = String(req.url || '').split('?')[1] || '';
  const params = new URLSearchParams(rawQ);
  params.delete('p');
  const q = params.toString();
  const target = SRC + sub + (q ? '?' + q : '');

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const r = await fetch(target, {
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
