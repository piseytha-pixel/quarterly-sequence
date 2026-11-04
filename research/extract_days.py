# Copy the cached 1-minute candles of a few example days into research/example_days.json (for drawing charts).
import json, gzip, os, datetime as dt
SYMS = {'NQ': 'USATECHIDXUSD', 'ES': 'USA500IDXUSD', 'YM': 'USA30IDXUSD', 'RTY': 'USSC2000IDXUSD'}
START = dt.date(2026, 8, 30); DAYS = [str(START + dt.timedelta(days=i)) for i in range(64)]   # UTC dates covering the NY trading days
out = {}
for n, sym in SYMS.items():
    rows = []
    for d in DAYS:
        fn = f'cache/{sym}_{d}.json.gz'
        if os.path.exists(fn): rows += json.load(gzip.open(fn, 'rt'))
    out[n] = sorted({r[0]: r for r in rows}.values())
    print(n, len(out[n]))
json.dump(out, gzip.open('research/example_days2.json.gz', 'wt'))
