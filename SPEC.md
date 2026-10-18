# MONKEY DESK reel — spec (from /workspace/reel_t0/reel.mp4)

## Source
- Account: Kairo Trading AI (@kairotradingai). 1080×1920, 30 fps, H.264, 40.0 s; AAC 48 kHz stereo.
- Caption: "Road to $100K 🚀 Day 8/30 / $431.25 → $597.29 | +38.50% / 23 wins. 2 losses. Would you take these trades? #Trading #Crypto #CryptoTrading #TradingChallenge #RoadTo100K"
- NOTE: on-screen date is **2026-10-16** (Friday 16 Oct 2026, i.e. two days before today), not 2020.
  It is a "hindsight replay": the bot is run over a day whose candles are already known.

## Audio timeline (measured RMS + transcription)
- 0.0–5.3 s  male energetic English VO over music: "One hundred dollars to start. One hundred thousand dollars is the goal. Day eight, let's trade."
  (word starts ≈ 0.0 / 1.1 "start" / 1.4 "100,000" / 3.3 "goal" / 4.1 "Day eight" / 4.6 "let's trade")
- 0–34 s     upbeat chiptune-style loop + arcade blips / coin SFX on trade closes (RMS ≈ −15…−20 dBFS)
- 34.0 s     replay ends (music drops ~−40 dB, tail fades), 36.5–40 s digital silence. Video holds the end card.

## Palette (sampled)
| use | hex |
|---|---|
| page bg | #08090f / #0b0b13 |
| panel fill / stroke | #0b0f14 / #222a33 ; office border #1b4655 |
| yellow (balance, PORTFOLIO, TRADE LOG) | #f1cb55 / #f2c94e ; badge border #d6b14a, badge fill #2a230c |
| green (%/pnl) | #4fe39a ; candle up #29b47c ; equity line #3ddc84 |
| red | #e0525c / #ef5b62 |
| cyan (REPLAY, HOUR, progress) | #00bbe3 / #22c3e6, badge fill #06232b |
| text / dim | #d6dbe1 / #7c858f / #565e68 |
| agents | SCOUT #5b8fe6, CHECK #2fc79e, SIZE #8f70e6, ENTRY #45c45f, EXIT #eb9a35, GUARD #e25a5a, CHIEF hologram #7ce9ff |
- Fonts: monospace UI (JetBrains Mono-like); big balance in a rounded-square bold (≈ Saira SemiCondensed ExtraBold).

## Layout (px, 1080×1920)
1. Header y 0–51: monkey-face logo (cyan) x20; "MONKEY DESK" x57 17px; [REPLAY] cyan badge x191–244;
   [PORTFOLIO · BTC ETH SOL XRP BNB] yellow badge x253–566 y11–41; day progress bar x707–857 y17 (cyan);
   [HOUR hh/24] cyan badge x869–962; "hh:mm UTC" right-aligned x1058 17px; second line "night · Friday 16 Oct · ▶ REPLAY" (→ "■ END") 10.5px.
2. Agent cards y 59–177: 6 cards 166×118, pitch 175 from x19. Face icon, NAME (agent colour, bold), sub-label
   (signals / liquidity / sizing / entries / exits / risk), typed status line, colour progress bar at y+97. Two cards highlighted at a time.
3. Balance y 200–600: "BALANCE · Friday 16 Oct" 26px y250; "$ 522.60" ≈150px yellow with green glow, centre y≈360;
   "+21.18 % today" 40px green y484; floating "+$6.63" pops (38px green) rising around y 540–600.
   End card (t≥34): yellow-bordered box x120–960 y505–591 "$431.25 → $597.29" 44px.
