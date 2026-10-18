"""
ZAKHM OSMA — Python port of the user's TradingView Pine v5 indicator "OSMA Momentum Zones"
(strategy/osma_zones.pine) + the exit rules of the user's زخم strategy.

Pine  ->  Python map
---------------------------------------------------------------------------------------------
f_osma() (inside request.security)      -> wave_engine(): per-TF OSMA, positive/negative waves,
                                           peak-OSMA bar, in-wave break time, "last completed
                                           wave" series lb*/ls* (one value per TF bar).
request.security(..., lookahead_on) +   -> visible_index(): on a chart bar that opens at T the
[off]=1 for higher TFs                     newest visible HTF bar is the last one whose CLOSE <= T
                                           (=> no lookahead, no repaint). off=0 (TF == chart TF):
                                           the bar itself at its close.
nb*/ns*/nc* "new value" flags           -> compare visible lb*/ls*/close-time with previous chart bar
Zone type, f_newZone, f_break, cap maxZ -> Zone dataclass, Engine._new_zone, Engine._break
state machine (barstate.isconfirmed)    -> Engine.step(): 0 active -> 1 broken (own-TF close
                                           through the line) -> 2 returned (own-TF close back) ->
                                           3 armed (opposite zone of same TF formed after the break)
                                           -> 4 entry (chart close crosses the line again).
f_ok (skip TFs below chart TF)          -> tfs filtered in Engine.__init__
EMA                                     -> pine_ema(): SMA seed then recursive, same as ta.ema.

Additions that are NOT in the Pine (the Pine only draws zones/entries):
* line_mode="body" (default, the user's rule "lines at candle bodies, not wicks"): buy-zone line =
  min(open,close) of the peak bar, sell-zone line = max(open,close).  line_mode="wick" reproduces
  the Pine exactly (buy line = low, sell line = high).
* Exits (see zakhm_backtest.py): SL = line of the last opposite zone of the same TF that armed the
  setup ("SL at the last opposite momentum"); TP = extreme of the strongest-OSMA bar of the same TF
  during the explosion (break -> return) phase, i.e. the momentum that broke the line
  (same convention as /workspace/zakhm-mtf/zakhm_signal.py variant M2).
Trade side: a broken+returned BUY zone gives a SELL entry, a broken+returned SELL zone a BUY entry
(exactly like the Pine labels).
"""
from dataclasses import dataclass, field
import numpy as np, pandas as pd

TF_MIN = {"16": 16, "66": 66, "396": 396, "D": 1440, "60": 60, "240": 240}

def tf_name(tf):
    m = TF_MIN[tf]
    return f"{m}m" if m < 60 else (f"{m//60}H" if m < 1440 and m % 60 == 0 else ("D" if m == 1440 else f"{m}m"))

def pine_ema(x, n):
    """ta.ema: na until n valid values, seeded with their SMA, then alpha recursion."""
    x = np.asarray(x, float); out = np.full(len(x), np.nan); a = 2.0 / (n + 1)
    valid = np.where(~np.isnan(x))[0]
    if len(valid) < n: return out
    s = valid[0] + n - 1
    out[s] = np.nanmean(x[valid[0]:s + 1])
    for i in range(s + 1, len(x)):
        out[i] = a * x[i] + (1 - a) * out[i - 1] if not np.isnan(x[i]) else out[i - 1]
    return out

def pine_atr(h, l, c, n):
    pc = np.r_[np.nan, c[:-1]]
    tr = np.where(np.isnan(pc), h - l, np.maximum(h - l, np.maximum(abs(h - pc), abs(l - pc))))
    out = np.full(len(tr), np.nan); a = 1.0 / n           # ta.atr = RMA
    if len(tr) >= n:
        out[n - 1] = tr[:n].mean()
        for i in range(n, len(tr)): out[i] = a * tr[i] + (1 - a) * out[i - 1]
    return out

