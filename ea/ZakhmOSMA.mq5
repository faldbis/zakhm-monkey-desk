//+------------------------------------------------------------------+
//| ZakhmOSMA.mq5 - ZAKHM OSMA Momentum Zones Expert Advisor          |
//| 1:1 port of strategy/zakhm_zones.py (port of the Pine indicator  |
//| "OSMA Momentum Zones") + the Zakhm exit rules.                    |
//| Chart TF = H1 (internal, the EA chart itself can be anything).   |
//| Zone TFs: 66m / 396m built from M3, restarting every day 00:00   |
//| (anchor = UTC by default), D built from H1 on the same anchor.   |
//| DryRun = true by default -> NO orders, only logs/alerts/push.    |
//+------------------------------------------------------------------+
#property copyright "ZAKHM"
#property version   "1.00"
#property strict

#define ZE EMPTY_VALUE           // "na" marker (Python NaN)

//==================================================================
//  ENGINE (no inputs, no trading - shared with the test script)
//==================================================================
class CBars
  {
public:
   long              t[];      // bar open time (anchor timeline, seconds)
   double            o[],h[],l[],c[];
   long              ct[];     // bar close time
   int               n;
                     CBars(void) { n=0; }
   void              Clear(void) { n=0; }
   void              Add(long tt,double oo,double hh,double ll,double cc,long cct)
     {
      if(n>=ArraySize(t))
        {
         int ns=n+8192;
         ArrayResize(t,ns); ArrayResize(o,ns); ArrayResize(h,ns); ArrayResize(l,ns); ArrayResize(c,ns); ArrayResize(ct,ns);
        }
      t[n]=tt; o[n]=oo; h[n]=hh; l[n]=ll; c[n]=cc; ct[n]=cct; n++;
     }
  };

struct SWave
  {
   double            pk;       // peak OSMA of the wave
   long              t;        // time of the peak bar
   int               i;        // index of the peak bar
   double            lvl;      // zone line (body or wick)
   long              brk_t;    // in-wave break time
   int               brk_i;    // in-wave break index (-1 = none)
  };

class CTF
  {
public:
   int               tfMin;
   CBars             b;
   double            osma[];
   int               LB[],LS[]; // per bar: index into w[] of last completed buy/sell wave (-1 none)
   SWave             w[];
   int               nw;
  };

struct SZone
  {
   int               tf;       // index into engine tf[]
   bool              is_buy;
   double            lvl;
   double            osma;
   long              t0;
   int               pk_i;
   int               state;    // 0 active,1 broken,2 returned,3 armed,4 entered
   long              broke_t;
   int               broke_i;
   bool              opp_seen;
   bool              has_opp;
   double            opp_lvl;
   int               ret_i;
   int               zid;
  };

struct SSig
  {
   long              time;     // H1 close time (anchor)
   int               side;     // +1 BUY, -1 SELL
   double            entry,sl,tp;
   bool              ok_sl,ok_tp;
   int               tfMin;
   bool              zbuy;
   double            zlvl;
   long              zt0;
   int               zid;
  };

struct SEvent
  {
   long              time;
   int               kind;     // 0 zone, 1 armed
   int               tfMin;
   bool              is_buy;
   double            lvl;
   long              t0;
  };

bool ZGt(double v) { return v!=ZE && v>0; }
bool ZLt(double v) { return v!=ZE && v<0; }

// ta.ema: na until len valid values, seeded with their SMA, then alpha recursion (same as pine_ema)
void PineEma(const double &x[],int n,int len,double &out[])
  {
   ArrayResize(out,n); ArrayInitialize(out,ZE);
   int first=-1,valid=0;
   for(int i=0;i<n;i++) if(x[i]!=ZE) { if(first<0) first=i; valid++; }
   if(first<0 || valid<len) return;
   int s=first+len-1; if(s>=n) return;
   double sum=0; int cnt=0;
   for(int i=first;i<=s;i++) if(x[i]!=ZE) { sum+=x[i]; cnt++; }
   out[s]=sum/cnt;
   double a=2.0/(len+1);
   for(int i=s+1;i<n;i++) out[i]=(x[i]!=ZE) ? a*x[i]+(1-a)*out[i-1] : out[i-1];
  }

