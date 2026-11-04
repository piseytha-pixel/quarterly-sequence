# Copy the cached 1-minute candles of a few example days into research/example_days.json (for drawing charts).
import json, gzip, os, datetime as dt
SYMS = {'NQ': 'USATECHIDXUSD', 'ES': 'USA500IDXUSD', 'YM': 'USA30IDXUSD', 'RTY': 'USSC2000IDXUSD'}
DAYS = ['2026-10-14', '2026-10-15', '2026-10-16', '2026-10-27', '2026-10-28', '2026-10-29']   # UTC dates covering the NY trading days
out = {}
for n, sym in SYMS.items():
    rows = []
    for d in DAYS:
        fn = f'cache/{sym}_{d}.json.gz'
        if os.path.exists(fn): rows += json.load(gzip.open(fn, 'rt'))
    out[n] = sorted({r[0]: r for r in rows}.values())
    print(n, len(out[n]))
json.dump(out, open('research/example_days.json', 'w'))
