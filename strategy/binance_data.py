"""Public Binance spot klines (no API key) with a local pickle cache.
data-api.binance.vision is Binance's public market-data mirror; falls back to api.binance.com."""
import os, time, pickle, requests, pandas as pd
from concurrent.futures import ThreadPoolExecutor
HOSTS = ["https://data-api.binance.vision", "https://api.binance.com"]
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
MS = {"1m": 60_000, "3m": 180_000, "5m": 300_000, "15m": 900_000, "1h": 3_600_000, "1d": 86_400_000}

def _get(params):
    for i in range(6):
        for h in HOSTS:
            try:
                r = requests.get(h + "/api/v3/klines", params=params, timeout=20)
                if r.status_code == 200: return r.json()
            except requests.RequestException: pass
        time.sleep(1 + i)
    raise RuntimeError(f"klines failed {params}")

def klines(symbol, interval, start, end):
    """OHLCV DataFrame indexed by bar OPEN time (UTC), bars with open in [start, end)."""
    start = pd.Timestamp(start, tz="UTC") if pd.Timestamp(start).tzinfo is None else pd.Timestamp(start)
    end = pd.Timestamp(end, tz="UTC") if pd.Timestamp(end).tzinfo is None else pd.Timestamp(end)
    os.makedirs(CACHE, exist_ok=True)
    fn = os.path.join(CACHE, f"{symbol}_{interval}_{start:%Y%m%d%H%M}_{end:%Y%m%d%H%M}.pkl")
    if os.path.exists(fn): return pickle.load(open(fn, "rb"))
    for f in os.listdir(CACHE):                       # reuse any cached file covering the range
        if f.startswith(f"{symbol}_{interval}_") and f.endswith(".pkl"):
            try:
                a_, b_ = f[:-4].split("_")[2:4]
                if pd.to_datetime(a_, format="%Y%m%d%H%M", utc=True) <= start and pd.to_datetime(b_, format="%Y%m%d%H%M", utc=True) >= end:
                    d = pickle.load(open(os.path.join(CACHE, f), "rb")); return d[(d.index >= start) & (d.index < end)]
            except Exception: pass
    step = MS[interval] * 1000; s0 = int(start.timestamp() * 1000); e0 = int(end.timestamp() * 1000)
    chunks = list(range(s0, e0, step))
    with ThreadPoolExecutor(6) as ex:
        parts = list(ex.map(lambda s: _get({"symbol": symbol, "interval": interval, "startTime": s,
                                            "endTime": min(s + step, e0) - 1, "limit": 1000}), chunks))
    rows = [r for p in parts for r in p]
    df = pd.DataFrame(rows, columns="t open high low close vol ct qv n tb tq ig".split())
    df = df.drop_duplicates("t").sort_values("t")
    df.index = pd.to_datetime(df.t, unit="ms", utc=True); df.index.name = "time"
    df = df[["open", "high", "low", "close", "vol"]].astype(float)
    df = df[(df.index >= start) & (df.index < end)]
    pickle.dump(df, open(fn, "wb"))
    return df
