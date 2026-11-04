# Which 222 / 333 / 414141 form the High - Low?
# Every 222 / 333 chain and every 414141 roll sits at a fixed clock time (same minutes every day; the Week level
# only adds depth on Tue = Q2 and Wed = Q3). So "which one" = "which clock time". For every instance this counts,
# over 12 months, how often the Day High or Low and the Session High or Low formed inside it (±5 min).
# lift = that rate ÷ the rate of an ordinary window of the same length (1.00 = an average time of day).
import json, os, math, gzip, datetime as dt, bisect
from zoneinfo import ZoneInfo
NY = ZoneInfo('America/New_York')
SYMS = {'NQ': 'USATECHIDXUSD', 'ES': 'USA500IDXUSD', 'YM': 'USA30IDXUSD', 'RTY': 'USSC2000IDXUSD'}
END = dt.date.today() - dt.timedelta(days=1); START = END - dt.timedelta(days=365)
CACHE = 'cache'; PAD = 5

def load(sym):
    out = []
    for i in range((END - START).days + 1):
        fn = f'{CACHE}/{sym}_{START + dt.timedelta(days=i)}.json.gz'
        if os.path.exists(fn): out += json.load(gzip.open(fn, 'rt'))
    return sorted({x[0]: tuple(x) for x in out}.values())

