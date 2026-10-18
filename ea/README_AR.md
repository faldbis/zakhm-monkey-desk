# ZAKHM OSMA — خبير MT5 (ZakhmOSMA)

## التركيب على الـ VPS (خطوات قصيرة)
1. افتح MetaTrader 5 على الـ VPS وسجّل دخول حسابك (Exness).
2. من القائمة: **File > Open Data Folder** ثم افتح **MQL5 > Experts**.
3. الصق الملفين `ZakhmOSMA.ex5` و `ZakhmOSMA.mq5` هنا.
4. في نافذة **Navigator** اضغط يمين على **Expert Advisors** ثم **Refresh**.
5. اسحب **ZakhmOSMA** على أي شارت **H1** (شارت واحد يكفي، البوت يمر على كل الرموز).
6. في نافذة الإعدادات: تبويب **Common** فعّل **Allow Algo Trading**، ثم اضغط زر **Algo Trading** في الأعلى ليصير أخضر.
7. يبدأ في وضع **DryRun = true** (بدون أي صفقات، فقط سجلات وتنبيهات). راقب تبويب **Experts** والتعليق على الشارت.
8. عندما تكون جاهز للتداول الحقيقي: اضغط F7 على الشارت وغيّر **DryRun = false**.

## ملاحظات
- الرموز: إذا تركت `SymbolsList` فارغ، البوت يأخذ تلقائيًا من **Market Watch** فقط هذه الرموز (مع اكتشاف اللاحقة مثل `BTCUSDm`):
  BTCUSD, XAUUSD, GBPUSD, GBPJPY, EURUSD, GBPAUD, USDCAD, USDJPY, AUDUSD, EURAUD.
- المخاطرة: الخسارة عند الستوب = 1% من الرصيد (تقريب للأسفل لخطوة اللوت). إيقاف يومي عند خسارة 3% من إيكوتي بداية اليوم.
- صفقة واحدة لكل رمز. Magic = 20261018، التعليق "ZAKHM".
- للإشعارات على الجوال: Tools > Options > Notifications وأدخل MetaQuotes ID.
- يفضّل: Tools > Options > Charts > Max bars in chart = Unlimited (البوت يحتاج ~150 يوم من بيانات M3).
- لا يحتاج البوت كلمة المرور؛ يستخدم الحساب المسجّل في المنصة.

## البديل: بوت بايثون (مجلد python/)
للـ Windows VPS: ثبّت Python 3.11 ثم `pip install -r requirements.txt`، افتح MT5 مسجّل الدخول،
شغّل `run_bridge.bat` ثم `run_bot_dry.bat` (وضع تجريبي بدون أوامر).
