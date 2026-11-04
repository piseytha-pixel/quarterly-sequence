# Are the High - Low of the week / day / session / 90 min, and SSMT points, timed by 222 / 333 / 414141?
# 12 months of Dukascopy 1-minute candles (NQ, ES, YM, RTY). Results are compared with
#   (a) chance: how much of the time the sequence is active in the same cycles, and
#   (b) a shuffled market: the same candles in random order inside each day, which keeps the
#       "extremes sit at the edges of a window" effect but removes any real clock timing.
import lzma, struct, json, math, os, random, datetime as dt, urllib.request, gzip
from concurrent.futures import ThreadPoolExecutor
from zoneinfo import ZoneInfo
NY = ZoneInfo('America/New_York'); UTC = dt.timezone.utc
SYMS = {'NQ': 'USATECHIDXUSD', 'ES': 'USA500IDXUSD', 'YM': 'USA30IDXUSD', 'RTY': 'USSC2000IDXUSD'}
END = dt.date.today() - dt.timedelta(days=1); START = END - dt.timedelta(days=int(os.environ.get('HL_DAYS', '365')))
CACHE = 'cache'; os.makedirs(CACHE, exist_ok=True)
UA = {'User-Agent': 'Mozilla/5.0'}
random.seed(7)

def day_file(sym, d):
    fn = f'{CACHE}/{sym}_{d}.json.gz'
    if os.path.exists(fn) and d < END:
        return json.load(gzip.open(fn, 'rt'))
    if d.weekday() == 5: return []
    u = f'https://datafeed.dukascopy.com/datafeed/{sym}/{d.year}/{d.month-1:02d}/{d.day:02d}/BID_candles_min_1.bi5'
    err = None
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
        except Exception as e:
            err = e
    print('  failed', sym, d, err); return []

