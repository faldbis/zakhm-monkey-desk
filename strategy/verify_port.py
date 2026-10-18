"""Sanity checks of the Pine port.
1) wick-mode 1h waves of ETHUSDT vs lines_full() of /workspace/zakhm-mtf/zakhm_signal.py (independent impl.)
2) print the latest zones (body mode) for ETHUSDT 1h and the zone state machine on 1h chart."""
import sys, pandas as pd, numpy as np
sys.path.insert(0, "/workspace/zakhm-mtf")
from binance_data import klines
from zakhm_zones import wave_engine, resample, Engine, tf_name
base = klines("ETHUSDT", "3m", "2026-05-19", "2026-10-17")
h1 = resample(base, "60")
_, LB, LS = wave_engine(h1, line_mode="wick")
mine = {(w["side"], w["t"]): w for w in
        [dict(v, side="buy") for v in {id(x): x for x in LB if x}.values()] + [dict(v, side="sell") for v in {id(x): x for x in LS if x}.values()]}
try:
    from zakhm_signal import lines_full
    ref = lines_full(h1[["open", "high", "low", "close"]])
    ref = [r for r in ref if r["end"] > 600]            # skip EMA warm-up (ref seeds EMA differently)
    ok = sum(1 for r in ref if (r["side"], h1.index[r["t"]]) in mine and abs(mine[(r["side"], h1.index[r["t"]])]["lvl"] - r["price"]) < 1e-9)
    print(f"[1] wick-mode waves vs zakhm_signal.lines_full (after warm-up): {ok}/{len(ref)} identical (peak bar + line price)")
except Exception as e: print("[1] skipped:", e)
_, LB, LS = wave_engine(h1, line_mode="body")
seen = []
for x in LB + LS:
    if x is not None and (not seen or seen[-1] is not x) and x not in seen: seen.append(x)
seen = sorted({(x["t"], x["lvl"], x["pk"] > 0, x["brk"]) for x in seen}, key=lambda r: r[0])
print("[2] last 12 completed ETHUSDT 1h waves (body lines):")
for t, lvl, buy, brk in seen[-12:]:
    print(f"   {'BUY ' if buy else 'SELL'} zone  peak bar {t:%Y-%m-%d %H:%M} UTC  line {lvl:.2f}  in-wave break: {brk if brk is not None else '-'}")