// TradingView-style bars of tfMin minutes, anchored at 00:00 of each (anchor) day; ct = close time;
// non-divisor TFs get a shorter last bar of the day; only complete bars (ct <= last src open + srcSec).
void ZResample(CBars &src,int srcSec,int tfMin,CBars &dst)
  {
   dst.Clear();
   if(src.n==0) return;
   long m=(long)tfMin*60,lastKey=-1;
   double bo=0,bh=0,bl=0,bc=0; long bct=0;
   for(int i=0;i<src.n;i++)
     {
      long tt=src.t[i];
      long day=tt-(tt%86400);
      long key=(tfMin==1440) ? day : day+((tt-day)/m)*m;
      if(key!=lastKey)
        {
         if(lastKey>=0) dst.Add(lastKey,bo,bh,bl,bc,bct);
         lastKey=key; bo=src.o[i]; bh=src.h[i]; bl=src.l[i]; bc=src.c[i];
         bct=MathMin(key+m,day+86400);
        }
      else
        {
         if(src.h[i]>bh) bh=src.h[i];
         if(src.l[i]<bl) bl=src.l[i];
         bc=src.c[i];
        }
     }
   dst.Add(lastKey,bo,bh,bl,bc,bct);
   long lim=src.t[src.n-1]+srcSec;
   while(dst.n>0 && dst.ct[dst.n-1]>lim) dst.n--;     // complete bars only
  }

// bar-by-bar copy of f_osma() (wave_engine in Python)
void ZWaveEngine(CTF &T,int fast,int slow,int sig,bool wick)
  {
   int n=T.b.n;
   double c[],e1[],e2[],m[],e3[];
   ArrayResize(c,n); for(int i=0;i<n;i++) c[i]=T.b.c[i];
   PineEma(c,n,fast,e1); PineEma(c,n,slow,e2);
   ArrayResize(m,n);
   for(int i=0;i<n;i++) m[i]=(e1[i]!=ZE && e2[i]!=ZE) ? e1[i]-e2[i] : ZE;
   PineEma(m,n,sig,e3);
   ArrayResize(T.osma,n);
   for(int i=0;i<n;i++) T.osma[i]=(m[i]!=ZE && e3[i]!=ZE) ? m[i]-e3[i] : ZE;
   ArrayResize(T.LB,n); ArrayResize(T.LS,n); T.nw=0; ArrayResize(T.w,0,4096);
   SWave bw,sw; bw.pk=ZE; bw.brk_i=-1; bw.brk_t=0; bw.t=0; bw.i=-1; bw.lvl=0;
   sw=bw;
   int lb=-1,ls=-1;
   for(int i=0;i<n;i++)
     {
      double o=T.osma[i];
      bool prevPos=(i>0 && ZGt(T.osma[i-1])), prevNeg=(i>0 && ZLt(T.osma[i-1]));
      double cl=T.b.c[i];
      if(ZGt(o))
        {
         if(!prevPos || o>bw.pk)
           {
            bw.pk=o; bw.t=T.b.t[i]; bw.i=i; bw.lvl=wick ? T.b.l[i] : MathMin(T.b.o[i],cl); bw.brk_i=-1; bw.brk_t=0;
           }
         else if(bw.brk_i<0 && cl<bw.lvl) { bw.brk_t=T.b.t[i]; bw.brk_i=i; }
        }
      if(!ZGt(o) && prevPos && bw.pk!=ZE)
        {
         if(bw.brk_i<0 && cl<bw.lvl) { bw.brk_t=T.b.t[i]; bw.brk_i=i; }
         ArrayResize(T.w,T.nw+1,4096); T.w[T.nw]=bw; lb=T.nw; T.nw++;
        }
      if(ZLt(o))
        {
         if(!prevNeg || o<sw.pk)
           {
            sw.pk=o; sw.t=T.b.t[i]; sw.i=i; sw.lvl=wick ? T.b.h[i] : MathMax(T.b.o[i],cl); sw.brk_i=-1; sw.brk_t=0;
           }
         else if(sw.brk_i<0 && cl>sw.lvl) { sw.brk_t=T.b.t[i]; sw.brk_i=i; }
        }
      if(!ZLt(o) && prevNeg && sw.pk!=ZE)
        {
         if(sw.brk_i<0 && cl>sw.lvl) { sw.brk_t=T.b.t[i]; sw.brk_i=i; }
         ArrayResize(T.w,T.nw+1,4096); T.w[T.nw]=sw; ls=T.nw; T.nw++;
        }
      T.LB[i]=lb; T.LS[i]=ls;
     }
  }

