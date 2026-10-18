// Offline cross-check: reads MQL5/Files/zk_base.csv (unix_time,o,h,l,c of 3m bars, UTC) and writes
// zk_mql_events.csv / zk_mql_signals.csv using the EA's engine. D is resampled from the 3m base (= Python daily=None).
#define ZAKHM_ENGINE_ONLY
#include "..\Experts\ZakhmOSMA.mq5"
input string InFile="zk_base.csv";
void Run1(bool Wick)
  {
   CBars base,dummy; CZakhmEngine E; E.keepEvents=true;
   int fh=FileOpen(InFile,FILE_READ|FILE_CSV|FILE_ANSI,',');
   if(fh==INVALID_HANDLE) { Print("open fail ",GetLastError()); return; }
   while(!FileIsEnding(fh))
     {
      double t=FileReadNumber(fh),o=FileReadNumber(fh),h=FileReadNumber(fh),l=FileReadNumber(fh),c=FileReadNumber(fh);
      if(t<=0) break;
      base.Add((long)t,o,h,l,c,0);
     }
   FileClose(fh);
   int tfs[]={16,66,396,1440}; string err;
   ulong t0=GetMicrosecondCount();
   ZBuildAndRun(E,base,dummy,false,tfs,132,32,16,Wick,20,err);
   PrintFormat("base %d chart %d zones %d events %d signals %d in %.2fs %s",base.n,E.chart.n,E.nz,E.nev,E.nsig,(GetMicrosecondCount()-t0)/1e6,err);
   int g=FileOpen(Wick?"zk_mql_events_wick.csv":"zk_mql_events.csv",FILE_WRITE|FILE_ANSI|FILE_TXT);
   for(int i=0;i<E.nev;i++)
      FileWriteString(g,StringFormat("%I64d,%d,%d,%d,%.10g,%I64d\n",E.ev[i].time,E.ev[i].kind,E.ev[i].tfMin,E.ev[i].is_buy?1:0,E.ev[i].lvl,E.ev[i].t0));
   FileClose(g);
   g=FileOpen(Wick?"zk_mql_signals_wick.csv":"zk_mql_signals.csv",FILE_WRITE|FILE_ANSI|FILE_TXT);
   for(int i=0;i<E.nsig;i++)
      FileWriteString(g,StringFormat("%I64d,%d,%.10g,%.10g,%.10g,%d,%d\n",E.sig[i].time,E.sig[i].side,E.sig[i].entry,E.sig[i].ok_sl?E.sig[i].sl:-1,E.sig[i].ok_tp?E.sig[i].tp:-1,E.sig[i].tfMin,E.sig[i].zbuy?1:0));
   FileClose(g);
  }
void OnStart() { Run1(false); Run1(true); Print("ZK_TEST_DONE"); }
