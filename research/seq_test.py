# Do swing highs / lows land in 222, 333 and 414141 sequences more often than chance?
# 12 months of Dukascopy 1-minute candles for US indices; every quarter level from Week down to Pico.
import lzma, struct, json, math, datetime as dt, urllib.request, sys, os
from concurrent.futures import ThreadPoolExecutor
from zoneinfo import ZoneInfo
NY = ZoneInfo('America/New_York'); UTC = dt.timezone.utc
SYMS = {'NQ': 'USATECHIDXUSD', 'ES': 'USA500IDXUSD', 'YM': 'USA30IDXUSD', 'RTY': 'USSC2000IDXUSD'}
END = dt.date.today() - dt.timedelta(days=1); START = END - dt.timedelta(days=365)
UA = {'User-Agent': 'Mozilla/5.0'}

def day_file(sym, d):
    u = f'https://datafeed.dukascopy.com/datafeed/{sym}/{d.year}/{d.month-1:02d}/{d.day:02d}/BID_candles_min_1.bi5'
    for _ in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=30) as r: raw = r.read()
            if not raw: return []
            b = lzma.decompress(raw); base = int(dt.datetime(d.year, d.month, d.day, tzinfo=UTC).timestamp())
            out = []
            for i in range(0, len(b) - 23, 24):
                t, o, c, l, h, v = struct.unpack('>Iiiiif', b[i:i + 24])
                if v > 0: out.append((base + t, o, h, l, c))
            return out
        except Exception as e:
            err = e
    print('  failed', sym, d, err); return []

def load(sym):
    days = [START + dt.timedelta(days=i) for i in range((END - START).days + 1)]
    with ThreadPoolExecutor(8) as ex: parts = list(ex.map(lambda d: day_file(sym, d), days))
    return [x for p in parts for x in p]