class CZakhmEngine
  {
public:
   CBars             chart;
   CTF               tf[4];
   int               ntf;
   SZone             z[];
   int               nz,zidc,maxZ;
   bool              wick;
   SSig              sig[];
   int               nsig;
   SEvent            ev[];
   int               nev;
   bool              keepEvents;
                     CZakhmEngine(void) { ntf=0; nz=0; zidc=0; nsig=0; nev=0; maxZ=20; wick=false; keepEvents=false; }

   void              AddEvent(long t,int kind,const SZone &q)
     {
      if(!keepEvents) return;
      ArrayResize(ev,nev+1,4096);
      ev[nev].time=t; ev[nev].kind=kind; ev[nev].tfMin=tf[q.tf].tfMin; ev[nev].is_buy=q.is_buy; ev[nev].lvl=q.lvl; ev[nev].t0=q.t0; nev++;
     }

   void              NewZone(int f,bool isBuy,int wi,long now)
     {
      zidc++;
      SZone q;
      q.tf=f; q.is_buy=isBuy; q.lvl=tf[f].w[wi].lvl; q.osma=tf[f].w[wi].pk; q.t0=tf[f].w[wi].t; q.pk_i=tf[f].w[wi].i;
      q.state=0; q.broke_t=0; q.broke_i=-1; q.opp_seen=false; q.has_opp=false; q.opp_lvl=0; q.ret_i=-1; q.zid=zidc;
      if(tf[f].w[wi].brk_i>=0) { q.state=1; q.broke_t=tf[f].w[wi].brk_t; q.broke_i=tf[f].w[wi].brk_i; }
      for(int k=0;k<nz;k++)                                     // step-3 helper
         if(z[k].tf==f && z[k].is_buy!=isBuy && (z[k].state==1 || z[k].state==2))
           { z[k].opp_seen=true; z[k].has_opp=true; z[k].opp_lvl=q.lvl; }
      ArrayResize(z,nz+1,256); z[nz]=q; nz++;
      AddEvent(now,0,q);
      int same=0,first=-1;
      for(int k=0;k<nz;k++) if(z[k].tf==f && z[k].is_buy==isBuy) { if(first<0) first=k; same++; }
      if(same>maxZ)
        {
         for(int k=first;k<nz-1;k++) z[k]=z[k+1];
         nz--;
        }
     }

   bool              TP(const SZone &q,double &tp)
     {
      int a=q.broke_i,b=q.ret_i;
      if(a<0 || b<a) return false;
      int best=-1; double bv=0;
      for(int k=a;k<=b;k++)
        {
         double v=tf[q.tf].osma[k]; if(v==ZE) continue;
         if(best<0 || (q.is_buy ? v<bv : v>bv)) { best=k; bv=v; }
        }
      if(best<0) return false;
      CBars *d=GetPointer(tf[q.tf].b);
      if(q.is_buy) tp=wick ? d.l[best] : MathMin(d.o[best],d.c[best]);   // explosion was downward -> target below
      else         tp=wick ? d.h[best] : MathMax(d.o[best],d.c[best]);
      return true;
     }

   void              Run(void)
     {
      nz=0; zidc=0; nsig=0; nev=0;
      int kp[4],plb[4],pls[4],K[4],LBv[4],LSv[4]; bool NB[4],NS[4],NC[4];
      for(int f=0;f<4;f++) { kp[f]=-1; plb[f]=-1; pls[f]=-1; }
      int ptr[4]; for(int f=0;f<4;f++) ptr[f]=-1;
      for(int j=0;j<chart.n;j++)
        {
         long T=chart.t[j],TC=chart.ct[j];
         for(int f=0;f<ntf;f++)
           {
            while(ptr[f]+1<tf[f].b.n && tf[f].b.ct[ptr[f]+1]<=T) ptr[f]++;   // newest HTF bar closed by chart-bar open
            int k=ptr[f];
            int lbv=(k>=0) ? tf[f].LB[k] : -1, lsv=(k>=0) ? tf[f].LS[k] : -1;
            NB[f]=(lbv>=0 && (plb[f]<0 || tf[f].w[lbv].t!=tf[f].w[plb[f]].t));
            NS[f]=(lsv>=0 && (pls[f]<0 || tf[f].w[lsv].t!=tf[f].w[pls[f]].t));
            NC[f]=(k>=0 && k!=kp[f]);
            K[f]=k; LBv[f]=lbv; LSv[f]=lsv; kp[f]=k; plb[f]=lbv; pls[f]=lsv;
           }
         for(int f=0;f<ntf;f++)                                  // 1) new zones
           {
            if(NB[f]) NewZone(f,true,LBv[f],TC);
            if(NS[f]) NewZone(f,false,LSv[f],TC);
           }
         int cnt=nz;
         for(int q=0;q<cnt;q++)                                  // 2) state machine
           {
            int f=z[q].tf,k=K[f];
            double cc=(k>=0) ? tf[f].b.c[k] : ZE;
            double d=z[q].is_buy ? -1.0 : 1.0;
            if(z[q].state==0)
              {
               if(NC[f] && (cc-z[q].lvl)*d>0) { z[q].state=1; z[q].broke_t=tf[f].b.t[k]; z[q].broke_i=k; }
              }
            else if(z[q].state==1)
              {
               if(NC[f] && (cc-z[q].lvl)*d<0)
                 {
                  z[q].state=2; z[q].ret_i=k;
                  if(z[q].opp_seen) { z[q].state=3; AddEvent(TC,1,z[q]); }
                 }
              }
            else if(z[q].state==2)
              {
               if(z[q].opp_seen) { z[q].state=3; AddEvent(TC,1,z[q]); }
              }
            else if(z[q].state==3)
              {
               if(j>0 && (chart.c[j]-z[q].lvl)*d>0 && (chart.c[j-1]-z[q].lvl)*d<=0)
                 {
                  z[q].state=4;
                  ArrayResize(sig,nsig+1,256);
                  sig[nsig].time=TC; sig[nsig].side=z[q].is_buy ? -1 : 1; sig[nsig].entry=chart.c[j];
                  sig[nsig].ok_sl=z[q].has_opp; sig[nsig].sl=z[q].has_opp ? z[q].opp_lvl : 0;
                  double tp=0; sig[nsig].ok_tp=TP(z[q],tp); sig[nsig].tp=tp;
                  sig[nsig].tfMin=tf[f].tfMin; sig[nsig].zbuy=z[q].is_buy; sig[nsig].zlvl=z[q].lvl; sig[nsig].zt0=z[q].t0; sig[nsig].zid=z[q].zid;
                  nsig++;
                 }
              }
           }
        }
     }
  };