def lv_at(sec, wk):
    m = sec / 60; sh = 1080 if m >= 1080 else 0 if m < 360 else 360 if m < 720 else 720
    day = {1080: 1, 0: 2, 360: 3, 720: 4}[sh]; r = m - sh
    q90 = min(int(r // 90), 3) + 1; r -= (q90 - 1) * 90
    mc = min(int(r // 22.5), 3) + 1; r -= (mc - 1) * 22.5
    na = min(int(r // 5.625), 3) + 1; r -= (na - 1) * 5.625
    pi = min(int(r // 1.40625), 3) + 1
    return [wk, day, q90, mc, na, pi]
NAMES = ['WK', 'DY', '90', 'MC', 'NA', 'PI']
def labels(L):
    # every chain that starts at its top level: e.g. 222 DY·90·MC stays one chain while the Nano also turns Q2
    out = []
    for q in (2, 3):
        for i in range(6):
            if L[i] != q or (i > 0 and L[i - 1] == q): continue
            j = i
            while j + 1 < 6 and L[j + 1] == q: j += 1
            for k in range(i + 2, j + 1): out.append(f'{q}{q}{q} ' + '·'.join(NAMES[i:k + 1]))
    return out

# ── every instance: (weekday quarter or None, label, start sec, end sec)
INST = {}
for wk in (1, 2, 3, 4):
    cur = {}
    for sec in range(0, 86400, 3):
        for lab in labels(lv_at(sec, wk)):
            k = (lab, ); s = cur.get(lab)
            if s is not None and s[1] == sec - 3: cur[lab] = (s[0], sec)
            else:
                if s: INST.setdefault((wk, lab, s[0]), s[1] + 3)
                cur[lab] = (sec, sec)
    for lab, s in cur.items(): INST.setdefault((wk, lab, s[0]), s[1] + 3)
    for sec in range(0, 86400):
        a, b = lv_at(sec - 1 if sec else 86399, wk), lv_at(sec, wk)
        best = cur2 = 0
        for x, y in zip(a[1:], b[1:]):
            cur2 = cur2 + 1 if (x == 4 and y == 1) else 0; best = max(best, cur2)
        if best >= 3: INST[(wk, f'414141 ×{best}', sec)] = sec + 60
# merge: an instance that does not use the Week level is the same on every weekday
merged = {}
for (wk, lab, s), e in INST.items():
    key = (None if 'WK' not in lab else wk, lab, s)
    merged.setdefault(key, (e, set()))[1].add(wk)

def wk_of(td): return {0: 1, 1: 2, 2: 3, 3: 4, 4: 4}.get(td.weekday())

def extremes(c):
    # per trading day: Day High / Low minute, and each Session High / Low minute (seconds after midnight NY)
    days = {}
    for x in c:
        d = dt.datetime.fromtimestamp(x[0], NY); td = (d + dt.timedelta(hours=6)).date()
        days.setdefault(td, []).append((d.hour * 3600 + d.minute * 60, x[2], x[3], d.hour))
    out = []
    for td, bars in days.items():
        if len(bars) < 900 or wk_of(td) is None: continue
        sec_of = lambda b: b[0]
        hiD = max(bars, key=lambda b: b[1]); loD = min(bars, key=lambda b: b[2])
        ses = {}
        for b in bars:
            k = 0 if b[3] >= 18 else 1 if b[3] < 6 else 2 if b[3] < 12 else 3
            ses.setdefault(k, []).append(b)
        sH = [max(v, key=lambda b: b[1])[0] for v in ses.values() if len(v) > 200]
        sL = [min(v, key=lambda b: b[2])[0] for v in ses.values() if len(v) > 200]
        out.append(dict(wk=wk_of(td), day=[hiD[0], loD[0]], sess=sH + sL))
    return out

def inside(t, s, e):
    a, b = (s - PAD * 60) % 86400, (e + PAD * 60) % 86400
    return a <= t < b if a < b else (t >= a or t < b)

report = {'from': str(START), 'to': str(END), 'pad_min': PAD, 'rows': []}
EX = {n: extremes(load(sym)) for n, sym in SYMS.items()}
EX = {n: v for n, v in EX.items() if v}
print({n: len(v) for n, v in EX.items()}, flush=True)
# baseline: chance for a window of length w = share of (day, extreme) pairs falling in a random window of that length
def base(ex_list, key, w, wkset):
    tot = n = 0
    for d in ex_list:
        if d['wk'] not in wkset: continue
        ts = d[key]; n += 1
        # probability a random window of width w (sec) contains at least one of ts, averaged over positions (step 5 min)
        hits = 0
        for st in range(0, 86400, 300):
            if any(inside(t, st, st + w - 2 * PAD * 60) for t in ts): hits += 1
        tot += hits / (86400 / 300)
    return tot / n if n else float('nan')
bcache = {}
for (wk, lab, s), (e, wks) in sorted(merged.items(), key=lambda kv: kv[0][2]):
    wkset = {wk} if wk else {1, 2, 3, 4}
    row = {'label': lab, 'weekday': {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu/Fri'}.get(wk, 'every day'),
           'start': f'{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}', 'end': f'{e // 3600:02d}:{e % 3600 // 60:02d}:{e % 60:02d}', 'assets': {}}
    w = (e - s) + 2 * PAD * 60
    for n, ex in EX.items():
        for key in ('day', 'sess'):
            days = [d for d in ex if d['wk'] in wkset]
            if not days: continue
            hit = sum(1 for d in days if any(inside(t, s, e) for t in d[key])) / len(days)
            bk = (n, key, round(w / 60), tuple(sorted(wkset)))
            if bk not in bcache: bcache[bk] = base(ex, key, w, wkset)
            b = bcache[bk]; z = (hit - b) * len(days) / math.sqrt(len(days) * b * (1 - b)) if 0 < b < 1 else 0
            row['assets'].setdefault(n, {})[key] = dict(days=len(days), hit=round(hit * 100, 1), base=round(b * 100, 1), lift=round(hit / b, 2) if b else None, z=round(z, 2))
    report['rows'].append(row)
os.makedirs('out', exist_ok=True); json.dump(report, open('out/which_test.json', 'w'), indent=1)
def avg(r, key, f): v = [a[key][f] for a in r['assets'].values() if key in a and a[key][f] is not None]; return sum(v) / len(v) if v else 0
R = sorted(report['rows'], key=lambda r: -avg(r, 'day', 'lift'))
L = [f"# Which 222 / 333 / 414141 form the High - Low — {report['from']} to {report['to']}", '',
     f'Times are New York. Window = the chain ±{PAD} min. hit = share of days the Day (or Session) High or Low formed inside it; lift = hit ÷ an ordinary window of the same length. Averages over NQ, ES, YM, RTY.', '',
     '| Sequence | Weekday | NY time | Day H/L hit | Day lift | Session H/L hit | Session lift | min z (Day) |', '|---|---|---|---|---|---|---|---|']
for r in R:
    zs = [a['day']['z'] for a in r['assets'].values() if 'day' in a]
    L.append(f"| {r['label']} | {r['weekday']} | {r['start'][:5]}–{r['end'][:5]} | {avg(r,'day','hit'):.1f}% | {avg(r,'day','lift'):.2f}× | {avg(r,'sess','hit'):.1f}% | {avg(r,'sess','lift'):.2f}× | {min(zs) if zs else 0:.1f} |")
open('out/which_test.md', 'w').write('\n'.join(L)); print('\n'.join(L[:40]))
