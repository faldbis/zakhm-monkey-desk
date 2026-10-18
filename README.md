# Zakhm × Monkey Desk 🐒📈

**Live page:** https://faldbis.github.io/zakhm-monkey-desk/

## عربي
لوحة تداول متحركة (نفس ستايل ريل "Monkey Desk") تعرض **صفقات حقيقية** لاستراتيجية **الزخم (OSMA 132/32/16)**
على شموع Binance الحقيقية — إعادة تشغيل ليوم كامل (hindsight replay).
- المؤشر الأصلي: `strategy/osma_zones.pine` (TradingView Pine v5).
- النسخة البايثون: `strategy/zakhm_zones.py` (مناطق الزخم، الكسر، الرجوع، الزخم المعاكس، الدخول بإغلاق ساعة).
- الباكتست: `strategy/zakhm_backtest.py` — وقف الخسارة عند آخر زخم معاكس، الهدف عند أقصى شمعة زخم الانفجار، رافعة 20x، 10٪ هامش، رسوم.
- النتيجة الحقيقية تنعرض مثل ما هي (حتى لو صفر صفقات أو خسارة).
- يوم جديد: `python3 run_day.py --date 2026-10-17 --day 9 --start 431.25` ثم ارفع ملفات `data/` و`audio/`.
- **ليست نصيحة مالية.** النتائج على بيانات معروفة مسبقاً ولا تضمن أي شي مستقبلاً.

## English
An animated trading-desk page (Monkey Desk reel style) replaying **real trades** of the user's **Zakhm OSMA momentum-zone strategy**
on real Binance candles (BTC, ETH, SOL, XRP, BNB / USDT).
- `index.html` — standalone canvas app (works on GitHub Pages or from disk). Tap to start: chiptune music, SFX and
  voiceover in the browser. Pick a day in the top menu; `?day=replica` shows the original reel replica (made-up trades).
- `data/day_*.js` — precomputed replays written by `run_day.py` (trades, real 3m candles, zone events). `data/*_summary.json`, `*_trades.csv` = raw results.
- `strategy/osma_zones.pine` — the original TradingView indicator. `strategy/zakhm_zones.py` — faithful Python port
  (verified: wick-mode waves identical to the earlier `zakhm_signal.py` scanner, 104/104 on ETHUSDT 1H).
- `strategy/zakhm_backtest.py` — execution model: entry at the close of the 1H candle crossing back through the broken line;
  SL = line of the last opposite zone (same TF) after the break; TP = extreme of the strongest-OSMA bar of the explosion;
  20x isolated, 10% margin, 0.05% fee + 0.02% slippage per side, liquidation modelled, EOD close.
- New day: `pip install -r requirements.txt && python3 run_day.py --date YYYY-MM-DD --day N --start BAL` (fetches public Binance klines, no keys).

Not financial advice. Hindsight replays on known data prove nothing about the future.