def load(sym):
    if os.environ.get('HL_LOCAL'):
        n = [k for k, v in SYMS.items() if v == sym][0]; j = json.load(open(os.environ['HL_LOCAL'] + f'/{n}_m1x.json'))['c']
        return sorted({x[0] // 1000: (x[0] // 1000, x[1], x[2], x[3], x[4]) for x in j}.values())
    days = [START + dt.timedelta(days=i) for i in range((END - START).days + 1)]
    with ThreadPoolExecutor(8) as ex: parts = list(ex.map(lambda d: day_file(sym, d), days))
    return sorted({x[0]: tuple(x) for p in parts for x in p}.values())

# ── the quarter clock (the app's rules)
def lv_at(sec, wk):
    m = sec / 60; sh = 1080 if m >= 1080 else 0 if m < 360 else 360 if m < 720 else 720
    day = {1080: 1, 0: 2, 360: 3, 720: 4}[sh]; r = m - sh
    q90 = min(int(r // 90), 3) + 1; r -= (q90 - 1) * 90
    mc = min(int(r // 22.5), 3) + 1; r -= (mc - 1) * 22.5
    na = min(int(r // 5.625), 3) + 1; r -= (na - 1) * 5.625
    pi = min(int(r // 1.40625), 3) + 1
    return [wk, day, q90, mc, na, pi]
NAMES = ['WK', 'DY', '90', 'MC', 'NA', 'PI']
def runs(L, q):
    out = set(); i = 0
    while i < len(L):
        if L[i] == q:
            j = i
            while j + 1 < len(L) and L[j + 1] == q: j += 1
            if j - i + 1 >= 3: out.add('·'.join(NAMES[i:j + 1]))
            i = j + 1
        else: i += 1
    return out
CATS = {}
def add(c, k): CATS.setdefault(c, set()).add(k)
for wk in (1, 2, 3, 4):
    for minute in range(1440):
        for s5 in range(0, 60, 5):
            for q, nm in ((2, '222'), (3, '333')):
                for r in runs(lv_at(minute * 60 + s5, wk), q):
                    add(nm + ' any', (wk, minute))
                    if r.endswith('MC·NA·PI'): add(nm + ' Pico (MC·NA·PI)', (wk, minute))
                    if r == '90·MC·NA': add(nm + ' DOOR (90·MC·NA)', (wk, minute))
        for s in range(60):
            sec = minute * 60 + s
            a, b = lv_at(sec - 1 if sec else 86399, wk), lv_at(sec, wk)
            best = cur = 0
            for x, y in zip(a[1:], b[1:]):
                cur = cur + 1 if (x == 4 and y == 1) else 0; best = max(best, cur)
            if best >= 3: add('414141', (wk, minute))
        if minute % 30 == 0: add('control: :00 / :30', (wk, minute))
        if minute % 30 == 15: add('control: :15 / :45', (wk, minute))
ORDER = ['414141', '222 any', '222 Pico (MC·NA·PI)', '222 DOOR (90·MC·NA)', '333 any', '333 Pico (MC·NA·PI)', '333 DOOR (90·MC·NA)', 'control: :00 / :30', 'control: :15 / :45']
TOLS = (0, 1, 5)
DIL = {(c, t): {(wk, (m + d) % 1440) for (wk, m) in CATS[c] for d in range(-t, t + 1)} for c in ORDER for t in TOLS}

def keyinfo(ts):
    d = dt.datetime.fromtimestamp(ts, NY); m = d.hour * 60 + d.minute
    td = (d + dt.timedelta(hours=6)).date()                       # trading day (starts 18:00 the evening before)
    wk = {0: 1, 1: 2, 2: 3, 3: 4, 4: 4}.get(td.weekday())
    sess = 0 if m >= 1080 else 1 if m < 360 else 2 if m < 720 else 3
    rem = (m - (1080 if sess == 0 else (sess - 1) * 360)) % 1440
    iso = td.isocalendar()
    return wk, m, {'Week': (iso[0], iso[1]), 'Day': td, 'Session': (td, sess), '90 min': (td, sess, int(rem // 90))}

def extremes(H, L, cyc, minfrac=0.7):
    # minute index of the High and of the Low of every cycle with enough data
    groups = {}
    for i, k in enumerate(cyc): groups.setdefault(k, []).append(i)
    big = max(len(v) for v in groups.values()); out = []
    for k, idx in groups.items():
        if len(idx) < minfrac * big: continue
        out.append(max(idx, key=lambda i: H[i])); out.append(min(idx, key=lambda i: L[i]))
    return out, [i for k, idx in groups.items() if len(idx) >= minfrac * big for i in idx]

def shuffled(c):
    # same candles, random order inside each trading day (gaps, wicks and bodies kept as moves)
    out = []; day = {}
    for x in c: day.setdefault(keyinfo(x[0])[2]['Day'], []).append(x)
    for d in sorted(day):
        bars = day[d]; mv = [(b[1] - p[4], b[2] - b[1], b[3] - b[1], b[4] - b[1]) for p, b in zip(bars, bars[1:])]
        random.shuffle(mv); price = bars[0][4]; out.append(bars[0])
        for b, (g, rh, rl, rc) in zip(bars[1:], mv):
            o = price + g; out.append((b[0], o, o + rh, o + rl, o + rc)); price = o + rc
    return out

def rate(idxs, flag): return sum(flag[i] for i in idxs) / len(idxs) if idxs else float('nan')

def swings(c, k=15):
    H = [x[2] for x in c]; L = [x[3] for x in c]; T = [x[0] for x in c]; hi = []; lo = []
    for i in range(k, len(c) - k):
        if T[i + k] - T[i - k] > (2 * k + 20) * 60: continue
        if H[i] == max(H[i - k:i + k + 1]): hi.append(i)
        if L[i] == min(L[i - k:i + k + 1]): lo.append(i)
    return hi, lo

report = {'from': str(START), 'to': str(END), 'cycles': {}, 'ssmt': {}}
data = {}
for name, sym in SYMS.items():
    data[name] = load(sym); print(name, len(data[name]), 'bars', flush=True)

# ── 1. High - Low of the week, day, session and 90 min
for name, c in data.items():
    if len(c) < (1000 if os.environ.get('HL_LOCAL') else 10000): continue
    K = [keyinfo(x[0]) for x in c]; key = [(k[0], k[1]) for k in K]
    flag = {(cat, t): [kk in DIL[(cat, t)] for kk in key] for cat in ORDER for t in TOLS}
    sh = [shuffled(c) for _ in range(5)]
    for lvl in ('Week', 'Day', 'Session', '90 min'):
        cyc = [k[2][lvl] for k in K]
        ev, members = extremes([x[2] for x in c], [x[3] for x in c], cyc)
        shev = [extremes([x[2] for x in s], [x[3] for x in s], cyc)[0] for s in sh]
        R = report['cycles'].setdefault(lvl, {}).setdefault(name, {'events': len(ev)})
        for cat in ORDER:
            for t in TOLS:
                f = flag[(cat, t)]; act = rate(ev, f); base = rate(members, f)
                ctl = sum(rate(e, f) for e in shev) / len(shev)
                n = len(ev); z = (act - ctl) * n / math.sqrt(n * ctl * (1 - ctl)) if 0 < ctl < 1 else None
                R[f'{cat} | ±{t}m'] = dict(actual=round(act * 100, 2), chance=round(base * 100, 2), shuffled=round(ctl * 100, 2), vs_shuffled=round(act / ctl, 2) if ctl else None, z=round(z, 2) if z is not None else None)
    print(name, 'cycles done', flush=True)

# ── 2. SSMT: one index makes a lower low (higher high) while another does not, at the same swing
idx = {n: {x[0]: i for i, x in enumerate(c)} for n, c in data.items()}
SW = {n: swings(c) for n, c in data.items() if len(c) > (1000 if os.environ.get('HL_LOCAL') else 10000)}
def prev_sw(lst, i, T, within=6 * 3600):
    import bisect
    j = bisect.bisect_left(lst, i) - 1
    return lst[j] if j >= 0 and T[i] - T[lst[j]] <= within else None
TT = {n: [x[0] for x in data[n]] for n in SW}; SWS = {n: (set(SW[n][0]), set(SW[n][1])) for n in SW}
events = {'SSMT': [], 'no divergence (all agree)': []}
names = list(SW)
for side in ('lo', 'hi'):
    for a in names:
        ca = data[a]; Ta = TT[a]; lst = SW[a][1 if side == 'lo' else 0]
        for i in lst:
            j = prev_sw(lst, i, Ta)
            if j is None: continue
            v = 3 if side == 'lo' else 2
            took = ca[i][v] < ca[j][v] if side == 'lo' else ca[i][v] > ca[j][v]
            if not took: continue
            div = agree = 0
            for b in names:
                if b == a: continue
                cb = data[b]; Tb = TT[b]; lb = SW[b][1 if side == 'lo' else 0]; lbs = SWS[b][1 if side == 'lo' else 0]
                cand = [k for k in (idx[b].get(Ta[i] + d * 60) for d in range(-3, 4)) if k is not None and k in lbs]
                if not cand: continue
                k = cand[0]; pj = prev_sw(lb, k, Tb)
                if pj is None: continue
                tb = cb[k][v] < cb[pj][v] if side == 'lo' else cb[k][v] > cb[pj][v]
                if tb: agree += 1
                else: div += 1
            if div: events['SSMT'].append(Ta[i])
            elif agree: events['no divergence (all agree)'].append(Ta[i])
for kind, tsl in events.items():
    ded = []
    for t in sorted(set(tsl)):
        if not ded or t - ded[-1] >= 300: ded.append(t)
    tsl = ded
    keys = [keyinfo(t)[:2] for t in tsl]
    R = report['ssmt'].setdefault(kind, {'events': len(tsl)})
    allkeys = [keyinfo(x[0])[:2] for x in data['NQ']]
    for cat in ORDER:
        for t in TOLS:
            S = DIL[(cat, t)]; act = sum(k in S for k in keys) / max(1, len(keys)); base = sum(k in S for k in allkeys) / len(allkeys)
            n = len(keys); z = (act - base) * n / math.sqrt(max(1e-9, n * base * (1 - base)))
            R[f'{cat} | ±{t}m'] = dict(actual=round(act * 100, 2), chance=round(base * 100, 2), vs_chance=round(act / base, 2) if base else None, z=round(z, 2))

os.makedirs('out', exist_ok=True); json.dump(report, open('out/hl_test.json', 'w'), indent=1, default=str)
L = [f"# High - Low and SSMT vs 222 / 333 / 414141 — {report['from']} to {report['to']}", '',
     'vs shuffled = how often the real High - Low sits in the sequence ÷ how often it does when the same candles are shuffled inside each day (1.00 = no real timing). z above 3 is strong.', '']
for lvl, A in report['cycles'].items():
    L += [f'## High - Low of the {lvl}', '', '| Sequence | ' + ' | '.join(f'{a} ({A[a]["events"]})' for a in A) + ' |', '|---|' + '---|' * len(A)]
    for cat in ORDER:
        for t in TOLS:
            k = f'{cat} | ±{t}m'
            L.append(f'| {k.replace(" | ", " · ")} | ' + ' | '.join(f"{A[a][k]['actual']}% vs {A[a][k]['shuffled']}% → {A[a][k]['vs_shuffled']}× (z {A[a][k]['z']})" for a in A) + ' |')
    L.append('')
L += ['## SSMT points', '', '| Sequence | ' + ' | '.join(f'{k} ({v["events"]})' for k, v in report['ssmt'].items()) + ' |', '|---|' + '---|' * len(report['ssmt'])]
for cat in ORDER:
    for t in TOLS:
        k = f'{cat} | ±{t}m'
        L.append(f'| {k.replace(" | ", " · ")} | ' + ' | '.join(f"{v[k]['actual']}% vs {v[k]['chance']}% → {v[k]['vs_chance']}× (z {v[k]['z']})" for v in report['ssmt'].values()) + ' |')
open('out/hl_test.md', 'w').write('\n'.join(L)); print('\n'.join(L[:60]))