string ZTfName(int m) { if(m==1440) return "D"; if(m<60 || m%60!=0) return IntegerToString(m)+"m"; return IntegerToString(m/60)+"H"; }

// Builds chart (H1) + zone TFs and runs. tfs: list of minutes (TFs below 60 are skipped, like f_ok).
// dsrc: source for D (H1 bars, srcSec 3600) when useDsrc, else D is resampled from base.
bool ZBuildAndRun(CZakhmEngine &E,CBars &base,CBars &dsrc,bool useDsrc,const int &tfs[],int fast,int slow,int sig,bool wick,int maxZ,string &err)
  {
   E.wick=wick; E.maxZ=maxZ; E.ntf=0;
   ZResample(base,180,60,E.chart);
   for(int i=0;i<ArraySize(tfs);i++)
     {
      int m=tfs[i];
      if(m<60) continue;
      if(E.ntf>=4) { err="too many TFs"; return false; }
      E.tf[E.ntf].tfMin=m;
      if(m==1440 && useDsrc) ZResample(dsrc,3600,1440,E.tf[E.ntf].b);
      else
        {
         if(m%3!=0) { err="TF "+IntegerToString(m)+" not buildable from M3"; return false; }
         ZResample(base,180,m,E.tf[E.ntf].b);
        }
      ZWaveEngine(E.tf[E.ntf],fast,slow,sig,wick);
      E.ntf++;
     }
   E.Run();
   return true;
  }

#ifndef ZAKHM_ENGINE_ONLY
//==================================================================
//  EXPERT ADVISOR
//==================================================================
#include <Trade\Trade.mqh>

enum ENUM_ZLINE   { ZLINE_BODY=0, ZLINE_WICK=1 };
enum ENUM_ZANCHOR { ZANCHOR_UTC=0, ZANCHOR_SERVER=1 };

input group "Mode"
input bool         DryRun              = true;      // DryRun: true = NO orders (log/alert/push only)
input group "Symbols"
input string       SymbolsList         = "";        // Symbols (comma list, exact names). Empty = auto from Market Watch
input string       ZakhmBases          = "BTCUSD,XAUUSD,GBPUSD,GBPJPY,EURUSD,GBPAUD,USDCAD,USDJPY,AUDUSD,EURAUD"; // Zakhm list (auto mode, suffix auto-detect)
input group "Strategy"
input ENUM_ZLINE   LineMode            = ZLINE_BODY; // Zone line: body (default) or wick (=Pine)
input string       ZoneTFs             = "16,66,396,D"; // Zone TFs (minutes / D). TFs < H1 are skipped
input int          OsmaFast            = 132;
input int          OsmaSlow            = 32;
input int          OsmaSignal          = 16;
input int          MaxZonesPerSide     = 20;
input ENUM_ZANCHOR TimeAnchor          = ZANCHOR_UTC; // Day/TF anchoring: UTC (=Python/TradingView) or broker server time
input int          ServerUTCOffsetHours= -100;      // Server - UTC in hours (-100 = auto detect)
input int          WarmDays            = 150;       // M3 history days (66m/396m)
input int          DailyWarmDays       = 400;       // H1 history days (D zones)
input int          CatchupHours        = 2;         // also act on signals up to N hours old (missed cycles)
input group "Risk"
input double       RiskPercent         = 1.0;       // loss at SL = % of balance (rounded DOWN to lot step)
input double       DailyLossStopPercent= 3.0;       // no new entries when equity <= start-of-day equity - X%
input long         MagicNumber         = 20261018;
input string       TradeComment        = "ZAKHM";
input int          DeviationPoints     = 50;
input group "Notifications"
input bool         ShowAlerts          = true;
input bool         SendPush            = true;      // needs MetaQuotes ID in Tools > Options > Notifications
input int          TimerSeconds        = 10;