# ── the quarter clock (same rules as the app): Week, Day, 90, Micro, Nano, Pico
def lv_at(sec_of_day, wk):   # seconds after midnight NY, weekly quarter (1-4 or None)
    m = sec_of_day / 60
    sh = 1080 if m >= 1080 else 0 if m < 360 else 360 if m < 720 else 720
    day = {1080: 1, 0: 2, 360: 3, 720: 4}[sh]; r = m - sh
    q90 = min(int(r // 90), 3) + 1; r -= (q90 - 1) * 90
    mc = min(int(r // 22.5), 3) + 1; r -= (mc - 1) * 22.5
    na = min(int(r // 5.625), 3) + 1; r -= (na - 1) * 5.625
    pi = min(int(r // 1.40625), 3) + 1
    return [wk, day, q90, mc, na, pi]
NAMES = ['WK', 'DY', '90', 'MC', 'NA', 'PI']
def runs(L, q):   # every run of >=3 consecutive levels equal to q, as level-name strings
    out = set(); i = 0
    while i < len(L):
        if L[i] == q:
            j = i
            while j + 1 < len(L) and L[j + 1] == q: j += 1
            if j - i + 1 >= 3: out.add('·'.join(NAMES[i:j + 1]))
            i = j + 1
        else: i += 1
    return out

# per (weekly quarter, minute of day): which sequence labels are active at any moment inside the minute
CATS = {}
def add(cat, wk, minute): CATS.setdefault(cat, set()).add((wk, minute))
for wk in (1, 2, 3, 4):
    for minute in range(1440):
        for s5 in range(0, 60, 5):
            sec = minute * 60 + s5
            # the trading day starting 18:00 belongs to the next weekday
            for q, nm in ((2, '222'), (3, '333')):
                for r in runs(lv_at(sec, wk), q):
                    add(nm + ' any', wk, minute); add(nm + ' ' + r, wk, minute)
                    if r.endswith('MC·NA·PI'): add(nm + ' pico 3-deep (MC·NA·PI)', wk, minute)
        # 414141: >=3 consecutive levels roll Q4 -> Q1 inside this minute
        for s in range(0, 60):
            sec = minute * 60 + s
            a, b = lv_at(sec - 1 if sec else 86399, wk), lv_at(sec, wk)
            roll = [x == 4 and y == 1 for x, y in zip(a[1:], b[1:])]
            best = 0; cur = 0
            for f in roll: cur = cur + 1 if f else 0; best = max(best, cur)
            if best >= 3: add('414141 any', wk, minute); add(f'414141 {best} levels', wk, minute)

def wk_of(ts):   # weekly quarter of the trading day: Mon=Q1 ... Thu=Q4, Fri counts as Q4
    d = dt.datetime.fromtimestamp(ts + 6 * 3600, NY).weekday()
    return {0: 1, 1: 2, 2: 3, 3: 4, 4: 4}.get(d)

def analyse(c, k=30):
    n = len(c); ts = [x[0] for x in c]
    keys = []
    for t in ts:
        d = dt.datetime.fromtimestamp(t, NY); keys.append((wk_of(t), d.hour * 60 + d.minute, d.hour * 60 + d.minute))
    # swings: the extreme of k minutes either side (using bars, which are minutes)
    from collections import deque
    hi = [x[2] for x in c]; lo = [x[3] for x in c]; piv = []
    for i in range(k, n - k):
        if ts[i + k] - ts[i - k] > (2 * k + 30) * 60: continue      # skip gaps (weekends, halts)
        if hi[i] == max(hi[i - k:i + k + 1]) or lo[i] == min(lo[i - k:i + k + 1]): piv.append(i)
    res = {}
    for cat, S in CATS.items():
        for tol in (0, 1, 5):
            def hit(i):
                wk, m, _ = keys[i]
                return any((wk, (m + dlt) % 1440) in S for dlt in range(-tol, tol + 1))
            base = sum(hit(i) for i in range(0, n, 3)) / len(range(0, n, 3))
            h = sum(hit(i) for i in piv) / len(piv)
            z = (h - base) * len(piv) / math.sqrt(max(1e-9, len(piv) * base * (1 - base)))
            res[f'{cat} | ±{tol}m'] = dict(swing=round(h * 100, 2), base=round(base * 100, 2), ratio=round(h / base, 3) if base else None, z=round(z, 2))
    # 333 without the 09:56 and 15:56 windows (news / cash close)
    S = CATS['333 any']
    def hit2(i):
        wk, m, _ = keys[i]
        if 590 <= m <= 605 or 950 <= m <= 965: return None
        return any((wk, (m + dlt) % 1440) in S for dlt in range(-1, 2))
    a = [hit2(i) for i in range(0, n, 3)]; a = [x for x in a if x is not None]
    b = [hit2(i) for i in piv]; b = [x for x in b if x is not None]
    base = sum(a) / len(a); h = sum(b) / len(b); z = (h - base) * len(b) / math.sqrt(len(b) * base * (1 - base))
    res['333 any, without 09:50-10:05 and 15:50-16:05 | ±1m'] = dict(swing=round(h * 100, 2), base=round(base * 100, 2), ratio=round(h / base, 3), z=round(z, 2))
    return len(piv), res

out = {'from': str(START), 'to': str(END), 'swing': 'extreme of 30 minutes either side (1-minute bars)', 'assets': {}}
for name, sym in SYMS.items():
    if os.environ.get('SEQ_LOCAL'):
        j = json.load(open(os.environ['SEQ_LOCAL'] + f'/{name}_m1x.json'))['c']; c = sorted({x[0] // 1000: (x[0] // 1000, x[1], x[2], x[3], x[4]) for x in j}.values())
    else: c = sorted(load(sym))
    print(name, sym, len(c), 'bars'); sys.stdout.flush()
    if len(c) < (1000 if os.environ.get('SEQ_LOCAL') else 10000): continue
    np_, res = analyse(c); out['assets'][name] = {'bars': len(c), 'swings': np_, 'results': res}
os.makedirs('out', exist_ok=True); json.dump(out, open('out/seq_test.json', 'w'), indent=1)
# a readable report
L = [f"# Swings vs 222 / 333 / 414141 — {out['from']} to {out['to']}", '', f"Swing = {out['swing']}. Ratio = swings in the sequence ÷ random minutes in it (1.00 = chance). z above 3 is strong.", '']
cats = sorted({k for a in out['assets'].values() for k in a['results']})
L.append('| Sequence · tolerance | ' + ' | '.join(out['assets']) + ' |'); L.append('|---|' + '---|' * len(out['assets']))
for k in cats:
    row = [f"{a['results'][k]['ratio']}× (z {a['results'][k]['z']}, {a['results'][k]['base']}% of time)" if k in a['results'] else '—' for a in out['assets'].values()]
    L.append(f'| {k} | ' + ' | '.join(row) + ' |')
open('out/seq_test.md', 'w').write('\n'.join(L)); print('\n'.join(L))
