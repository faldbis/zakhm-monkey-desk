"""ZAKHM OSMA day backtest on real Binance candles.
Signals: zakhm_zones.Engine (Pine port, chart TF 1H => TFs 66m/396m/D; 16m skipped as in f_ok).
Execution model (documented choices, not in the Pine):
  * entry  : market at the CLOSE of the 1H candle that crossed back through the broken line
             ("entry at the broken momentum level after a 1-hour candle holds")
  * SL     : line of the last opposite zone (same TF) formed after the break
  * TP     : extreme (body by default) of the strongest-OSMA bar of the explosion (break->return)
  * setups whose SL/TP are not on the correct side of the entry are skipped (logged)
  * exits checked on 3m candles; if SL and TP fall in the same 3m candle SL is assumed first
  * isolated margin = margin_pct of free cash, leverage L, liquidation at entry*(1 -/+ (1/L - mmr))
  * fees = taker_fee + slippage on notional, both sides; one position per symbol
  * positions still open at 24:00 UTC are closed at the day's last price (reason "eod")
Only entries whose signal candle closes inside the chosen UTC day are traded."""
import argparse, json, math, pandas as pd, numpy as np
from binance_data import klines
from zakhm_zones import Engine, tf_name

SYMS = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "XRPUSDT", "BNBUSDT"]

def load(sym, day, warm_days=150):
    d0 = pd.Timestamp(day, tz="UTC"); d1 = d0 + pd.Timedelta(days=1)
    import os, pickle
    from binance_data import CACHE
    base = None
    for f in sorted(os.listdir(CACHE)) if os.path.isdir(CACHE) else []:   # reuse a cached 3m file with >=120d warm-up
        if f.startswith(f"{sym}_3m_"):
            a_, b_ = f[:-4].split("_")[2:4]
            fa, fb = (pd.to_datetime(x, format="%Y%m%d%H%M", utc=True) for x in (a_, b_))
            if fa <= d0 - pd.Timedelta(days=120) and fb >= d1:
                base = pickle.load(open(os.path.join(CACHE, f), "rb")); base = base[base.index < d1]; break
    if base is None: base = klines(sym, "3m", d0 - pd.Timedelta(days=warm_days), d1)
    daily = klines(sym, "1d", d0 - pd.Timedelta(days=1100), d1)
    return base, daily

def signals_for(sym, day, line_mode="body", warm_days=150):
    base, daily = load(sym, day, warm_days)
    eng = Engine(base, chart_tf="60", tfs=("16", "66", "396", "D"), daily=daily, line_mode=line_mode)
    sig = eng.run()
    d0 = pd.Timestamp(day, tz="UTC"); d1 = d0 + pd.Timedelta(days=1)
    day_events = [(t, kind, z) for t, kind, z in eng.events if d0 <= t <= d1]
    return base, [s for s in sig if d0 <= s["time"] < d1], day_events, eng