struct SSymState
  {
   string            name;
   long              lastProc;     // last processed H1 close (anchor time)
   bool              ready;
   string            status;
   // dry-run virtual position
   bool              vOpen;
   int               vSide;
   double            vPrice,vSl,vTp,vVol;
   long              vTime;
  };

SSymState    S[];
int          NSym=0;
int          TFS[];
CZakhmEngine Eng;
CBars        Base,H1src;
CTrade       Trade;
long         OffsetSec=0;
double       VClosedToday=0;
long         VDay=-1;
bool         HaltNotified=false;
string       LastSignalTxt="-";

long Shift(void) { return TimeAnchor==ZANCHOR_UTC ? OffsetSec : 0; }
long ToAnchor(datetime srv) { return (long)srv-Shift(); }
string AT(long t) { return TimeToString((datetime)t,TIME_DATE|TIME_MINUTES); }
string GVName(string k) { return "ZAKHM_"+IntegerToString(MagicNumber)+"_"+k; }

void Notify(string msg)
  {
   Print(msg);
   if(ShowAlerts) Alert(msg);
   if(SendPush && TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED)) SendNotification(StringSubstr(msg,0,255));
  }

void UpdateOffset(void)
  {
   if(ServerUTCOffsetHours!=-100) { OffsetSec=(long)ServerUTCOffsetHours*3600; return; }
   long d=(long)TimeTradeServer()-(long)TimeGMT();
   OffsetSec=(long)MathRound(d/3600.0)*3600;
  }

bool ParseTFs(void)
  {
   string p[]; int n=StringSplit(ZoneTFs,',',p); ArrayResize(TFS,0);
   for(int i=0;i<n;i++)
     {
      string s=p[i]; StringTrimLeft(s); StringTrimRight(s); StringToUpper(s);
      if(s=="") continue;
      int m=(s=="D" || s=="1D" || s=="1440") ? 1440 : (int)StringToInteger(s);
      if(m<=0) { Print("bad TF ",s); return false; }
      int k=ArraySize(TFS); ArrayResize(TFS,k+1); TFS[k]=m;
     }
   return ArraySize(TFS)>0;
  }

void AddSym(string nm)
  {
   for(int i=0;i<NSym;i++) if(S[i].name==nm) return;
   ArrayResize(S,NSym+1); S[NSym].name=nm; S[NSym].lastProc=0; S[NSym].ready=false; S[NSym].status="waiting"; S[NSym].vOpen=false; NSym++;
  }

void BuildSymbols(void)
  {
   NSym=0; ArrayResize(S,0);
   string p[];
   if(StringLen(SymbolsList)>0)
     {
      int n=StringSplit(SymbolsList,',',p);
      for(int i=0;i<n;i++)
        {
         string s=p[i]; StringTrimLeft(s); StringTrimRight(s); if(s=="") continue;
         bool custom=false;
         if(!SymbolExist(s,custom)) { Print("ZAKHM: symbol ",s," not available on this account - skipped"); continue; }
         SymbolSelect(s,true); AddSym(s);
        }
      return;
     }
   int n=StringSplit(ZakhmBases,',',p), tot=SymbolsTotal(true);
   for(int i=0;i<n;i++)
     {
      string b=p[i]; StringTrimLeft(b); StringTrimRight(b); if(b=="") continue;
      string best="";
      for(int k=0;k<tot;k++)
        {
         string nm=SymbolName(k,true);
         if(nm==b) { best=nm; break; }
         if(best=="" && StringFind(nm,b)==0 && StringLen(nm)-StringLen(b)<=4) best=nm;   // suffix e.g. BTCUSDm / EURUSD.r
        }
      if(best!="") AddSym(best); else Print("ZAKHM: ",b," not in Market Watch - skipped");
     }
  }

//--- day / daily-stop bookkeeping
double DayStartEquity(void)
  {
   long day=ToAnchor(TimeTradeServer())/86400;
   if(!GlobalVariableCheck(GVName("DSE_DAY")) || (long)GlobalVariableGet(GVName("DSE_DAY"))!=day)
     {
      GlobalVariableSet(GVName("DSE_DAY"),(double)day);
      GlobalVariableSet(GVName("DSE"),AccountInfoDouble(ACCOUNT_EQUITY));
      HaltNotified=false;
     }
   if(VDay!=day) { VDay=day; VClosedToday=0; }
   return GlobalVariableGet(GVName("DSE"));
  }