def resample(df, tf):
    """TradingView-style bars of `tf` minutes built from lower-TF data, anchored to 00:00 UTC each day
    (non-divisor TFs like 66m/396m get a shorter last bar of the day). Adds 'ct' = bar close time."""
    m = TF_MIN[tf]
    if m == 1440:
        key = df.index.floor("1D")
    else:
        day = df.index.floor("1D"); mins = (df.index - day) // pd.Timedelta(minutes=1)
        key = day + pd.to_timedelta((mins // m) * m, unit="min")
    g = df.groupby(key).agg(open=("open", "first"), high=("high", "max"), low=("low", "min"), close=("close", "last"))
    day = g.index.floor("1D")
    g["ct"] = np.minimum(g.index + pd.Timedelta(minutes=m), day + pd.Timedelta(days=1))
    base = df.index[1] - df.index[0]
    g = g[g.ct <= df.index[-1] + base]                     # complete bars only
    return g

def wave_engine(df, fast=132, slow=32, sig=16, line_mode="body", atr_len=14, atr_mult=0.25, atr_mode=True, mintick=1e-8):
    """Bar-by-bar copy of f_osma(). Returns (osma array, per-bar last-completed buy/sell wave dicts)."""
    o_, h, l, c = (df[k].values for k in ("open", "high", "low", "close"))
    t = df.index
    m = pine_ema(c, fast) - pine_ema(c, slow); osma = m - pine_ema(m, sig); atr = pine_atr(h, l, c, atr_len)
    gt = lambda v: (not np.isnan(v)) and v > 0
    lt = lambda v: (not np.isnan(v)) and v < 0
    b = dict(pk=np.nan); s = dict(pk=np.nan); lb = None; ls = None
    LB, LS = [None] * len(c), [None] * len(c)
    for i in range(len(c)):
        o = osma[i]; prevPos = i > 0 and gt(osma[i - 1]); prevNeg = i > 0 and lt(osma[i - 1])
        if gt(o):
            if not prevPos or o > b["pk"]:
                top = max(l[i] + atr[i] * atr_mult if (atr_mode and not np.isnan(atr[i])) else min(o_[i], c[i]), l[i] + mintick)
                lvl = l[i] if line_mode == "wick" else min(o_[i], c[i])
                b = dict(pk=o, t=t[i], i=i, bot=l[i], top=top, lvl=lvl, brk=None, brk_i=None)
            elif b["brk"] is None and c[i] < b["lvl"]:
                b["brk"], b["brk_i"] = t[i], i
        if not gt(o) and prevPos and not np.isnan(b["pk"]):
            if b["brk"] is None and c[i] < b["lvl"]: b["brk"], b["brk_i"] = t[i], i
            lb = dict(b, end_i=i)
        if lt(o):
            if not prevNeg or o < s["pk"]:
                bot = min(h[i] - atr[i] * atr_mult if (atr_mode and not np.isnan(atr[i])) else max(o_[i], c[i]), h[i] - mintick)
                lvl = h[i] if line_mode == "wick" else max(o_[i], c[i])
                s = dict(pk=o, t=t[i], i=i, top=h[i], bot=bot, lvl=lvl, brk=None, brk_i=None)
            elif s["brk"] is None and c[i] > s["lvl"]:
                s["brk"], s["brk_i"] = t[i], i
        if not lt(o) and prevNeg and not np.isnan(s["pk"]):
            if s["brk"] is None and c[i] > s["lvl"]: s["brk"], s["brk_i"] = t[i], i
            ls = dict(s, end_i=i)
        LB[i], LS[i] = lb, ls
    return osma, LB, LS

@dataclass
class Zone:
    tf: str; is_buy: bool; top: float; bot: float; lvl: float; osma: float; t0: pd.Timestamp; pk_i: int
    state: int = 0; broke_t: pd.Timestamp = None; broke_i: int = None; opp_seen: bool = False
    opp: "Zone" = None; ret_i: int = None; zid: int = 0
    def label(self): return f"{tf_name(self.tf)} {'buy' if self.is_buy else 'sell'} zone {self.lvl:.6g} @ {self.t0:%m-%d %H:%M}"

class Engine:
    """Runs the Pine bar-close logic on a chart TF built from base (lower-TF) data."""
    def __init__(self, base, chart_tf="60", tfs=("16", "66", "396", "D"), daily=None, max_z=20, **wave_kw):
        self.chart = resample(base, chart_tf)
        self.chart_tf = chart_tf; self.max_z = max_z; self.wave_kw = wave_kw
        self.tfs = [tf for tf in tfs if TF_MIN[tf] >= TF_MIN[chart_tf]]          # f_ok
        self.htf = {}
        for tf in self.tfs:
            if tf == "D" and daily is not None: d = daily.copy(); d["ct"] = d.index + pd.Timedelta(days=1)
            else:
                bm = (base.index[1] - base.index[0]) // pd.Timedelta(minutes=1)
                if TF_MIN[tf] % bm: raise ValueError(f"TF {tf} not buildable from {bm}m data")
                d = resample(base, tf)
            osma, LB, LS = wave_engine(d, **wave_kw)
            self.htf[tf] = dict(df=d, osma=osma, LB=LB, LS=LS, ct=d.ct.values, off=0 if tf == chart_tf else 1)
        self.zones = []; self.events = []; self.signals = []; self._zid = 0

    def visible_index(self, tf, bar_open, bar_close):
        H = self.htf[tf]; lim = bar_close if H["off"] == 0 else bar_open
        return int(np.searchsorted(H["ct"], np.datetime64(lim.tz_convert(None)), side="right")) - 1

    def _break(self, z, t, i): z.state, z.broke_t, z.broke_i = 1, t, i

    def _new_zone(self, tf, is_buy, w, now):
        self._zid += 1
        z = Zone(tf, is_buy, w["top"], w["bot"], w["lvl"], w["pk"], w["t"], w["i"], zid=self._zid)
        if w["brk"] is not None: self._break(z, w["brk"], w["brk_i"])
        for oz in self.zones:                                                    # step-3 helper
            if oz.tf == tf and oz.is_buy != is_buy and oz.state in (1, 2):
                oz.opp_seen = True; oz.opp = z
        self.zones.append(z); self.events.append((now, "zone", z))
        same = [k for k, oz in enumerate(self.zones) if oz.tf == tf and oz.is_buy == is_buy]
        if len(same) > self.max_z: self.zones.pop(same[0])

    def _arm(self, z, now): z.state = 3; self.events.append((now, "armed", z))

    def _tp(self, z):
        """extreme of the strongest-OSMA bar of the zone TF during break -> return (explosion)."""
        H = self.htf[z.tf]; d = H["df"]; a, b = z.broke_i, z.ret_i
        seg = H["osma"][a:b + 1]
        k = a + (int(np.nanargmin(seg)) if z.is_buy else int(np.nanargmax(seg)))
        mode = self.wave_kw.get("line_mode", "body")
        if z.is_buy:  # explosion was downward -> target below
            return d.low.iat[k] if mode == "wick" else min(d.open.iat[k], d.close.iat[k])
        return d.high.iat[k] if mode == "wick" else max(d.open.iat[k], d.close.iat[k])

    def run(self):
        C = self.chart; close = C.close.values; prev = {tf: (-1, None, None) for tf in self.tfs}
        for j in range(len(C)):
            T, TC = C.index[j], C.ct.iat[j]
            vis = {}
            for tf in self.tfs:
                k = self.visible_index(tf, T, TC); H = self.htf[tf]
                pk, plb, pls = prev[tf]
                lb = H["LB"][k] if k >= 0 else None; ls = H["LS"][k] if k >= 0 else None
                nb = lb is not None and (plb is None or lb["t"] != plb["t"])
                ns = ls is not None and (pls is None or ls["t"] != pls["t"])
                nc = k >= 0 and k != pk
                vis[tf] = (k, nb, ns, nc, lb, ls); prev[tf] = (k, lb, ls)
            for tf in self.tfs:                                                   # 1) new zones
                k, nb, ns, nc, lb, ls = vis[tf]
                if nb: self._new_zone(tf, True, lb, TC)
                if ns: self._new_zone(tf, False, ls, TC)
            for z in list(self.zones):                                            # 2) state machine
                k, nb, ns, nc, lb, ls = vis[z.tf]
                cc = self.htf[z.tf]["df"].close.iat[k] if k >= 0 else np.nan
                d = -1.0 if z.is_buy else 1.0
                if z.state == 0:
                    if nc and (cc - z.lvl) * d > 0: self._break(z, self.htf[z.tf]["df"].index[k], k)
                elif z.state == 1:
                    if nc and (cc - z.lvl) * d < 0:
                        z.state = 2; z.ret_i = k
                        if z.opp_seen: self._arm(z, TC)
                elif z.state == 2:
                    if z.opp_seen: self._arm(z, TC)
                elif z.state == 3:
                    if j > 0 and (close[j] - z.lvl) * d > 0 and (close[j - 1] - z.lvl) * d <= 0:
                        z.state = 4
                        side = "SELL" if z.is_buy else "BUY"
                        self.signals.append(dict(time=TC, side=side, entry=float(close[j]), tf=z.tf, zone=z,
                                                 sl=float(z.opp.lvl) if z.opp is not None else np.nan, tp=float(self._tp(z))))
        return self.signals
