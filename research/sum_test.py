# Does Arcana's sum rule pick the quarter that holds the High - Low?
# Predictions come from Arcana itself (research/sum_pred.json, exported with focusAt0 at the start of every session).
# Checked on 12 months of Dukascopy 1-minute candles for NQ, ES, YM and RTY.
#   hit      = the High or the Low of the block formed in the predicted quarter
#   expected = what a rule with no skill would score: for each block, how often its predicted quarter holds
#              the High or the Low across all blocks of that level (so busy quarters like NY AM are not free wins)
import json, os, math, gzip, lzma, struct, urllib.request, datetime as dt
from concurrent.futures import ThreadPoolExecutor
from zoneinfo import ZoneInfo
NY = ZoneInfo('America/New_York'); UTC = dt.timezone.utc
SYMS = {'NQ': 'USATECHIDXUSD', 'ES': 'USA500IDXUSD', 'YM': 'USA30IDXUSD', 'RTY': 'USSC2000IDXUSD'}
PRED = json.load(open(os.path.join(os.path.dirname(__file__), 'sum_pred.json')))
END = dt.date.today() - dt.timedelta(days=1); START = END - dt.timedelta(days=365)
CACHE = 'cache'; os.makedirs(CACHE, exist_ok=True); UA = {'User-Agent': 'Mozilla/5.0'}

def day_file(sym, d):
    fn = f'{CACHE}/{sym}_{d}.json.gz'
    if os.path.exists(fn) and d < END: return json.load(gzip.open(fn, 'rt'))
    if d.weekday() == 5: return []
    u = f'https://datafeed.dukascopy.com/datafeed/{sym}/{d.year}/{d.month-1:02d}/{d.day:02d}/BID_candles_min_1.bi5'
    for _ in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=30) as r: raw = r.read()
            out = []
            if raw:
                b = lzma.decompress(raw); base = int(dt.datetime(d.year, d.month, d.day, tzinfo=UTC).timestamp())
                for i in range(0, len(b) - 23, 24):
                    t, o, c, l, h, v = struct.unpack('>Iiiiif', b[i:i + 24])
                    if v > 0: out.append((base + t, o, h, l, c))
            json.dump(out, gzip.open(fn, 'wt')); return out
        except Exception: pass
    return []