double VFloating(void)
  {
   double s=0;
   for(int i=0;i<NSym;i++) if(S[i].vOpen)
     {
      double px=S[i].vSide>0 ? SymbolInfoDouble(S[i].name,SYMBOL_BID) : SymbolInfoDouble(S[i].name,SYMBOL_ASK), p=0;
      if(OrderCalcProfit(S[i].vSide>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,S[i].name,S[i].vVol,S[i].vPrice,px,p)) s+=p;
     }
   return s;
  }

bool Halted(double &eff,double &stop)
  {
   double dse=DayStartEquity();
   eff=AccountInfoDouble(ACCOUNT_EQUITY)+(DryRun ? VClosedToday+VFloating() : 0);
   stop=dse*(1.0-DailyLossStopPercent/100.0);
   return eff<=stop;
  }

bool HasPosition(string sym)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==sym && PositionGetInteger(POSITION_MAGIC)==MagicNumber) return true;
     }
   return false;
  }

double FloorStep(double v,double step) { return MathFloor(v/step+1e-9)*step; }

//--- dry-run virtual positions
void UpdateVirtual(void)
  {
   for(int i=0;i<NSym;i++)
     {
      if(!S[i].vOpen) continue;
      string sym=S[i].name;
      double bid=SymbolInfoDouble(sym,SYMBOL_BID),ask=SymbolInfoDouble(sym,SYMBOL_ASK);
      if(bid<=0 || ask<=0) continue;
      string why=""; double px=0;
      if(S[i].vSide>0) { if(bid<=S[i].vSl) { why="SL"; px=S[i].vSl; } else if(bid>=S[i].vTp) { why="TP"; px=S[i].vTp; } }
      else             { if(ask>=S[i].vSl) { why="SL"; px=S[i].vSl; } else if(ask<=S[i].vTp) { why="TP"; px=S[i].vTp; } }
      if(why=="") continue;
      double p=0; if(!OrderCalcProfit(S[i].vSide>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,sym,S[i].vVol,S[i].vPrice,px,p)) p=0;
      VClosedToday+=p; S[i].vOpen=false;
      Notify(StringFormat("ZAKHM [DRY] %s virtual %s closed by %s @ %s  P/L %+.2f %s",sym,S[i].vSide>0?"BUY":"SELL",why,
                          DoubleToString(px,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)),p,AccountInfoString(ACCOUNT_CURRENCY)));
     }
  }