def simulate(day, start_balance, lev=20, margin_pct=0.10, fee=0.0005, slip=0.0002, mmr=0.005, line_mode="body", syms=SYMS):
    d0 = pd.Timestamp(day, tz="UTC"); d1 = d0 + pd.Timedelta(days=1)
    data, cands, skipped, events = {}, [], [], []
    for s in syms:
        base, sig, ev, eng = signals_for(s, day, line_mode)
        data[s] = base[(base.index >= d0 - pd.Timedelta(hours=8)) & (base.index < d1)]
        for x in sig: x["sym"] = s; cands.append(x)
        for t, kind, z in ev: events.append(dict(time=t, sym=s, kind=kind, tf=tf_name(z.tf), side="buy" if z.is_buy else "sell", lvl=z.lvl))
    cands.sort(key=lambda x: x["time"])
    cash = start_balance; open_pos = {}; trades = []
    def close_pos(p, t, px, reason):
        nonlocal cash
        d = 1 if p["side"] == "BUY" else -1
        gross = p["qty"] * (px - p["entry"]) * d
        fees = p["qty"] * (p["entry"] + px) * (fee + slip)
        pnl = max(gross - fees, -p["margin"] - p["qty"] * p["entry"] * (fee + slip)) if reason == "liquidated" else gross - fees
        cash += p["margin"] + pnl
        trades.append(dict(p, exit=px, exit_time=t, pnl=pnl, fees=fees, roe=pnl / p["margin"] * 100, reason=reason))
    # walk 3m bars chronologically, opening positions at their signal time
    times = sorted(set().union(*[set(data[s].index[data[s].index >= d0]) for s in syms]))
    ci = 0
    for t in times:
        tclose = t + pd.Timedelta(minutes=3)
        # entries whose 1H candle closed at/before this 3m bar's open
        while ci < len(cands) and cands[ci]["time"] <= t:
            c = cands[ci]; ci += 1; s = c["sym"]; e = c["entry"]; d = 1 if c["side"] == "BUY" else -1
            why = None
            if s in open_pos: why = "position already open on symbol"
            elif not (np.isfinite(c["sl"]) and (e - c["sl"]) * d > 0): why = f"SL {c['sl']:.6g} not beyond entry"
            elif not ((c["tp"] - e) * d > 0): why = f"TP {c['tp']:.6g} not beyond entry"
            if why: skipped.append(dict(c, reason=why)); continue
            margin = cash * margin_pct; qty = margin * lev / e
            liq = e * (1 - d * (1 / lev - mmr))
            cash -= margin
            open_pos[s] = dict(sym=s, side=c["side"], lev=lev, entry=e, sl=c["sl"], tp=c["tp"], liq=liq, margin=margin, qty=qty,
                               entry_time=c["time"], tf=tf_name(c["tf"]), zone=c["zone"].label())
        for s in list(open_pos):
            p = open_pos[s]; df = data[s]
            if t not in df.index: continue
            hi, lo = df.high.at[t], df.low.at[t]; d = 1 if p["side"] == "BUY" else -1
            adverse = lo if d == 1 else hi; favor = hi if d == 1 else lo
            stop = max(p["sl"], p["liq"]) if d == 1 else min(p["sl"], p["liq"])
            if (adverse - stop) * d <= 0:
                liq_first = (p["liq"] - p["sl"]) * d >= 0
                close_pos(p, tclose, p["liq"] if liq_first else p["sl"], "liquidated" if liq_first else "stop loss"); del open_pos[s]
            elif (favor - p["tp"]) * d >= 0:
                close_pos(p, tclose, p["tp"], "take profit"); del open_pos[s]
    for s, p in list(open_pos.items()):
        close_pos(p, d1, float(data[s].close.iat[-1]), "eod"); del open_pos[s]
    trades.sort(key=lambda x: x["exit_time"])
    return dict(day=day, start=start_balance, end=cash, trades=trades, skipped=skipped, events=events, data=data,
                params=dict(lev=lev, margin_pct=margin_pct, fee=fee, slip=slip, mmr=mmr, line_mode=line_mode))

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", default="2026-10-16"); ap.add_argument("--start", type=float, default=431.25)
    ap.add_argument("--lev", type=float, default=20); ap.add_argument("--margin-pct", type=float, default=0.10)
    ap.add_argument("--line-mode", default="body", choices=["body", "wick"])
    a = ap.parse_args()
    r = simulate(a.date, a.start, a.lev, a.margin_pct, line_mode=a.line_mode)
    for t in r["trades"]:
        print(f"{t['entry_time']:%H:%M}->{t['exit_time']:%H:%M} {t['sym']} {t['side']} {t['tf']} entry {t['entry']:.6g} sl {t['sl']:.6g} tp {t['tp']:.6g} exit {t['exit']:.6g} {t['reason']} pnl {t['pnl']:+.2f}")
    for s in r["skipped"]: print("skipped", s["time"], s["sym"], s["side"], s["reason"])
    print(f"start {r['start']:.2f} end {r['end']:.2f}  events in day: {len(r['events'])}")