def load(name, sym):
    if os.environ.get('SUM_LOCAL'):
        j = json.load(open(os.environ['SUM_LOCAL'] + f'/{name}_m1x.json'))['c']
        return sorted({x[0] // 1000: (x[0] // 1000, x[1], x[2], x[3], x[4]) for x in j}.values())
    days = [START + dt.timedelta(days=i) for i in range((END - START).days + 1)]
    with ThreadPoolExecutor(8) as ex: parts = list(ex.map(lambda d: day_file(sym, d), days))
    return sorted({x[0]: tuple(x) for p in parts for x in p}.values())

# ── blocks with their predicted quarter
sess = sorted(PRED, key=lambda r: r['s'])
BLOCKS = {'Week (which day)': [], 'Day (which session)': [], '90 min (which 90 in the session)': [], 'Micro (which micro in the 90)': []}
weeks = {}
for r in sess:
    s = r['s']
    if r['sess'] == 1 and r['pd']:
        BLOCKS['Day (which session)'].append((s, [s + k * 21600 for k in range(5)], r['pd']))
    if r['p90']:
        BLOCKS['90 min (which 90 in the session)'].append((s, [s + k * 5400 for k in range(5)], r['p90']))
    if r['pmc']:
        for k in range(4):
            b0 = s + k * 5400; BLOCKS['Micro (which micro in the 90)'].append((b0, [b0 + j * 1350 for j in range(5)], r['pmc']))
    if r['sess'] == 1 and r['wk'] and r['pw']:
        td = (dt.datetime.fromtimestamp(s, NY) + dt.timedelta(hours=6)).date()
        wkey = td.isocalendar()[:2]; weeks.setdefault(wkey, {'pred': r['pw'], 'days': {}})
        weeks[wkey]['days'][min(td.weekday() + 1, 4)] = weeks[wkey]['days'].get(min(td.weekday() + 1, 4), []) + [(s, s + 86400)]
for wkey, w in weeks.items():
    if len(w['days']) == 4: BLOCKS['Week (which day)'].append((wkey, w['days'], w['pred']))

def score(c):
    import bisect
    T = [x[0] for x in c]; res = {}
    def rng(a, b):
        i, j = bisect.bisect_left(T, a), bisect.bisect_left(T, b)
        return (i, j) if j > i else None
    for lvl, blocks in BLOCKS.items():
        rows = []
        for key, edges, pred in blocks:
            if lvl.startswith('Week'):
                parts = {q: [rng(a, b) for a, b in spans] for q, spans in edges.items()}
                parts = {q: [p for p in v if p] for q, v in parts.items()}
                if any(not v for v in parts.values()): continue
                best = {}
                for q, v in parts.items():
                    for i, j in v:
                        for k in range(i, j):
                            if 'H' not in best or c[k][2] > c[best['H']][2]: best['H'] = k; best['Hq'] = q
                            if 'L' not in best or c[k][3] < c[best['L']][3]: best['L'] = k; best['Lq'] = q
                hq, lq = best['Hq'], best['Lq']
            else:
                span = rng(edges[0], edges[4]); full = (edges[4] - edges[0]) / 60
                if not span or (span[1] - span[0]) < 0.6 * full: continue
                i, j = span
                h = max(range(i, j), key=lambda k: c[k][2]); l = min(range(i, j), key=lambda k: c[k][3])
                qof = lambda k: max(q for q in range(1, 5) if T[k] >= edges[q - 1])
                hq, lq = qof(h), qof(l)
            rows.append((pred, hq, lq))
        if not rows: continue
        n = len(rows)
        either = {q: sum(1 for _, h, l in rows if q in (h, l)) / n for q in range(1, 5)}
        hit = sum(1 for p, h, l in rows if p in (h, l)) / n
        exp = sum(either[p] for p, _, _ in rows) / n
        var = sum(either[p] * (1 - either[p]) for p, _, _ in rows)
        z = (hit * n - exp * n) / math.sqrt(var) if var else 0
        best_fixed = max(either.values())
        hiH = sum(1 for p, h, l in rows if p == h) / n; hiL = sum(1 for p, h, l in rows if p == l) / n
        res[lvl] = dict(blocks=n, hit=round(hit * 100, 1), expected=round(exp * 100, 1), ratio=round(hit / exp, 3) if exp else None, z=round(z, 2),
                        high_in_pred=round(hiH * 100, 1), low_in_pred=round(hiL * 100, 1),
                        quarter_holds_HL={f'Q{q}': round(either[q] * 100, 1) for q in range(1, 5)},
                        pred_mix={f'Q{q}': sum(1 for p, _, _ in rows if p == q) for q in range(1, 5)},
                        best_fixed_quarter=round(best_fixed * 100, 1))
    return res

out = {'from': str(START), 'to': str(END), 'assets': {}}
for name, sym in SYMS.items():
    c = load(name, sym); print(name, len(c), 'bars', flush=True)
    if len(c) < 1000: continue
    out['assets'][name] = score(c)
os.makedirs('out', exist_ok=True); json.dump(out, open('out/sum_test.json', 'w'), indent=1)
L = [f"# Arcana sum rule vs the real High - Low — {out['from']} to {out['to']}", '',
     'hit = the High or the Low formed in the predicted quarter. expected = the score of a rule with no skill that picks quarters as often as the sum rule does. ratio above 1 and z above 3 = real skill.', '']
for lvl in BLOCKS:
    L += [f'## {lvl}', '', '| | ' + ' | '.join(out['assets']) + ' |', '|---|' + '---|' * len(out['assets'])]
    for k, lab in (('blocks', 'blocks'), ('hit', 'hit %'), ('expected', 'expected %'), ('ratio', 'ratio'), ('z', 'z'), ('best_fixed_quarter', 'best fixed quarter %')):
        L.append(f'| {lab} | ' + ' | '.join(str(a.get(lvl, {}).get(k, '—')) for a in out['assets'].values()) + ' |')
    L.append('')
open('out/sum_test.md', 'w').write('\n'.join(L)); print('\n'.join(L))