//--- one signal -> checks -> (dry-run) order
void HandleSignal(int si,const SSig &g)
  {
   string sym=S[si].name; int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   string side=g.side>0 ? "BUY" : "SELL";
   string head=StringFormat("ZAKHM %s %s %s @%s (H1 close %s) zone %s %s %s",DryRun?"[DRY]":"[LIVE]",sym,side,DoubleToString(g.entry,dg),AT(g.time),
                            ZTfName(g.tfMin),g.zbuy?"buy":"sell",DoubleToString(g.zlvl,dg));
   LastSignalTxt=sym+" "+side+" "+AT(g.time);
   double eff,stop;
   if(Halted(eff,stop)) { Notify(head+" -> skipped: daily loss stop ("+DoubleToString(eff,2)+" <= "+DoubleToString(stop,2)+")"); return; }
   if(HasPosition(sym) || S[si].vOpen) { Notify(head+" -> skipped: position already open on "+sym); return; }
   if(!g.ok_sl || !g.ok_tp) { Notify(head+" -> skipped: SL/TP missing"); return; }
   long tm=SymbolInfoInteger(sym,SYMBOL_TRADE_MODE);
   if(tm==SYMBOL_TRADE_MODE_DISABLED || tm==SYMBOL_TRADE_MODE_CLOSEONLY || (g.side>0 && tm==SYMBOL_TRADE_MODE_SHORTONLY) || (g.side<0 && tm==SYMBOL_TRADE_MODE_LONGONLY))
     { Notify(head+" -> skipped: trade mode "+IntegerToString(tm)); return; }
   double price=g.side>0 ? SymbolInfoDouble(sym,SYMBOL_ASK) : SymbolInfoDouble(sym,SYMBOL_BID);
   double sl=NormalizeDouble(g.sl,dg),tp=NormalizeDouble(g.tp,dg);
   if(g.side>0 && !(sl<price && price<tp)) { Notify(head+StringFormat(" -> skipped: invalid SL/TP for BUY (sl %s px %s tp %s)",DoubleToString(sl,dg),DoubleToString(price,dg),DoubleToString(tp,dg))); return; }
   if(g.side<0 && !(tp<price && price<sl)) { Notify(head+StringFormat(" -> skipped: invalid SL/TP for SELL (sl %s px %s tp %s)",DoubleToString(sl,dg),DoubleToString(price,dg),DoubleToString(tp,dg))); return; }
   double pt=SymbolInfoDouble(sym,SYMBOL_POINT),stops=(double)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL)*pt;
   if(MathAbs(price-sl)<stops || MathAbs(tp-price)<stops) { Notify(head+" -> skipped: SL/TP inside stops level"); return; }
   ENUM_ORDER_TYPE ot=g.side>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double pr=0;
   if(!OrderCalcProfit(ot,sym,1.0,price,sl,pr) || pr>=0) { Notify(head+" -> skipped: cannot compute loss per lot"); return; }
   double loss1=-pr, risk=AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100.0;
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),vmin=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),vmax=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double vol=MathMin(FloorStep(risk/loss1,step),vmax);
   int vd=(int)MathMax(0,MathCeil(-MathLog10(step)-1e-9)); vol=NormalizeDouble(vol,vd);
   if(vol<vmin) { Notify(head+StringFormat(" -> skipped: volume %.4f < min lot %s (risk %.2f, loss/lot %.2f)",risk/loss1,DoubleToString(vmin,vd),risk,loss1)); return; }
   double mg=0;
   if(OrderCalcMargin(ot,sym,vol,price,mg) && mg>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { Notify(head+StringFormat(" -> skipped: margin %.2f > free margin",mg)); return; }
   string plan=StringFormat(" vol %s SL %s TP %s risk %.2f (loss/lot %.2f) magic %I64d \"%s\"",DoubleToString(vol,vd),DoubleToString(sl,dg),DoubleToString(tp,dg),vol*loss1,loss1,MagicNumber,TradeComment);
   if(DryRun)
     {
      S[si].vOpen=true; S[si].vSide=g.side; S[si].vPrice=price; S[si].vSl=sl; S[si].vTp=tp; S[si].vVol=vol; S[si].vTime=g.time;
      Notify(head+" -> WOULD SEND market"+plan);
      return;
     }
   Trade.SetExpertMagicNumber((ulong)MagicNumber); Trade.SetDeviationInPoints((ulong)DeviationPoints); Trade.SetTypeFillingBySymbol(sym);
   bool ok=Trade.PositionOpen(sym,ot,vol,price,sl,tp,TradeComment);
   Notify(head+(ok?" -> SENT":" -> FAILED")+plan+StringFormat(" retcode %u %s",Trade.ResultRetcode(),Trade.ResultRetcodeDescription()));
  }

//--- load data + run engine for one symbol
bool RunSymbol(int si,long &newest)
  {
   string sym=S[si].name; datetime now=TimeTradeServer();
   MqlRates r[];
   int n=CopyRates(sym,PERIOD_M3,now-(datetime)((long)WarmDays*86400),now,r);
   if(n<1000) { S[si].status="M3 history loading ("+IntegerToString(n)+")"; return false; }
   if((long)now-(long)r[0].time<40L*86400) Print("ZAKHM: ",sym," only ",(now-r[0].time)/86400," days of M3 history (set Tools>Options>Charts>Max bars = Unlimited)");
   Base.Clear();
   for(int i=0;i<n;i++) if((long)r[i].time+180<=(long)now) Base.Add(ToAnchor(r[i].time),r[i].open,r[i].high,r[i].low,r[i].close,0);
   MqlRates h[];
   int m=CopyRates(sym,PERIOD_H1,now-(datetime)((long)DailyWarmDays*86400),now,h);
   if(m<200) { S[si].status="H1 history loading ("+IntegerToString(m)+")"; return false; }
   H1src.Clear();
   for(int i=0;i<m;i++) if((long)h[i].time+3600<=(long)now) H1src.Add(ToAnchor(h[i].time),h[i].open,h[i].high,h[i].low,h[i].close,0);
   string err="";
   if(!ZBuildAndRun(Eng,Base,H1src,true,TFS,OsmaFast,OsmaSlow,OsmaSignal,LineMode==ZLINE_WICK,MaxZonesPerSide,err)) { S[si].status=err; return false; }
   newest=Eng.chart.n>0 ? Eng.chart.ct[Eng.chart.n-1] : 0;
   return true;
  }

