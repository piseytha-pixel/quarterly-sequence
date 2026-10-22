// SSMT / 2-Stage SSMT / tCISD alerts for Telegram, run by .github/workflows/prices.yml after each price refresh.
// It opens Arcana itself (the copy inside index.html) with the fresh prices and runs the same check the app runs,
// so the alerts match what members see. Sent alerts are remembered in out/alerts_sent.json.
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const OUT = process.argv[2] || 'out', SITE = process.argv[3] || 'site';
const E = process.env, TG = E.TELEGRAM_BOT_TOKEN && E.TELEGRAM_CHAT_ID;
(async () => {
  const cfg = JSON.parse(fs.readFileSync(path.join(SITE, 'alerts.json'), 'utf8'));
  if (!cfg.on) { console.log('alerts off in alerts.json'); return; }
  const html = fs.readFileSync(path.join(SITE, 'index.html'), 'utf8');
  const m = /__qsArcB64="([^"]+)"/.exec(html); if (!m) throw new Error('Arcana not found in index.html');
  fs.writeFileSync('/tmp/arc.html', Buffer.from(m[1], 'base64').toString('utf8'));
  // the prices, as Arcana keeps them
  const ids = ['ES','NQ','YM','RTY','EURUSD','GBPUSD','DXY','GC','SI','PL','BTC','ETH','SOL'], PXI = {};
  const rd = (id, k) => { try { return JSON.parse(fs.readFileSync(path.join(OUT, 'p', `${id}_${k}.json`), 'utf8')); } catch (e) { return null; } };
  const conv = j => (j && j.c || []).map(x => ({ t: x[0], o: x[1], h: x[2], l: x[3], c: x[4] }));
  for (const id of ids) {
    const m1 = conv(rd(id, 'm1')), m1x = conv(rd(id, 'm1x')), m5 = conv(rd(id, 'm5')), h1 = conv(rd(id, 'h1'));
    const mm = new Map(); m1x.concat(m1).forEach(x => mm.set(x.t, x));
    PXI[id] = { m1: [...mm.values()].sort((a, b) => a.t - b.t).slice(-8000), m5, h1 };
  }
  const sentPath = path.join(OUT, 'alerts_sent.json');
  let sent = {}; try { sent = JSON.parse(fs.readFileSync(sentPath, 'utf8')); } catch (e) {}
  const b = await chromium.launch(E.ARC_CHROME ? { executablePath: E.ARC_CHROME } : {}); const pg = await b.newPage();
  await pg.route('**/*', r => r.request().url().startsWith('file:') || r.request().url().startsWith('data:') ? r.continue() : r.abort());
  await pg.addInitScript(() => { try { localStorage.setItem('qsArcLang', 'en'); } catch (e) {} });
  if (E.ARC_NOW) await pg.addInitScript(t0 => { const R = Date.now(), D = Date; class FD extends D { constructor(...a) { if (a.length) super(...a); else super(t0 + (D.now() - R)); } static now() { return t0 + (D.now() - R); } } window.Date = FD; }, +E.ARC_NOW);   // testing only
  await pg.goto('file:///tmp/arc.html'); await pg.waitForTimeout(2500);
  const list = await pg.evaluate(([PXI, cfg]) => {
    const n = Date.now() + 3600e3;
    for (const id in PXI) PX.d[id] = Object.assign(PX.d[id] || {}, PXI[id], { m1at: n, m5at: n, h1at: n, ghat: n });
    PX.ver++;
    ALR.ps = true; ALR.ps1 = !!cfg.ssmt; ALR.psTc = !!cfg.tcisd;
    ALR.psA = { day: cfg.levels.day || [], m90: cfg.levels.m90 || [], micro: cfg.levels.micro || [] };
    return psScan(Date.now()).map(z => ({ k: z.k, title: z.title, body: z.body }));
  }, [PXI, cfg]);
  await b.close();
  const now = Date.now(); let n = 0, fail = 0;
  if (E.ARC_DRY) { list.forEach(z => console.log('would send:', z.title, '|', z.body)); console.log('found', list.length); return; }
  for (const z of list) {
    if (sent[z.k]) continue;
    if (!TG) { console.log('would send:', z.title); continue; }
    const f = new FormData(); f.append('chat_id', E.TELEGRAM_CHAT_ID); f.append('text', `🔔 ${z.title}\n${z.body}\n\nQS Kingdom’s Arcana`);
    const r = await fetch(`https://api.telegram.org/bot${E.TELEGRAM_BOT_TOKEN}/sendMessage`, { method: 'POST', body: f });
    const j = await r.json().catch(() => ({}));
    if (j.ok) { sent[z.k] = now; n++; console.log('sent:', z.title); } else { fail++; console.log('::warning title=Alerts::Telegram failed (' + (j.description || r.status) + '): ' + z.title); }
  }
  for (const k in sent) if (now - sent[k] > 3 * 864e5) delete sent[k];
  fs.writeFileSync(sentPath, JSON.stringify(sent));
  console.log(`alerts: ${list.length} found, ${n} sent${fail ? ', ' + fail + ' failed' : ''}`);
})().catch(e => { console.log('alerts error:', e.message); process.exit(0); });