4. BOT OFFICE panel y 620–1250 (cyan border). Header: "BOT OFFICE · Friday 16 Oct · hindsight replay" (left) /
   "Binance USD-M SOL/USDT 15m · 2026-10-16 UTC · real candles" (right, symbol follows active trade), 11px.
   Isometric dark room: left wall with 3 blue windows, sofa, server rack with dish antenna + holo monkey logo,
   right wall with big holographic chart screen ("SOL/USD 15m · real", price, "HOUR 16/24 · 15:32 UTC"),
   6 desks with monitors + lamps, plants. 6 box-head robots (colours above, faces: dots, squares, lines,
   triangles, ^^ arcs, o o) wander between desks; cyan neon monkey "CHIEF" hologram with sparkles.
   Each has a bubble (NAME + typed status) linked by a thin line. "+16.52 $" green box pops near ENTRY on close;
   "SOL SHORT 20x / +1.9%" tag over ENTRY while a position is open.
   Status vocab: SCOUT "scanning the replay"; CHECK "reviewing the logs" / "reading 15m candles" / "“real candle, ok”";
   SIZE "margin 42.67 $" / "balance 481.78" / "“20x ·"; ENTRY "“your position now”" / "ready to enter" / "on SOL SHORT 20x +1.9%";
   EXIT "holding SOL long"; GUARD "liq. at 112.0344" / "watching risk" / "logging the trades"; CHIEF "watching the replay" / "doing my rounds".
   End: "scanning the replay", "day +38.5 %", "end 597.29 $", "replay finished", "25 trades done", "hindsight only!", "day done!".
5. CHART panel x0–528 y1262–1632: "CHART · SOL (Solana) 15m", live price top-right, ~22 15m candles, 5 price labels at x455,
   entry triangles + "SHORT 20x 106.4000" / "LONG 20x 105.4500", white exit dots + "exit 106.0200 +9$".
6. OPEN POSITIONS x540–1080 y1260–1462: equity "523.56 $" 26px; "+92.32 $  +21.41 % today"; "1 open · margin 47.39 $";
   "cash 433.53 $"; position row "SOL SHORT 20x 107.2100 > 107.0206  +0.93 $ (+1.9%)"; or "no open positions · all cash";
   footer "15/25 trades closed · fees+slip 21.96 $" (fees ≈ 1.54 $/trade, 38.60 total).
7. PORTFOLIO BALANCE (USD) x540–1080 y1475–1690: green equity curve w/ dots + fill, dashed start line, y labels 430.99/486.47/541.95/597.43, x 06h/12h/18h.
8. TRADE LOG y1700–1892 yellow border: "TRADE LOG · Friday 16 Oct" 22px yellow, "day +21.4 %" green right; last 5 rows:
   "# 8 SOL (Solana) SHORT 20x 106.8300->105.7500   +17.0% +7.69$"; losses red-tinted; open row green outline "… open"; "# 3 · pending".
9. Footer bar y1892–1920 "Not financial advice".

## Timeline
| t (s) | replay clock | balance (orig) | notes |
|---|---|---|---|
| 0.0 | 01:39 (HOUR 02) | 434.16 | VO starts, trade #2 ETH LONG open |
| 12.5 | 11:25 (HOUR 12) | 481.96 | SOL trades, 10/25 closed |
| 20.0 | 15:32 (HOUR 16) | 522.60 | 15/25 closed |
| 27.5 | 19:18 (HOUR 20) | 577.10 | XRP trades |
| 34–35 | 00:00 (HOUR 24/24) | 597.29 | ■ END, end card, statuses switch to final |
| 35–40 | hold | 597.29 | silent hold |
Trades ≈ every 55 replay-minutes; each close = coin SFX + "+$" pop + counter roll (~0.6 s) + office pop.

## Observed trades (Day 8)
#1 ETH SHORT 20x 2,444->2,431 +7.7% +3.26 · #4 SOL LONG 104.79->106.18 +23.3% +10.12 · #5 SOL SHORT 106.18->105.61 +7.5% +3.35 ·
#6 SOL LONG 105.61->106.39 +11.6% +5.18 · #7 BNB LONG 731.48 -3.2% -1.44 · #8 SOL SHORT 106.83->105.75 +17.0% +7.69 ·
#9 SOL LONG 105.75->106.72 +15.1% +6.94 · #10 ETH LONG 2,464->2,489 +16.9% +7.85 · #11 SOL SHORT 107.21->106.02 +19.0% +9.01 ·
#12 ETH LONG 2,463->2,474 +5.1% +2.44 · #16 SOL SHORT 104.59->103.72 +13.4% +6.92 · #17 SOL LONG 103.72->104.36 +9.2% +4.78 ·
#18 ETH SHORT 2,443->2,400 +32.2% +16.93 · #19 SOL LONG 103.10->104.29 +19.9% +10.78 · #20 XRP SHORT 1.3086->1.2991 +11.3% +6.27 ·
#21 BNB SHORT 10x 721.90->723.33 -3.6% -2.02 · #22 SOL SHORT 103.88->103.02 +13.4% +7.46.
(#2, #3, #13–15, #23–25 not visible; filled in the recreation so the total is exactly +166.04 $.)