void CheckSymbol(int si)
  {
   string sym=S[si].name; datetime now=TimeTradeServer();
   datetime tt[];
   if(CopyTime(sym,PERIOD_M3,0,3,tt)<2) return;
   long lastClosed=0;
   for(int i=ArraySize(tt)-1;i>=0;i--) if((long)tt[i]+180<=(long)now) { lastClosed=(long)tt[i]; break; }
   if(lastClosed==0) return;
   long hc=((ToAnchor((datetime)lastClosed)+180)/3600)*3600;          // newest H1 close covered by closed M3 data
   if(S[si].lastProc==0)
     {
      string gv=GVName("LP_"+sym);
      S[si].lastProc=GlobalVariableCheck(gv) ? (long)GlobalVariableGet(gv) : hc-3600;
     }
   if(hc<=S[si].lastProc) return;
   long newest=0;
   if(!RunSymbol(si,newest)) return;                                   // retry next timer
   long prev=S[si].lastProc;
   S[si].lastProc=hc; GlobalVariableSet(GVName("LP_"+sym),(double)hc);
   int armed=0; for(int k=0;k<Eng.nz;k++) if(Eng.z[k].state==3) armed++;
   string last=Eng.nsig>0 ? StringFormat("%s %s",Eng.sig[Eng.nsig-1].side>0?"BUY":"SELL",AT(Eng.sig[Eng.nsig-1].time)) : "-";
   int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   S[si].ready=true;
   S[si].status=StringFormat("H1 %s close %s | zones %d armed %d | last signal %s",AT(newest),DoubleToString(Eng.chart.n>0?Eng.chart.c[Eng.chart.n-1]:0,dg),Eng.nz,armed,last);
   for(int k=0;k<Eng.nsig;k++)
     {
      long t=Eng.sig[k].time;
      if(t>prev && t<=hc && t>=hc-(long)CatchupHours*3600) HandleSignal(si,Eng.sig[k]);
     }
  }

void ShowStatus(void)
  {
   double eff,stop; bool h=Halted(eff,stop);
   if(h && !HaltNotified) { HaltNotified=true; Notify(StringFormat("ZAKHM daily loss stop reached: equity %.2f <= %.2f - no new entries today",eff,stop)); }
   string s=StringFormat("ZAKHM OSMA  %s  | anchor %s (server%+d h) | lines %s | risk %.2f%% | day stop %.2f%s\n",DryRun?"DRY-RUN (no orders)":"LIVE",
                         TimeAnchor==ZANCHOR_UTC?"UTC":"server",(int)(OffsetSec/3600),LineMode==ZLINE_WICK?"wick":"body",RiskPercent,stop,h?"  HALTED":"");
   s+=StringFormat("balance %.2f equity %.2f%s | last signal %s\n",AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY),
                   DryRun?StringFormat(" (virtual P/L today %+.2f)",VClosedToday+VFloating()):"",LastSignalTxt);
   for(int i=0;i<NSym;i++)
     {
      s+=S[i].name+": "+S[i].status;
      if(S[i].vOpen) s+=StringFormat("  [virtual %s %.2f lots sl %s tp %s]",S[i].vSide>0?"BUY":"SELL",S[i].vVol,DoubleToString(S[i].vSl,_Digits),DoubleToString(S[i].vTp,_Digits));
      s+="\n";
     }
   Comment(s);
  }

int OnInit(void)
  {
   if(!ParseTFs()) return INIT_PARAMETERS_INCORRECT;
   if(RiskPercent<=0 || RiskPercent>10) { Print("RiskPercent out of range"); return INIT_PARAMETERS_INCORRECT; }
   UpdateOffset();
   BuildSymbols();
   if(NSym==0) { Print("ZAKHM: no tradable symbols found"); return INIT_FAILED; }
   string list=""; for(int i=0;i<NSym;i++) list+=(i?",":"")+S[i].name;
   Notify(StringFormat("ZAKHM OSMA started %s on %d symbols: %s | server-UTC %+d h | anchor %s",DryRun?"DRY-RUN":"LIVE",NSym,list,(int)(OffsetSec/3600),TimeAnchor==ZANCHOR_UTC?"UTC":"server"));
   if(!DryRun && !MQLInfoInteger(MQL_TRADE_ALLOWED)) Print("ZAKHM: Algo Trading not allowed for this EA - enable it");
   EventSetTimer(MathMax(1,TimerSeconds));
   OnTimer();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { EventKillTimer(); Comment(""); }

void OnTimer(void)
  {
   UpdateOffset();
   DayStartEquity();
   if(DryRun) UpdateVirtual();
   for(int i=0;i<NSym;i++) CheckSymbol(i);
   ShowStatus();
  }

void OnTick(void) {}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=MagicNumber) return;
   long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   string sym=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
   double p=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
   if(entry==DEAL_ENTRY_IN) Notify(StringFormat("ZAKHM trade opened %s %.2f lots @ %s",sym,HistoryDealGetDouble(trans.deal,DEAL_VOLUME),DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),(int)SymbolInfoInteger(sym,SYMBOL_DIGITS))));
   else Notify(StringFormat("ZAKHM trade closed %s @ %s P/L %+.2f %s",sym,DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)),p,AccountInfoString(ACCOUNT_CURRENCY)));
  }
#endif
