#!/usr/bin/env python3
"""Monkey Desk replay of the SCI-R strategy (SCI market-structure shift on Zakhm OSMA momentum lines,
preferred entry, H1 indication -> M15/M5 entries, SL floor 1.0x ATR14) from REAL backtest trades.
Inputs (local, not in this repo): the backtest trade list trades_sci_R_long_pref_atr10.csv and the 1m bars used by it.
   python3 run_sci_week.py --week 2026-10-12 [--start 1000 --risk 6.5 --default]
Each trade's P/L = R (net of spread+commission, from the backtest) x risk% x balance before the trade (compounding).
Hindsight replay: the trades were produced by the backtest on known data; nothing here was traded live."""
import argparse, json, os, csv
import numpy as np, pandas as pd
D = os.path.dirname(os.path.abspath(__file__))
BT = os.environ.get("SCI_BT", "/workspace/zakhm_backtest")
TRADES = os.path.join(BT, "trades_sci_R_long_pref_atr10.csv"); BARS = os.path.join(BT, "signals_long")
SHORT = {"BTCUSD": "BTC", "XAUUSD": "XAU"}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--week", required=True, help="Monday, YYYY-MM-DD (UTC)")
    ap.add_argument("--start", type=float, default=1000.0); ap.add_argument("--risk", type=float, default=6.5)
    ap.add_argument("--default", action="store_true", help="make this the page's default view")
    a = ap.parse_args()
    w0 = pd.Timestamp(a.week, tz="UTC"); w1 = w0 + pd.Timedelta(days=7)
    T = pd.read_csv(TRADES, parse_dates=["entry_time_utc", "exit_time_utc"])
    T = T[(T.entry_time_utc >= w0) & (T.entry_time_utc < w1)].sort_values("entry_time_utc").reset_index(drop=True)
    assert len(T), "no trades in that week"
    bars = {s: pd.read_pickle(f"{BARS}/{s}_1m.pkl") for s in T.symbol.unique()}
    data_end = min(b.index[-1] for b in bars.values()).ceil("1h")
    end = max(min(w1, data_end), T.exit_time_utc.max().ceil("1h") + pd.Timedelta(minutes=60))
    span = int((end - w0) / pd.Timedelta(minutes=1))
    mins = lambda t: round((t - w0) / pd.Timedelta(minutes=1), 2)
    bal = a.start; trades = []; rows = []
    for i, r in T.iterrows():
        d = 1 if r.side == "BUY" else -1; risk = bal * a.risk / 100; pnl = r.R * risk
        gross = (r.exit - r.entry) * d / r.sl_dist; fees = max(0.0, (gross - r.R) * risk)
        sym = SHORT.get(r.symbol, r.symbol)
        trades.append(dict(sym=sym, side=r.side, lev=round(r.entry / r.sl_dist, 4), levTxt=r.chart_tf, entry=r.entry, exit=r.exit,
                           pct=round(r.R * 100, 1), R=round(r.R, 2), pnl=round(pnl, 2), o=mins(r.entry_time_utc), c=mins(r.exit_time_utc),
                           margin=round(risk, 2), fees=round(fees, 2), reason=r.exit_reason, tf=r.chart_tf, sl=r.sl, tp=r.tp))
        rows.append([i + 1, r.symbol, r.side, r.chart_tf, r.entry_time_utc, r.exit_time_utc, r.entry, r.sl, r.tp, r.exit, r.exit_reason,
                     round(r.R, 3), round(bal, 2), round(risk, 2), round(pnl, 2), round(bal + pnl, 2)])
        bal += pnl
    # real 3m candles (gaps forward-filled so the page can index bars by time), from 8 h before the window
    candles = {}
    for s, b in bars.items():
        x = b[(b.index >= w0 - pd.Timedelta(hours=8)) & (b.index < end)]
        x = x.resample("3min", label="left", closed="left").agg(dict(open="first", high="max", low="min", close="last"))
        idx = pd.date_range(w0 - pd.Timedelta(hours=8), end - pd.Timedelta(minutes=3), freq="3min", tz="UTC"); x = x.reindex(idx)
        x["close"] = x.close.ffill().bfill()
        for k in ("open", "high", "low"): x[k] = x[k].fillna(x.close)
        dg = 2 if s in ("BTCUSD", "XAUUSD") else (3 if "JPY" in s else 5)
        candles[SHORT.get(s, s)] = dict(t0=mins(x.index[0]), o=[round(v, dg) for v in x.open], h=[round(v, dg) for v in x.high],
                                        l=[round(v, dg) for v in x.low], c=[round(v, dg) for v in x.close])
    # replay clock: trade windows get ~12x more screen time than quiet hours
    wgt = np.full(span + 1, 0.08)
    for t in trades: wgt[max(0, int(t["o"]) - 45):min(span, int(t["c"]) + 30) + 1] = 1.0
    cum = np.concatenate([[0], np.cumsum(wgt[:-1])]); cum /= cum[-1]
    tl = [[round(float(cum[m]), 5), m] for m in range(0, span, 30)] + [[1, span]]
    last = w0 + pd.Timedelta(minutes=span - 1)
    lab = f"{w0:%a} {w0.day} {w0:%b} – {last:%a} {last.day} {last:%b}"
    wins = sum(t["pnl"] > 0 for t in trades); sumR = round(float(T.R.sum()), 2)
    cfg = dict(day=0, dateLabel=lab, dateISO=f"{w0:%Y-%m-%d}", startBalance=a.start, endBalance=round(bal, 2), wins=int(wins),
               losses=len(trades) - int(wins), leverage=1, feesTotal=round(sum(t["fees"] for t in trades), 2),
               strategyName="SCI-R", strategyLong="SCI-R · ZAKHM LINES", span=span, duration=64, replayEnd=60, startMinute=0, timeline=tl,
               cur="KWD", rMode=True, periodWord="this week", riskPct=a.risk, voiceover=None,
               portfolioLabel="SCI-R · " + " ".join(dict.fromkeys(t["sym"] for t in trades)),
               feedLabel="real 1m candles (Dukascopy/HistData FX, Binance BTC)", slNote="failed high",
               checkList=["H1 indication > BS / NL", "M15+M5 shift, close past BS", "SL floor 1.0x ATR14", "session 07-21 UTC"],
               scoutIdle="H1 SCI setups on zakhm lines", pendingText="waiting for SCI-R setup",
               startText="SCI-R · zakhm lines · real backtest trades · hindsight replay",
               chartSym=trades[0]["sym"], trades=trades, candles=candles, events=[])
    name = f"sci_week_{w0:%Y-%m-%d}"
    os.makedirs(os.path.join(D, "data"), exist_ok=True)
    open(os.path.join(D, "data", f"{name}.js"), "w").write(
        "// generated by run_sci_week.py — SCI-R preferred (1.0x ATR floor) backtest trades + real candles, hindsight replay\nwindow.DAY_CONFIG=" + json.dumps(cfg) + ";\n")
    with open(os.path.join(D, "data", f"{name}_trades.csv"), "w", newline="") as f:
        wr = csv.writer(f); wr.writerow(["#", "symbol", "side", "entry_tf", "entry_utc", "exit_utc", "entry", "sl", "tp", "exit", "reason", "R_net", "bal_before_kwd", "risk_kwd", "pnl_kwd", "bal_after_kwd"]); wr.writerows(rows)
    summ = dict(week=f"{w0:%Y-%m-%d}", window_utc=[str(w0), str(end)], start_kwd=a.start, end_kwd=round(bal, 2), pct=round((bal / a.start - 1) * 100, 2),
                trades=len(trades), wins=int(wins), losses=len(trades) - int(wins), sum_R=sumR, risk_pct=a.risk,
                source="trades_sci_R_long_pref_atr10.csv (SCI-R preferred entry, H1 -> M15/M5, SL floor 1.0x ATR14, session 07-21 UTC, costs included)")
    json.dump(summ, open(os.path.join(D, "data", f"{name}_summary.json"), "w"), indent=1); print(json.dumps(summ, indent=1))
    idx_fn = os.path.join(D, "data", "index.json"); idx = json.load(open(idx_fn)) if os.path.exists(idx_fn) else []
    idx = [x for x in idx if x["file"] != f"data/{name}.js"]
    if a.default:
        for x in idx: x.pop("default", None)
    e = dict(file=f"data/{name}.js", date=f"{w0:%Y-%m-%d}", day=0, start=a.start, end=round(bal, 2), trades=len(trades), strategy="SCI-R",
             label=f"SCI-R (new) · week {lab} · {a.start:.0f} → {bal:.0f} KWD · {len(trades)} trades · {sumR:+.2f}R")
    if a.default: e["default"] = True
    idx.append(e)
    idx.sort(key=lambda x: (0 if x.get("strategy") == "SCI-R" else 1, x["date"] if x.get("strategy") != "SCI-R" else "", x["file"]), reverse=False)
    sci = sorted([x for x in idx if x.get("strategy") == "SCI-R"], key=lambda x: x["date"], reverse=True)
    old = [x for x in idx if x.get("strategy") != "SCI-R"]
    idx = sci + old
    json.dump(idx, open(idx_fn, "w"), indent=1); open(os.path.join(D, "data", "index.js"), "w").write("window.DAYS=" + json.dumps(idx) + ";\n")

if __name__ == "__main__": main()
