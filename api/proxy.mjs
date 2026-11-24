
const SRC = Buffer.from('aHR0cHM6Ly93d3cubm93Y2FzdC5ydQ==', 'base64').toString('utf8');
const H1 = Buffer.from('bWV0ZW9yYWQucnU=', 'base64').toString('utf8');
const H2 = Buffer.from('d3d3Lm1ldGVvaW5mby5ydQ==', 'base64').toString('utf8');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

export default async function handler(req, res) {
  const u = String(req.query.url || '');
  const ok =
    (u.startsWith(SRC + '/demo/viz/mytiles/') && /^https:\/\/[^\s]+\/mytiles\/[A-Za-z0-9_]+\.png$/.test(u)) ||
    u === 'https://' + H1 + '/static/phenomena24.gif' ||
    u === 'https://' + H2 + '/hmc-output/rmap/phenomena.gif' ||
    /^https:\/\/[^\s]+\/res\/nowcast\/\d+\/ncgi\.php\?/.test(u) ||
    u === 'https://' + H2 + '/hmc-output/nowcast3/nowcast.php';
  if (!ok) {
    res.status(403).end();
    return;
  }
  try {
    const r = await fetch(u, { headers: { 'User-Agent': UA, 'Referer': SRC + '/' }, redirect: 'follow' });
    res.status(r.status);
    const ct = r.headers.get('content-type');
    if (ct) res.setHeader('Content-Type', ct);
    res.setHeader('Cache-Control', 'max-age=600');
    const buf = Buffer.from(await r.arrayBuffer());
    res.send(buf);
  } catch (e) {
    res.status(502).end();
  }
}
