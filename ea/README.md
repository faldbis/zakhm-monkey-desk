# ZakhmOSMA EA (MQL5) - quick reference
Install: MT5 > File > Open Data Folder > MQL5/Experts, paste ZakhmOSMA.ex5 (+ .mq5), Navigator > Refresh,
drag on any H1 chart, enable Algo Trading. Starts with DryRun=true (no orders). Set DryRun=false to trade.

Logic (1:1 port of strategy/zakhm_zones.py, verified identical on 150 days of BTC 3m data: 199/199 zone events,
61/61 signals body mode; 193/193 and 60/60 wick mode):
OSMA = (EMA132-EMA32) - EMA16 (Pine-exact SMA-seeded EMA). Zone TFs 66m/396m from M3 (restart 00:00 of anchor day),
D from H1; 16m skipped (below H1 chart TF). States 0 active -> 1 broken -> 2 returned -> 3 armed -> 4 entry on H1 close
crossing the line. Broken buy zone => SELL, broken sell zone => BUY. SL = line of the opposite zone that armed it,
TP = body (or wick) extreme of strongest-OSMA bar between break and return. Risk 1% of balance at SL (floor to lot
step, skip < min lot), invalid SL/TP vs live price => skip, one position per symbol (magic), 3% daily equity stop.

Python alternative (python/): run_bridge.bat (MT5 open+logged in; orders disabled), then run_bot_dry.bat.
Live (only when you decide): set ZAKHM_ALLOW_ORDERS=1 before run_bridge.bat AND run `python bot.py --loop --live`.
MQL5/Scripts/ZakhmEngineTest.mq5 = offline engine cross-check (reads MQL5/Files/zk_base.csv).
