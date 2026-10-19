# Zakhm × Monkey Desk 🐒📈

**Live page:** https://faldbis.github.io/zakhm-monkey-desk/

## الاستراتيجية الجديدة: SCI-R على خطوط الزخم (الافتراضي في الصفحة)
- الصفحة تفتح الحين على **إعادة تشغيل أسبوع 12–16 أكتوبر 2026** لاستراتيجية **SCI-R**: كسر الهيكل (indication) على فريم الساعة على خطوط الزخم → تصحيح ثم shift على 15 و5 دقايق → **الدخول المفضل** بإغلاق شمعة بعد مستوى الكسر BS. الوقف عند القمة/القاع اللي فشل، والهدف عند NL، ويتخطى أي إشارة ستوبها أصغر من 1.0× ATR14، والتداول بس من 07:00 لين 21:00 UTC.
- الصفقات **حقيقية من الباكتست** (`trades_sci_R_long_pref_atr10.csv`، التكاليف محسوبة) على شموع حقيقية. تبدي بـ 1000 دينار، ومخاطرة 6.5٪ من الرصيد بكل صفقة. وكل صفقة معروضة بالـ R بعد.
- هذا **hindsight replay**: إعادة تشغيل لنتايج باكتست على بيانات معروفة مسبقاً، **مو** نتايج تداول حي.
- الأسابيع الموجودة (كل أسبوع يبدي من 1000 دينار):
  - 12–16 أكتوبر: 4 صفقات، −0.17R، وانتهى على 980.39 (−1.96٪)
  - 5–11 أكتوبر: 5 صفقات، −1.68R، وانتهى على 892.73 (−10.73٪)
  - 28 سبتمبر – 4 أكتوبر: 4 صفقات، +3.76R، وانتهى على 1246.01 (+24.6٪)
- الأيام القديمة لاستراتيجية ZAKHM OSMA للحين تقدر تختارها من القائمة اللي فوق.
- أسبوع جديد: `python3 run_sci_week.py --week YYYY-MM-DD --default` (لازم ملفات الباكتست تكون موجودة محلياً).

## عربي (ZAKHM OSMA — القديم)
لوحة تداول متحركة (نفس ستايل ريل "Monkey Desk") تعرض **صفقات حقيقية** لاستراتيجية **الزخم (OSMA 132/32/16)**
على شموع Binance الحقيقية — إعادة تشغيل ليوم كامل (hindsight replay).
- المؤشر الأصلي: `strategy/osma_zones.pine` (TradingView Pine v5).
- النسخة البايثون: `strategy/zakhm_zones.py` (مناطق الزخم، الكسر، الرجوع، الزخم المعاكس، الدخول بإغلاق ساعة).
- الباكتست: `strategy/zakhm_backtest.py` — وقف الخسارة عند آخر زخم معاكس، الهدف عند أقصى شمعة زخم الانفجار، رافعة 20x، 10٪ هامش، رسوم.
- النتيجة الحقيقية تنعرض مثل ما هي (حتى لو صفر صفقات أو خسارة).
- يوم جديد: `python3 run_day.py --date 2026-10-17 --day 9 --start 431.25` ثم ارفع ملفات `data/` و`audio/`.
- **ليست نصيحة مالية.** النتائج على بيانات معروفة مسبقاً ولا تضمن أي شي مستقبلاً.

## New strategy: SCI-R on Zakhm momentum lines (default view)
- Default view: a **hindsight replay of the week of 12–16 Oct 2026** for **SCI-R**. An H1 market-structure indication on the zakhm momentum lines is followed by an M15/M5 correction and shift. Entry is the **preferred entry**: the first close back beyond the broken level (BS). The SL goes beyond the failed high/low and the TP is NL. Signals with an SL smaller than 1.0× ATR14 are skipped, and trading is limited to 07:00–21:00 UTC.
- The trades are **real backtest trades** from `trades_sci_R_long_pref_atr10.csv`, net of spread and commission, shown on real candles. The replay starts at 1000 KWD and risks 6.5% of the current balance per trade (compounding), and every trade is also shown in R.
- Weeks in the menu (each starts at 1000 KWD):

  | Week | Trades | Net R | End balance |
  |---|---|---|---|
  | 12–16 Oct | 4 | −0.17R | 980.39 (−1.96%) |
  | 5–11 Oct | 5 | −1.68R | 892.73 (−10.73%) |
  | 28 Sep–4 Oct | 4 | +3.76R | 1246.01 (+24.6%) |

- Links: `?day=sci` (the default) or `?day=data/sci_week_2026-10-12.js`. The old ZAKHM OSMA days are still in the menu.
- To add a new week, run `python3 run_sci_week.py --week YYYY-MM-DD [--default]`. It reads the local backtest outputs, which are not in this repo.
- These are backtest results replayed with hindsight, **not live trading results**.

## English (ZAKHM OSMA — old)
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
