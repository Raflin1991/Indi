//+------------------------------------------------------------------+
//|                                                  AurumPulse.mq5 |
//|             AurumPulse v1.0 — Gold-Specialized Signal Engine     |
//|                   Session-aware | Sweep | DXY | Round | Cycle    |
//+------------------------------------------------------------------+

#property copyright "Copyright 2026, AurumPulse Labs"
#property link      "https://t.me/sbe7xofficial"
#property version   "1.000"
#property description "AurumPulse v1.0 — Gold-Specialized Signal Engine"
#property description "Session-aware parameters | Liquidity Sweep detection"
#property description "DXY correlation filter | Round-number proximity scoring"
#property description "ATR expansion/compression cycle tracking | Killzone visuals"
#property indicator_chart_window
#property indicator_plots   5
#property indicator_buffers 10

#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrLime, C'110,185,120', clrTomato, C'216,112,108'
#property indicator_type2   DRAW_ARROW
#property indicator_color2  C'0,214,180'
#property indicator_type3   DRAW_ARROW
#property indicator_color3  C'255,102,128'
#property indicator_type4   DRAW_ARROW
#property indicator_color4  C'135,255,224'
#property indicator_type5   DRAW_ARROW
#property indicator_color5  C'255,176,196'

#define REGIME_RANGING   0
#define REGIME_TRENDING  1
#define REGIME_VOLATILE  2

#define TREND_BULL  1.0
#define TREND_BEAR  0.0
#define TREND_NONE -1.0

#define STATE_WAIT       0
#define STATE_WATCH      1
#define STATE_CONFIRMED  2

#define CANDLE_STRONG_BULL 0
#define CANDLE_WEAK_BULL   1
#define CANDLE_STRONG_BEAR 2
#define CANDLE_WEAK_BEAR   3

enum ENUM_TREND_FILTER_MODE {
    FILTER_OFF,         // Off
    FILTER_ALIGN,       // Align only (with-trend)
    FILTER_WEAKEN,      // Weaken counter-trend
    FILTER_BLOCK_CT     // Block counter-trend
};

enum ENUM_GOLD_SESSION {
    SESSION_ASIA,          // Asia (00-08)
    SESSION_LONDON_PRE,    // London Pre (08-09)
    SESSION_LONDON_OPEN,   // London Open (09-12)
    SESSION_LONDON_MID,    // London Mid (12-14)
    SESSION_NY_OPEN,       // NY Open (14-16)
    SESSION_NY_PM,         // NY PM (16-19)
    SESSION_DEAD           // Dead (19-00)
};

enum ENUM_ATR_CYCLE {
    CYCLE_COMPRESSION,
    CYCLE_NORMAL,
    CYCLE_EXPANSION,
    CYCLE_CLIMAX
};

struct SessionParams {
   double thresholdMult;
   double atrFloor;
   double momentumMult;
   bool   suppressFire;
   double killzoneWeight;
};

struct TradeTracker {
   bool     active;
   double   trend;
   double   entry;
   double   stop;
   double   tp1;
   double   tp2;
   datetime entryTime;
   string   grade;
   bool     tp1Hit;
   bool     tp2Hit;
   bool     stoppedOut;
   bool     beActive;
   double   peakR;
   double   currentR;
   int      barsInTrade;
};

input group "=== Core ==="
input int    InpAtrPeriod               = 6;
input double InpTrendMult               = 0.96;
input int    InpAdxPeriod               = 6;
input int    InpRsiPeriod               = 5;
input int    InpMacdFast                = 4;
input int    InpMacdSlow                = 10;
input int    InpMacdSignal              = 3;
input int    InpFlowLookback            = 5;
input int    InpRegimeLookback          = 10;

input group "=== Signal ==="
input double InpWatchScoreThreshold     = 60.0;
input double InpConfirmedScoreThreshold = 72.0;
input double InpWatchMomentumThreshold  = 56.0;
input double InpWatchHealthFloor        = 42.0;
input double InpConfirmedHealthFloor    = 52.0;
input double InpExhaustionBlock         = 65.0;
input int    InpEarlyWindowBars         = 1;
input int    InpSignalLookbackBars      = 320;

input group "=== Display ==="
input bool   InpShowDashboard           = true;
input bool   InpShowWatchTag            = true;
input bool   InpAlertPopup              = true;
input bool   InpAlertPush               = true;
input int    InpArrowMinPoints          = 8;
input int    InpArrowMaxPoints          = 60;
input double InpArrowAtrOffset          = 0.12;
input bool   InpShowSignalMarkers       = true;
input int    InpSignalMarkerLookback    = 300;
input color  InpMarkerBuyColor          = clrLime;
input color  InpMarkerSellColor         = clrMagenta;

input group "=== Execution Guide ==="
input bool   InpShowExecutionGuide      = true;
input double InpTp1RiskMultiple         = 1.0;
input double InpTp2RiskMultiple         = 2.0;
input bool   InpUseSwingStop            = true;
input int    InpSwingLookback           = 5;
input double InpStopAtrBuffer           = 0.20;
input bool   InpUseAdaptiveTp           = true;
input double InpTp2AtrFactor            = 2.8;

input group "=== Apex Engine ==="
input bool   InpUseDivergenceFilter     = true;
input int    InpDivergenceLookback      = 18;
input double InpGradeAThreshold         = 78.0;
input double InpGradeSThreshold         = 88.0;
input bool   InpBlockGradeC             = true;
input double InpMinAdxConfirmed         = 14.0;
input int    InpSignalCooldownBars      = 2;
input bool   InpEarlyReversalMode       = true;
input double InpReversalBodyRatio       = 0.28;
input double InpReversalRangeAtr        = 0.40;
input double InpReversalWickRatio       = 0.40;
input double InpReversalMaxExh          = 82.0;
input int    InpReversalBackScan        = 6;
input bool   InpShowTradeTracker        = true;
input bool   InpShowMomentumStrip       = false;
input int    InpMomentumStripBars       = 24;
input color  InpThemeAccent             = C'255,180,60';
input color  InpThemeBullish            = C'0,214,180';
input color  InpThemeBearish            = C'255,102,128';

input group "=== Trend Filter (MTF) ==="
input ENUM_TREND_FILTER_MODE  InpTrendFilterMode       = FILTER_WEAKEN;
input ENUM_TIMEFRAMES         InpTrendFilterTF         = PERIOD_H1;
input int                     InpTrendFilterAtrPeriod   = 0;
input double                  InpTrendFilterMult        = 0.0;

input group "=== Gold Session ==="
input bool              InpUseSessionEngine      = true;
input int               InpSessionGMTOffset      = 2;
input bool              InpShowKillzones         = true;
input bool              InpFilterAsiaSignals     = true;
input double            InpAsiaThresholdMult     = 1.45;
input double            InpLondonThresholdMult   = 0.78;
input double            InpNYThresholdMult       = 1.20;

input group "=== Gold Liquidity Sweep ==="
input bool   InpUseSweepDetection     = true;
input int    InpSweepLookback          = 10;
input double InpMinSweepDepthAtr      = 0.12;
input double InpSweepRetraceRatio     = 0.35;
input double InpSweepGradeBonus       = 12.0;

input group "=== Gold DXY Filter ==="
input bool   InpUseDXYFilter          = true;
input string InpDXYSymbol             = "USDX";
input int    InpDXYCorrLookback       = 20;
input double InpDXYMinInvCorr         = -0.40;
input double InpDXYBlockBelowGrade    = 60.0;

input group "=== Gold Round Numbers ==="
input bool   InpUseRoundNumbers       = true;
input double InpRoundNumberInterval   = 100.0;
input double InpRoundCriticalDistPct  = 0.10;
input double InpRoundReactionDistPct  = 0.30;
input double InpRoundWatchDistPct     = 0.60;
input double InpRoundRetestBonus      = 10.0;

input group "=== Gold ATR Cycle ==="
input bool   InpUseATRCycle           = true;
input int    InpATRCycleMALength      = 14;
input double InpATRCompressionRatio   = 0.65;
input double InpATRExpansionRatio     = 1.40;
input double InpATRClimaxRatio        = 2.50;
input double InpCompressionEntryBonus = 12.0;

input group "=== Gold Thresholds ==="
input double InpGoldConfirmedThreshold = 74.0;
input double InpGoldWatchThreshold     = 62.0;
input double InpGoldMomentumFloor      = 58.0;
input double InpGoldHealthFloor        = 52.0;
input double InpGoldMinADX             = 14.0;

double bufOpen[], bufHigh[], bufLow[], bufClose[], bufColor[];
double bufConfirmedBuy[], bufConfirmedSell[];
double bufWatchBuy[], bufWatchSell[];
double bufAux[];

double tmpATR[], tmpADXMain[], tmpDIPlus[], tmpDIMinus[];
double tmpRSI[], tmpMACDMain[], tmpMACDSignal[];
double tmpTF_ATR[];

double workTrend[], workPrevTrend[], workTrendAge[];
double workFinalUp[], workFinalDn[];
double workFlow[], workMomentum[];
double workHealth[], workExhaustion[];
double workRegime[], workConfirmedScore[], workLiveScore[];
double workSignalState[];
double workSignalTrend[];
double workHTFTrend[];
double workHTFPrevTrend[];
double workHTFFinalUp[];
double workHTFFinalDn[];
double workHTFTrendAge[];

double workSweepDepth[];
double workRoundScore[];
double workCycleState[];
double workCycleBias[];
double workDXYCorrelation[];
double workSession[];

int hATR = INVALID_HANDLE;
int hADX = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hTF_ATR = INVALID_HANDLE;

double g_tfAtrPeriod = 0;
double g_tfMult = 0.0;
ENUM_TREND_FILTER_MODE g_tfMode = FILTER_OFF;
bool g_dxyAvailable = false;
ENUM_GOLD_SESSION g_cacheSession = SESSION_DEAD;
datetime g_cacheSessionTime = 0;
double g_dxyCloseCache[];

int g_minBars = 60;
double g_effectiveTrendMult = 0.96;
int g_effectiveFlowLookback = 5;
int g_effectiveRegimeLookback = 10;
double g_effectiveWatchThreshold = 60.0;
double g_effectiveConfirmedThreshold = 72.0;
double g_effectiveWatchMomentumThreshold = 56.0;
double g_effectiveWatchHealthFloor = 42.0;
double g_effectiveConfirmedHealthFloor = 52.0;
double g_effectiveExhaustionBlock = 65.0;
double g_effectiveLiveBoost = 7.0;
double g_effectiveFastBreakoutBonus = 7.0;
double g_effectiveArrowAtrOffset = 0.12;
int g_effectiveArrowMinPoints = 8;
int g_effectiveArrowMaxPoints = 60;

double g_goldConfirmedThreshold = 74.0;
double g_goldWatchThreshold = 62.0;
double g_goldMomentumFloor = 58.0;
double g_goldHealthFloor = 52.0;
double g_goldMinADX = 14.0;

TradeTracker g_tracker;
double workGrade[];
double workDiv[];

void ConfigureMode();
void ResizeWorkArrays(int bars);
void SetAllSeries();
void InitBuffers();
void ConfigurePlots();
void ConfigureChart();
double ClampPct(double value);
double ClampRange(double value, double low, double high);
bool IsFreshBreakout(int idx);
bool IsTrendBodyAligned(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[]);
double CalcArrowPrice(int idx, bool isBuy, const double &high[], const double &low[]);
double CalcGuideTargetPrice(double entryPrice, double stopPrice, double trend, double riskMultiple);
double NormalizeStopSide(int idx, double entryPrice, double stopPrice, double trend);
double CalcFlowPressureLite(int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], int rates_total);
double CalcIntrabarMomentumLite(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], int rates_total);
double CalcDirectionalEdgeLite(int idx, double trend);
double GetAlignedFlowLite(int idx, double trend);
double CalchealthLite(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[], int rates_total);
double CalcExhaustionLite(int idx, double trend, const long &tick_volume[], int rates_total);
int DetectRegimeLite(int idx, const double &close[], int rates_total);
double CalcConfirmedScoreLite(int idx, double trend, int regime);
double CalcLiveScoreLite(int idx, double trend, int regime);
bool IsWatchSignal(int idx, double trend, double &dirEdge);
bool IsFastConfirmedImpulse(int idx, double trend, double dirEdge);
bool IsConfirmedSignal(int idx, double trend, double &dirEdge);
string TFToStr(ENUM_TIMEFRAMES tf);
string TrendDirToStr(double trend);
string SignalToStr(double trend);
double SignalTrendAt(int idx);
string StateToStr(int state);
string FitText(string text, int maxChars);
string MakeBar(int value, int maxValue, int width);
void MakePanel(string name, int x, int y, int w, int h);
void MakeLabel(string name, int x, int y, string text, int size, color clr);
void UpsertLine(string name, datetime t1, datetime t2, double price, color clr, ENUM_LINE_STYLE style, int width);
void UpsertTagBox(string name, int left, int top, int width, int height, color fillClr, color borderClr);
void UpsertTagLabel(string name, int x, int y, string text, color clr, int size);
void DeleteConfirmedGuideObjects();
void DeleteConfirmedObjects();
void DeleteWatchObjects();
void DeleteDashboardObjects();
void DrawConfirmedLevels(int idx, double trend);
void DrawWatchLevels(int idx, double trend);
int FindLatestConfirmedBar(int maxLookback);
int FindConfirmedBarInCurrentLeg(int maxLookback);
void RefreshVisuals();
void DrawSignalMarkers();
void DeleteSignalMarkers();
void DrawDashboard();
void CheckAlerts(int prevCalculated, int rates, const datetime &time[], const double &close[]);

bool   InitTrendFilter();
void   CalcHTFSupertrend(int i, int oldest, const double &close[], int rates_total);
bool   IsSignalAligned(double localTrend, double htTrend);
double GetHTFBiasScore(int idx, double localTrend);
void   DrawHTFTrendRow(int x, int &y, int w, int maxChars);
string GetHTFContextString(int idx);

double CalcSignalGrade(int idx, double trend, double dirEdge, double htBias);
string GradeLetter(double grade);
color  GradeColor(double grade);
bool   DetectDivergenceLite(int idx, double trend);
bool   IsPivotReversal(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[], int rates_total);
int    FindPivotCandleBack(int flipIdx, double newTrend, const double &open[], const double &high[], const double &low[], const double &close[], int rates_total);
double CalcSwingStop(int idx, double trend, const double &high[], const double &low[]);
double CalcAdaptiveTp2(double entry, double stop, double trend, double atr);
void   ResetTradeTracker();
void   InitTradeTracker(int idx, double trend, double grade);
void   UpdateTradeTracker(const double &high[], const double &low[], const double &close[]);
void   DrawTradeTrackerPanel(int x, int y, int w);
void   DrawGaugeBar(string base, int x, int y, int w, int h, double value, double maxV, color fill, color bg, color border);
void   DrawMomentumStrip();
void   DeleteMomentumStrip();

ENUM_GOLD_SESSION DetectGoldSession(datetime serverTime);
SessionParams GetSessionParams(ENUM_GOLD_SESSION session);
bool   DetectLiquiditySweep(int idx, double trend, double &sweepDepth, int &sweepBarsAgo);
bool   InitDXYFilter();
double GetDXYBias(int idx, double trend);
double CalcRollingDXYCorrelation(int idx, int lookback, int rates_total);
double CalcRoundNumberProximity(double price, int idx, ENUM_ATR_CYCLE cycle);
ENUM_ATR_CYCLE DetectATRCycle(int idx);
double GetCycleBias(ENUM_ATR_CYCLE cycle);
double CalcGoldConfirmedScore(int idx, double trend, int regime, double sweepDepth, double roundScore, double cycleBias, double sessionMult, double dxyBias, double momentumMult);
double CalcGoldLiveScore(int idx, double trend, int regime, double sweepDepth, double roundScore, double cycleBias, double sessionMult, double dxyBias, double momentumMult);
bool   IsGoldConfirmedSignal(int idx, double trend, double &dirEdge, double goldScore, bool sessionBlocked, double sweepDepth, ENUM_ATR_CYCLE cycle);
string SessionToStr(ENUM_GOLD_SESSION session);
color  SessionColor(ENUM_GOLD_SESSION session);
string CycleToStr(ENUM_ATR_CYCLE cycle);
color  CycleColor(ENUM_ATR_CYCLE cycle);
void   DrawKillzoneMarkers();
void   DrawGoldDashboardRows(int x, int &y, int panelW, int maxChars, int confirmedBar, double confirmedTrend);
void   DeleteKillzoneMarkers();

int OnInit()
{
   if(InpAtrPeriod < 1 || InpTrendMult <= 0.0)
      return INIT_PARAMETERS_INCORRECT;
   if(InpAdxPeriod < 2 || InpRsiPeriod < 2 || InpMacdFast >= InpMacdSlow)
      return INIT_PARAMETERS_INCORRECT;

   ConfigureMode();

   hATR  = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   hADX  = iADX(_Symbol, PERIOD_CURRENT, InpAdxPeriod);
   hRSI  = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);
   hMACD = iMACD(_Symbol, PERIOD_CURRENT, InpMacdFast, InpMacdSlow, InpMacdSignal, PRICE_CLOSE);

   if(hATR == INVALID_HANDLE || hADX == INVALID_HANDLE || hRSI == INVALID_HANDLE || hMACD == INVALID_HANDLE)
      return INIT_FAILED;

   if(!InitTrendFilter()) {
      Print("AurumPulse: Trend filter init failed, disabling filter");
      g_tfMode = FILTER_OFF;
   }

   if(InpUseDXYFilter && !InitDXYFilter()) {
      Print("AurumPulse: DXY filter init failed (symbol not found: ", InpDXYSymbol, "), DXY filter disabled");
   }

   SetIndexBuffer(0, bufOpen, INDICATOR_DATA);
   SetIndexBuffer(1, bufHigh, INDICATOR_DATA);
   SetIndexBuffer(2, bufLow, INDICATOR_DATA);
   SetIndexBuffer(3, bufClose, INDICATOR_DATA);
   SetIndexBuffer(4, bufColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, bufConfirmedBuy, INDICATOR_DATA);
   SetIndexBuffer(6, bufConfirmedSell, INDICATOR_DATA);
   SetIndexBuffer(7, bufWatchBuy, INDICATOR_DATA);
   SetIndexBuffer(8, bufWatchSell, INDICATOR_DATA);
   SetIndexBuffer(9, bufAux, INDICATOR_CALCULATIONS);

   SetAllSeries();
   ConfigurePlots();
   ConfigureChart();
   InitBuffers();
   ResetTradeTracker();

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("AurumPulse v1.0 GOLD (%s)", TFToStr(Period())));
   IndicatorSetInteger(INDICATOR_DIGITS, Digits());
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(spread, true);

   if(rates_total <= g_minBars)
      return 0;

   int calcBars = MathMin(rates_total, MathMax(InpSignalLookbackBars, g_minBars + 40));
   int copyCount = MathMin(rates_total, calcBars + 10);

   if(CopyBuffer(hATR, 0, 0, copyCount, tmpATR) < copyCount) return prev_calculated;
   if(CopyBuffer(hADX, 0, 0, copyCount, tmpADXMain) < copyCount) return prev_calculated;
   if(CopyBuffer(hADX, 1, 0, copyCount, tmpDIPlus) < copyCount) return prev_calculated;
   if(CopyBuffer(hADX, 2, 0, copyCount, tmpDIMinus) < copyCount) return prev_calculated;
   if(CopyBuffer(hRSI, 0, 0, copyCount, tmpRSI) < copyCount) return prev_calculated;
   if(CopyBuffer(hMACD, 0, 0, copyCount, tmpMACDMain) < copyCount) return prev_calculated;
   if(CopyBuffer(hMACD, 1, 0, copyCount, tmpMACDSignal) < copyCount) return prev_calculated;

   bool htfDataOk = false;
   if(g_tfMode != FILTER_OFF && hTF_ATR != INVALID_HANDLE) {
      int htfCopied = CopyBuffer(hTF_ATR, 0, 0, copyCount, tmpTF_ATR);
      htfDataOk = (htfCopied >= copyCount);
      if(!htfDataOk) {
         Print("AurumPulse: HTF ATR data insufficient (", htfCopied, "/", copyCount, "), filter disabled this pass");
      }
   }

   bool dxyDataOk = false;
   if(g_dxyAvailable && InpUseDXYFilter) {
      int dxyCopied = CopyClose(InpDXYSymbol, PERIOD_CURRENT, 0, copyCount, g_dxyCloseCache);
      dxyDataOk = (dxyCopied >= copyCount);
      if(!dxyDataOk && prev_calculated == 0) {
         Print("AurumPulse: DXY close data insufficient, DXY filter disabled this pass");
      }
   }

   ResizeWorkArrays(rates_total);
   InitBuffers();

   int    latestSigIdx   = -1;
   double latestSigTrend = TREND_NONE;
   double latestSigGrade = 0.0;

   int oldest = MathMin(rates_total - 1, calcBars - 1);
   bool legConfirmed = false;
   double activeSignalTrend = TREND_NONE;
   for(int i = oldest; i >= 0; i--) {
      bufConfirmedBuy[i] = EMPTY_VALUE;
      bufConfirmedSell[i] = EMPTY_VALUE;
      bufWatchBuy[i] = EMPTY_VALUE;
      bufWatchSell[i] = EMPTY_VALUE;
      workSignalState[i] = (double)STATE_WAIT;
      workSignalTrend[i] = TREND_NONE;

      double mid = (high[i] + low[i] + close[i] + close[i]) / 4.0;
      double bandUp = mid + tmpATR[i] * g_effectiveTrendMult;
      double bandDn = mid - tmpATR[i] * g_effectiveTrendMult;

      if(i == oldest) {
         workFinalUp[i] = bandUp;
         workFinalDn[i] = bandDn;
         workTrend[i] = (close[i] >= mid) ? TREND_BULL : TREND_BEAR;
         workPrevTrend[i] = TREND_NONE;
         workTrendAge[i] = 1.0;
      } else {
         int p = i + 1;
         workFinalUp[i] = (bandUp < workFinalUp[p] || close[p] > workFinalUp[p]) ? bandUp : workFinalUp[p];
         workFinalDn[i] = (bandDn > workFinalDn[p] || close[p] < workFinalDn[p]) ? bandDn : workFinalDn[p];
         workPrevTrend[i] = workTrend[p];

         if(workTrend[p] == TREND_BEAR)
            workTrend[i] = (close[i] > workFinalUp[i]) ? TREND_BULL : TREND_BEAR;
         else
            workTrend[i] = (close[i] < workFinalDn[i]) ? TREND_BEAR : TREND_BULL;

         workTrendAge[i] = (workTrend[i] == workTrend[p]) ? workTrendAge[p] + 1.0 : 1.0;
      }

      bufOpen[i] = open[i];
      bufHigh[i] = high[i];
      bufLow[i] = low[i];
      bufClose[i] = close[i];

      if(g_tfMode != FILTER_OFF && htfDataOk)
         CalcHTFSupertrend(i, oldest, close, rates_total);

      ENUM_GOLD_SESSION session = SESSION_DEAD;
      if(InpUseSessionEngine) {
         session = DetectGoldSession(time[i]);
         if((int)session < 0 || (int)session > 6) session = SESSION_DEAD;
      }
      workSession[i] = (double)session;

      double sweepDepth = 0.0;
      if(InpUseSweepDetection && i >= 1 && workTrend[i] != TREND_NONE) {
         int sweepBars = -1;
         DetectLiquiditySweep(i, workTrend[i], sweepDepth, sweepBars);
         if(sweepDepth > 0.0)
            workSweepDepth[i] = sweepDepth;
      }

      ENUM_ATR_CYCLE cycle = CYCLE_NORMAL;
      double cycleBias = 0.0;
      if(InpUseATRCycle) {
         cycle = DetectATRCycle(i);
         cycleBias = GetCycleBias(cycle);
         workCycleState[i] = (double)cycle;
         workCycleBias[i] = cycleBias;
      }

      double roundScore = 0.0;
      if(InpUseRoundNumbers) {
         roundScore = CalcRoundNumberProximity(close[i], i, cycle);
         workRoundScore[i] = roundScore;
      }

      double dxyBias = 0.0;
      if(InpUseDXYFilter && g_dxyAvailable && dxyDataOk) {
         if(i == 0 || i % 10 == 0 || i == oldest)
            workDXYCorrelation[i] = CalcRollingDXYCorrelation(i, InpDXYCorrLookback, rates_total);
         else if(i + 1 < ArraySize(workDXYCorrelation))
            workDXYCorrelation[i] = workDXYCorrelation[i + 1];
         dxyBias = GetDXYBias(i, workTrend[i]);
      }

      workFlow[i] = CalcFlowPressureLite(i, open, high, low, close, tick_volume, rates_total);
      workMomentum[i] = CalcIntrabarMomentumLite(i, workTrend[i], open, high, low, close, tick_volume, rates_total);
      workHealth[i] = CalchealthLite(i, workTrend[i], open, high, low, close, rates_total);
      workRegime[i] = (double)DetectRegimeLite(i, close, rates_total);
      workExhaustion[i] = CalcExhaustionLite(i, workTrend[i], tick_volume, rates_total);

      SessionParams sp;
      double sessionMult = 1.0;
      double momentumMult = 1.0;
      bool sessionBlocked = false;
      if(InpUseSessionEngine) {
         sp = GetSessionParams(session);
         sessionMult = sp.thresholdMult;
         momentumMult = sp.momentumMult;
         sessionBlocked = InpFilterAsiaSignals && sp.suppressFire && session == SESSION_ASIA;
      }

      workConfirmedScore[i] = CalcGoldConfirmedScore(i, workTrend[i], (int)workRegime[i], sweepDepth, roundScore, cycleBias, sessionMult, dxyBias, momentumMult);
      workLiveScore[i] = CalcGoldLiveScore(i, workTrend[i], (int)workRegime[i], sweepDepth, roundScore, cycleBias, sessionMult, dxyBias, momentumMult);

      bool strong = workConfirmedScore[i] >= g_goldConfirmedThreshold && workHealth[i] >= g_goldHealthFloor;
      if(workTrend[i] == TREND_BULL)
         bufColor[i] = strong ? (double)CANDLE_STRONG_BULL : (double)CANDLE_WEAK_BULL;
      else
         bufColor[i] = strong ? (double)CANDLE_STRONG_BEAR : (double)CANDLE_WEAK_BEAR;

      if(activeSignalTrend == TREND_BULL)
         bufColor[i] = strong ? (double)CANDLE_STRONG_BULL : (double)CANDLE_WEAK_BULL;
      else if(activeSignalTrend == TREND_BEAR)
         bufColor[i] = strong ? (double)CANDLE_STRONG_BEAR : (double)CANDLE_WEAK_BEAR;

      if(i == oldest || workTrend[i] != workTrend[i + 1])
         legConfirmed = false;

      if(i >= 0 && !legConfirmed) {
         bool newsSpike = false;
         if(i >= 0 && i < ArraySize(tmpATR) && tmpATR[i] > _Point) {
            double atrSum = 0.0; int atrCnt = 0;
            int atrLook = MathMin(20, ArraySize(tmpATR) - i - 1);
            for(int j = i + 1; j <= i + atrLook && j < ArraySize(tmpATR); j++) {
               if(tmpATR[j] > _Point) { atrSum += tmpATR[j]; atrCnt++; }
            }
            if(atrCnt >= 8 && tmpATR[i] > (atrSum / atrCnt) * 2.8) newsSpike = true;
         }
         if(!newsSpike) {

         double confirmedDirEdge = 0.0;
         bool stdSig = IsGoldConfirmedSignal(i, workTrend[i], confirmedDirEdge, workConfirmedScore[i], sessionBlocked, sweepDepth, cycle);
         bool pivotSig = (!stdSig) && IsPivotReversal(i, workTrend[i], open, high, low, close, rates_total);
         bool sweepSignal = (!stdSig && !pivotSig) && InpUseSweepDetection && sweepDepth >= InpMinSweepDepthAtr * 1.5;

          if(stdSig || pivotSig || sweepSignal) {
             if(sessionBlocked && !pivotSig && workConfirmedScore[i] < InpGradeSThreshold)
                continue;
             if(!stdSig) confirmedDirEdge = CalcDirectionalEdgeLite(i, workTrend[i]);
            bool hasDiv = DetectDivergenceLite(i, workTrend[i]);
            workDiv[i] = hasDiv ? ((workTrend[i] == TREND_BULL) ? -1.0 : 1.0) : 0.0;
            bool divBlock = InpUseDivergenceFilter && hasDiv;

            double htBias = 0.0;
            if(g_tfMode != FILTER_OFF && htfDataOk) {
               bool isAligned = IsSignalAligned(workTrend[i], workHTFTrend[i]);
               if((g_tfMode == FILTER_ALIGN || g_tfMode == FILTER_BLOCK_CT) && !isAligned)
                  continue;
               htBias = GetHTFBiasScore(i, workTrend[i]);
            }

            double grade = CalcSignalGrade(i, workTrend[i], confirmedDirEdge, 0.0);
            if(pivotSig) grade = MathMax(grade, 62.0);
            if(sweepSignal) grade = MathMax(grade, 60.0);
            if(divBlock) grade = MathMax(grade - 18.0, 0.0);

            if(g_tfMode == FILTER_WEAKEN && htfDataOk) {
               bool isAligned = IsSignalAligned(workTrend[i], workHTFTrend[i]);
               if(!isAligned)
                  grade = MathMin(grade, 77.0);
            }

            grade += htBias;
            grade = ClampPct(grade);
            if(dxyBias < -14.0 && grade < InpDXYBlockBelowGrade)
               continue;
            grade += dxyBias * 0.25;
            grade = ClampPct(grade);

            workGrade[i] = grade;
            string letter = GradeLetter(grade);
            bool gradeBlocked = (!pivotSig && !sweepSignal) && InpBlockGradeC && (letter == "C" || letter == "D");
            if(!divBlock && !gradeBlocked) {
               double signalTrend = workTrend[i];
               if(signalTrend == TREND_BULL) {
                  bufConfirmedBuy[i] = CalcArrowPrice(i, true, high, low);
               } else {
                  bufConfirmedSell[i] = CalcArrowPrice(i, false, high, low);
               }
               int flipBar = i + ((int)workTrendAge[i] - 1);
               for(int c = flipBar; c >= i && c >= 0; c--) {
                  if(c >= ArraySize(bufColor)) continue;
                   bool cStrong = workConfirmedScore[c] >= g_goldConfirmedThreshold && workHealth[c] >= g_goldHealthFloor;
                  if(signalTrend == TREND_BULL)
                     bufColor[c] = cStrong ? (double)CANDLE_STRONG_BULL : (double)CANDLE_WEAK_BULL;
                  else
                     bufColor[c] = cStrong ? (double)CANDLE_STRONG_BEAR : (double)CANDLE_WEAK_BEAR;
               }
               activeSignalTrend = signalTrend;
               workSignalState[i] = (double)STATE_CONFIRMED;
               workSignalTrend[i] = signalTrend;
               workGrade[i] = grade;
               legConfirmed = true;
               latestSigIdx   = i;
               latestSigTrend = signalTrend;
               latestSigGrade = grade;
             }
          }
        }
       }
   }

   if(latestSigIdx >= 0) {
      datetime newEntryTime = iTime(_Symbol, PERIOD_CURRENT, latestSigIdx);
      if(!g_tracker.active || g_tracker.entryTime != newEntryTime || g_tracker.trend != latestSigTrend) {
         InitTradeTracker(latestSigIdx, latestSigTrend, latestSigGrade);
      }
   }

   UpdateTradeTracker(high, low, close);

   RefreshVisuals();
   CheckAlerts(prev_calculated, rates_total, time, close);
   DrawDashboard();
   return rates_total;
}

void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hTF_ATR != INVALID_HANDLE) IndicatorRelease(hTF_ATR);
   DeleteConfirmedObjects();
   DeleteWatchObjects();
   DeleteKillzoneMarkers();
   ObjectsDeleteAll(0, "AU_");
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE) {
      RefreshVisuals();
      if(InpShowDashboard)
         DrawDashboard();
   }
}

void ConfigureMode()
{
   g_effectiveTrendMult = MathMax(InpTrendMult, 0.1);
   g_effectiveFlowLookback = MathMax(InpFlowLookback, 3);
   g_effectiveRegimeLookback = MathMax(InpRegimeLookback, 4);
   g_effectiveWatchThreshold = ClampRange(InpWatchScoreThreshold, 5.0, 95.0);
   g_effectiveConfirmedThreshold = ClampRange(InpConfirmedScoreThreshold, 5.0, 99.0);
   g_effectiveWatchMomentumThreshold = ClampRange(InpWatchMomentumThreshold, 5.0, 95.0);
   g_effectiveWatchHealthFloor = ClampRange(InpWatchHealthFloor, 0.0, 95.0);
   g_effectiveConfirmedHealthFloor = ClampRange(InpConfirmedHealthFloor, 0.0, 99.0);
   g_effectiveExhaustionBlock = ClampRange(InpExhaustionBlock, 20.0, 99.0);
   g_effectiveLiveBoost = 7.0;
   g_effectiveFastBreakoutBonus = 7.0;
   g_effectiveArrowAtrOffset = ClampRange(InpArrowAtrOffset, 0.05, 1.50);
   g_effectiveArrowMinPoints = MathMax(InpArrowMinPoints, 0);
   g_effectiveArrowMaxPoints = MathMax(InpArrowMaxPoints, 0);

   if(_Period <= PERIOD_M1) {
      g_effectiveTrendMult = MathMax(g_effectiveTrendMult, 1.02);
      g_effectiveFlowLookback = MathMax(g_effectiveFlowLookback, 6);
      g_effectiveRegimeLookback = MathMax(g_effectiveRegimeLookback, 10);
      g_effectiveWatchThreshold = MathMax(g_effectiveWatchThreshold, 62.0);
      g_effectiveConfirmedThreshold = MathMax(g_effectiveConfirmedThreshold, 71.0);
      g_effectiveWatchMomentumThreshold = MathMax(g_effectiveWatchMomentumThreshold, 58.0);
      g_effectiveWatchHealthFloor = MathMax(g_effectiveWatchHealthFloor, 44.0);
      g_effectiveConfirmedHealthFloor = MathMax(g_effectiveConfirmedHealthFloor, 54.0);
      g_effectiveExhaustionBlock = MathMin(g_effectiveExhaustionBlock, 68.0);
      g_effectiveLiveBoost = 6.0;
      g_effectiveFastBreakoutBonus = 6.0;
   } else if(_Period <= PERIOD_M5) {
      g_effectiveTrendMult = MathMax(g_effectiveTrendMult, 0.96);
      g_effectiveFlowLookback = MathMax(g_effectiveFlowLookback, 5);
      g_effectiveRegimeLookback = MathMax(g_effectiveRegimeLookback, 8);
      g_effectiveWatchThreshold = MathMax(g_effectiveWatchThreshold, 60.0);
      g_effectiveConfirmedThreshold = MathMax(g_effectiveConfirmedThreshold, 69.0);
      g_effectiveWatchMomentumThreshold = MathMax(g_effectiveWatchMomentumThreshold, 56.0);
      g_effectiveWatchHealthFloor = MathMax(g_effectiveWatchHealthFloor, 42.0);
      g_effectiveConfirmedHealthFloor = MathMax(g_effectiveConfirmedHealthFloor, 52.0);
      g_effectiveExhaustionBlock = MathMin(g_effectiveExhaustionBlock, 70.0);
      g_effectiveLiveBoost = 7.0;
      g_effectiveFastBreakoutBonus = 7.0;
   } else if(_Period <= PERIOD_M15) {
      g_effectiveTrendMult = MathMax(g_effectiveTrendMult, 1.06);
      g_effectiveFlowLookback = MathMax(g_effectiveFlowLookback, 6);
      g_effectiveRegimeLookback = MathMax(g_effectiveRegimeLookback, 10);
      g_effectiveWatchThreshold = MathMax(g_effectiveWatchThreshold, 60.0);
      g_effectiveConfirmedThreshold = MathMax(g_effectiveConfirmedThreshold, 70.0);
      g_effectiveWatchMomentumThreshold = MathMax(g_effectiveWatchMomentumThreshold, 56.0);
      g_effectiveWatchHealthFloor = MathMax(g_effectiveWatchHealthFloor, 42.0);
      g_effectiveConfirmedHealthFloor = MathMax(g_effectiveConfirmedHealthFloor, 52.0);
      g_effectiveExhaustionBlock = MathMin(g_effectiveExhaustionBlock, 68.0);
      g_effectiveLiveBoost = 5.0;
      g_effectiveFastBreakoutBonus = 5.0;
   }

   g_goldConfirmedThreshold = ClampRange(InpGoldConfirmedThreshold, 40.0, 98.0);
   g_goldWatchThreshold = ClampRange(InpGoldWatchThreshold, 35.0, 95.0);
   g_goldMomentumFloor = ClampRange(InpGoldMomentumFloor, 20.0, 90.0);
   g_goldHealthFloor = ClampRange(InpGoldHealthFloor, 20.0, 90.0);
   g_goldMinADX = ClampRange(InpGoldMinADX, 8.0, 35.0);

   g_minBars = MathMax(g_minBars, InpAtrPeriod + 8);
   g_minBars = MathMax(g_minBars, InpAdxPeriod + 8);
   g_minBars = MathMax(g_minBars, InpMacdSlow + InpMacdSignal + 10);

   g_tfMode = InpTrendFilterMode;
   g_tfAtrPeriod = (InpTrendFilterAtrPeriod > 0) ? InpTrendFilterAtrPeriod : InpAtrPeriod;
   g_tfMult = (InpTrendFilterMult > 0.0) ? InpTrendFilterMult : InpTrendMult;
   if(g_tfMode != FILTER_OFF)
      g_minBars = MathMax(g_minBars, (int)g_tfAtrPeriod + 10);

   if(InpUseATRCycle)
      g_minBars = MathMax(g_minBars, InpATRCycleMALength + 6);

   g_minBars = MathMax(g_minBars, g_effectiveRegimeLookback + 4);
}

void ResizeWorkArrays(int bars)
{
   ArrayResize(workTrend, bars);
   ArrayResize(workPrevTrend, bars);
   ArrayResize(workTrendAge, bars);
   ArrayResize(workFinalUp, bars);
   ArrayResize(workFinalDn, bars);
   ArrayResize(workFlow, bars);
   ArrayResize(workMomentum, bars);
   ArrayResize(workHealth, bars);
   ArrayResize(workExhaustion, bars);
   ArrayResize(workRegime, bars);
   ArrayResize(workConfirmedScore, bars);
   ArrayResize(workLiveScore, bars);
   ArrayResize(workSignalState, bars);
   ArrayResize(workSignalTrend, bars);
   ArrayResize(workGrade, bars);
   ArrayResize(workDiv, bars);
   ArrayResize(workHTFTrend, bars);
   ArrayResize(workHTFPrevTrend, bars);
   ArrayResize(workHTFFinalUp, bars);
   ArrayResize(workHTFFinalDn, bars);
   ArrayResize(workHTFTrendAge, bars);
   ArrayResize(workSweepDepth, bars);
   ArrayResize(workRoundScore, bars);
   ArrayResize(workCycleState, bars);
   ArrayResize(workCycleBias, bars);
   ArrayResize(workDXYCorrelation, bars);
   ArrayResize(workSession, bars);
   ArrayResize(g_dxyCloseCache, bars);
   SetAllSeries();
}

void SetAllSeries()
{
   ArraySetAsSeries(bufOpen, true);
   ArraySetAsSeries(bufHigh, true);
   ArraySetAsSeries(bufLow, true);
   ArraySetAsSeries(bufClose, true);
   ArraySetAsSeries(bufColor, true);
   ArraySetAsSeries(bufConfirmedBuy, true);
   ArraySetAsSeries(bufConfirmedSell, true);
   ArraySetAsSeries(bufWatchBuy, true);
   ArraySetAsSeries(bufWatchSell, true);
   ArraySetAsSeries(bufAux, true);

   ArraySetAsSeries(tmpATR, true);
   ArraySetAsSeries(tmpADXMain, true);
   ArraySetAsSeries(tmpDIPlus, true);
   ArraySetAsSeries(tmpDIMinus, true);
   ArraySetAsSeries(tmpRSI, true);
   ArraySetAsSeries(tmpMACDMain, true);
   ArraySetAsSeries(tmpMACDSignal, true);
   ArraySetAsSeries(tmpTF_ATR, true);

   ArraySetAsSeries(workTrend, true);
   ArraySetAsSeries(workPrevTrend, true);
   ArraySetAsSeries(workTrendAge, true);
   ArraySetAsSeries(workFinalUp, true);
   ArraySetAsSeries(workFinalDn, true);
   ArraySetAsSeries(workFlow, true);
   ArraySetAsSeries(workMomentum, true);
   ArraySetAsSeries(workHealth, true);
   ArraySetAsSeries(workExhaustion, true);
   ArraySetAsSeries(workRegime, true);
   ArraySetAsSeries(workConfirmedScore, true);
   ArraySetAsSeries(workLiveScore, true);
   ArraySetAsSeries(workSignalState, true);
   ArraySetAsSeries(workSignalTrend, true);
   ArraySetAsSeries(workGrade, true);
   ArraySetAsSeries(workDiv, true);
   ArraySetAsSeries(workHTFTrend, true);
   ArraySetAsSeries(workHTFPrevTrend, true);
   ArraySetAsSeries(workHTFFinalUp, true);
   ArraySetAsSeries(workHTFFinalDn, true);
   ArraySetAsSeries(workHTFTrendAge, true);
   ArraySetAsSeries(workSweepDepth, true);
   ArraySetAsSeries(workRoundScore, true);
   ArraySetAsSeries(workCycleState, true);
   ArraySetAsSeries(workCycleBias, true);
   ArraySetAsSeries(workDXYCorrelation, true);
   ArraySetAsSeries(workSession, true);
   ArraySetAsSeries(g_dxyCloseCache, true);
}

void InitBuffers()
{
   ArrayInitialize(bufOpen, EMPTY_VALUE);
   ArrayInitialize(bufHigh, EMPTY_VALUE);
   ArrayInitialize(bufLow, EMPTY_VALUE);
   ArrayInitialize(bufClose, EMPTY_VALUE);
   ArrayInitialize(bufColor, 0.0);
   ArrayInitialize(bufConfirmedBuy, EMPTY_VALUE);
   ArrayInitialize(bufConfirmedSell, EMPTY_VALUE);
   ArrayInitialize(bufWatchBuy, EMPTY_VALUE);
   ArrayInitialize(bufWatchSell, EMPTY_VALUE);
   ArrayInitialize(bufAux, 0.0);

   ArrayInitialize(workTrend, TREND_NONE);
   ArrayInitialize(workPrevTrend, TREND_NONE);
   ArrayInitialize(workTrendAge, 0.0);
   ArrayInitialize(workFinalUp, EMPTY_VALUE);
   ArrayInitialize(workFinalDn, EMPTY_VALUE);
   ArrayInitialize(workFlow, 0.0);
   ArrayInitialize(workMomentum, 0.0);
   ArrayInitialize(workHealth, 50.0);
   ArrayInitialize(workExhaustion, 0.0);
   ArrayInitialize(workRegime, (double)REGIME_RANGING);
   ArrayInitialize(workConfirmedScore, 0.0);
   ArrayInitialize(workLiveScore, 0.0);
   ArrayInitialize(workSignalState, (double)STATE_WAIT);
   ArrayInitialize(workSignalTrend, TREND_NONE);
   ArrayInitialize(workGrade, 0.0);
   ArrayInitialize(workDiv, 0.0);
   ArrayInitialize(workHTFTrend, TREND_NONE);
   ArrayInitialize(workHTFPrevTrend, TREND_NONE);
   ArrayInitialize(workHTFFinalUp, EMPTY_VALUE);
   ArrayInitialize(workHTFFinalDn, EMPTY_VALUE);
   ArrayInitialize(workHTFTrendAge, 0.0);
   ArrayInitialize(workSweepDepth, 0.0);
   ArrayInitialize(workRoundScore, 0.0);
   ArrayInitialize(workCycleState, (double)CYCLE_NORMAL);
   ArrayInitialize(workCycleBias, 0.0);
   ArrayInitialize(workDXYCorrelation, 0.0);
   ArrayInitialize(workSession, (double)SESSION_DEAD);
   ArrayInitialize(g_dxyCloseCache, 0.0);
}

void ConfigurePlots()
{
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_minBars);

   PlotIndexSetInteger(1, PLOT_ARROW, 159);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_minBars);

   PlotIndexSetInteger(2, PLOT_ARROW, 159);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 1);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_minBars);

   PlotIndexSetInteger(3, PLOT_ARROW, 159);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 1);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, g_minBars);

   PlotIndexSetInteger(4, PLOT_ARROW, 159);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 1);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, g_minBars);
}

void ConfigureChart()
{
   color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, bg);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, bg);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, bg);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, bg);
}

double ClampPct(double value)
{
   return MathMin(MathMax(value, 0.0), 100.0);
}

double ClampRange(double value, double low, double high)
{
   return MathMin(MathMax(value, low), high);
}

bool IsFreshBreakout(int idx)
{
   if(idx < 0 || idx >= ArraySize(workTrend))
      return false;
   if(workTrend[idx] == TREND_NONE)
      return false;
   if(workTrend[idx] != workPrevTrend[idx])
      return true;
   return (int)workTrendAge[idx] <= MathMax(1, InpEarlyWindowBars);
}

bool IsTrendBodyAligned(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(idx < 0 || trend == TREND_NONE)
      return false;

   double range = high[idx] - low[idx];
   if(range <= _Point)
      return false;

   double body = close[idx] - open[idx];
   double bodyRatio = MathAbs(body) / range;
   if(trend == TREND_BULL)
      return body > 0.0 && bodyRatio >= 0.28;
   return body < 0.0 && bodyRatio >= 0.28;
}

double CalcArrowPrice(int idx, bool isBuy, const double &high[], const double &low[])
{
   double atrOffset = tmpATR[idx] * g_effectiveArrowAtrOffset;
   double minOffset = (double)g_effectiveArrowMinPoints * _Point;
   double maxOffset = (g_effectiveArrowMaxPoints > 0) ? (double)g_effectiveArrowMaxPoints * _Point : atrOffset;
   double offset = MathMax(atrOffset, minOffset);
   if(g_effectiveArrowMaxPoints > 0)
      offset = MathMin(offset, maxOffset);

   if(isBuy) {
      double anchor = low[idx];
      if(idx < ArraySize(workFinalDn) && workFinalDn[idx] != EMPTY_VALUE)
         anchor = MathMin(anchor, workFinalDn[idx]);
      return anchor - offset;
   }

   double anchor = high[idx];
   if(idx < ArraySize(workFinalUp) && workFinalUp[idx] != EMPTY_VALUE)
      anchor = MathMax(anchor, workFinalUp[idx]);
   return anchor + offset;
}

double CalcGuideTargetPrice(double entryPrice, double stopPrice, double trend, double riskMultiple)
{
   double riskDistance = MathAbs(entryPrice - stopPrice);
   if(riskDistance <= _Point || trend == TREND_NONE || riskMultiple <= 0.0)
      return EMPTY_VALUE;

   if(trend == TREND_BULL)
      return entryPrice + (riskDistance * riskMultiple);

   return entryPrice - (riskDistance * riskMultiple);
}

double NormalizeStopSide(int idx, double entryPrice, double stopPrice, double trend)
{
   if(trend == TREND_NONE || entryPrice <= 0.0) return stopPrice;
   double atr = (idx >= 0 && idx < ArraySize(tmpATR) && tmpATR[idx] > _Point) ? tmpATR[idx] : 10.0 * _Point;
   double minGap = MathMax(atr * MathMax(InpStopAtrBuffer, 0.10), 10.0 * _Point);

   if(trend == TREND_BULL && stopPrice >= entryPrice)
      return entryPrice - minGap;
   if(trend == TREND_BEAR && stopPrice <= entryPrice)
      return entryPrice + minGap;

   return stopPrice;
}

double CalcFlowPressureLite(int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], int rates_total)
{
   double range = high[idx] - low[idx];
   if(range <= _Point)
      return 0.0;

   double closeLocation = (close[idx] - low[idx]) / range;
   double bodyRatio = MathAbs(close[idx] - open[idx]) / range;
   double direction = (close[idx] >= open[idx]) ? 1.0 : -1.0;

   double avgVol = 0.0;
   int volCount = 0;
   for(int j = idx; j < idx + g_effectiveFlowLookback && j < rates_total; j++) {
      avgVol += (double)tick_volume[j];
      volCount++;
   }
   double volRatio = 1.0;
   if(volCount > 0 && avgVol > 0.0)
      volRatio = (double)tick_volume[idx] / (avgVol / (double)volCount);
   volRatio = ClampRange(volRatio, 0.55, 1.55);

   double directionalClose = (closeLocation - 0.5) * 70.0;
   double directionalBody = direction * bodyRatio * 65.0;
   double result = (directionalClose + directionalBody) * volRatio;
   return ClampRange(result, -100.0, 100.0);
}

double CalcIntrabarMomentumLite(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], int rates_total)
{
   if(trend == TREND_NONE)
      return 0.0;

   double range = high[idx] - low[idx];
   if(range <= _Point)
      return 0.0;

   double dir = (trend == TREND_BULL) ? 1.0 : -1.0;
   double directionalBody = dir * (close[idx] - open[idx]) / range;
   double closeLocation = (trend == TREND_BULL) ? (close[idx] - low[idx]) / range : (high[idx] - close[idx]) / range;
   double rangeVsAtr = (tmpATR[idx] > _Point) ? range / (tmpATR[idx] + _Point) : 0.0;
   double closeDelta = 0.0;
   if(idx + 1 < rates_total && tmpATR[idx] > _Point)
      closeDelta = dir * (close[idx] - close[idx + 1]) / (tmpATR[idx] + _Point);

   double avgVol = 0.0;
   int volCount = 0;
   for(int j = idx; j < idx + 4 && j < rates_total; j++) {
      avgVol += (double)tick_volume[j];
      volCount++;
   }
   double volRatio = 1.0;
   if(volCount > 0 && avgVol > 0.0)
      volRatio = (double)tick_volume[idx] / (avgVol / (double)volCount);

   double momentum = MathMax(0.0, directionalBody) * 36.0 +
                     MathMax(0.0, closeLocation - 0.40) * 28.0 +
                     ClampRange(rangeVsAtr, 0.0, 1.6) * 12.0 +
                     ClampRange(closeDelta, 0.0, 1.8) * 14.0 +
                     ClampRange(volRatio - 0.8, 0.0, 1.5) * 7.0 +
                     ClampRange(MathAbs(workFlow[idx]) * 0.08, 0.0, 10.0);
   return ClampPct(momentum);
}

double CalcDirectionalEdgeLite(int idx, double trend)
{
   if(trend == TREND_NONE)
      return 0.0;

   double diEdge = 0.0;
   if(tmpDIPlus[idx] != EMPTY_VALUE && tmpDIMinus[idx] != EMPTY_VALUE) {
      diEdge = (trend == TREND_BULL) ? (tmpDIPlus[idx] - tmpDIMinus[idx]) : (tmpDIMinus[idx] - tmpDIPlus[idx]);
   }

   double macdEdge = 0.0;
   if(tmpMACDMain[idx] != EMPTY_VALUE && tmpMACDSignal[idx] != EMPTY_VALUE) {
      double hist = tmpMACDMain[idx] - tmpMACDSignal[idx];
      macdEdge = (trend == TREND_BULL) ? (hist * 90.0) : (-hist * 90.0);
   }

   double flowAligned = (trend == TREND_BULL) ? MathMax(0.0, workFlow[idx]) : MathMax(0.0, -workFlow[idx]);
   double edge = flowAligned * 0.45 + MathMax(0.0, diEdge) * 1.1 + MathMax(0.0, macdEdge) * 0.25;
   return ClampRange(edge, 0.0, 100.0);
}

double GetAlignedFlowLite(int idx, double trend)
{
   if(trend == TREND_NONE)
      return 0.0;
   return (trend == TREND_BULL) ? MathMax(0.0, workFlow[idx]) : MathMax(0.0, -workFlow[idx]);
}

double CalchealthLite(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[], int rates_total)
{
   if(trend == TREND_NONE)
      return 50.0;

   bool freshBreakout = IsFreshBreakout(idx);
   double ageNorm = freshBreakout ? 2.0 : 4.0;
   double health = 0.0;

   health += MathMin(workTrendAge[idx] / ageNorm, 1.0) * 18.0;

   if(tmpADXMain[idx] != EMPTY_VALUE)
      health += MathMin(tmpADXMain[idx] / 24.0, 1.0) * 18.0;
   else
      health += 9.0;

   if(tmpDIPlus[idx] != EMPTY_VALUE && tmpDIMinus[idx] != EMPTY_VALUE) {
      bool diAligned = (trend == TREND_BULL) ? (tmpDIPlus[idx] > tmpDIMinus[idx]) : (tmpDIMinus[idx] > tmpDIPlus[idx]);
      health += diAligned ? 16.0 : 4.0;
   } else {
      health += 8.0;
   }

   if(tmpMACDMain[idx] != EMPTY_VALUE && tmpMACDSignal[idx] != EMPTY_VALUE) {
      double hist = tmpMACDMain[idx] - tmpMACDSignal[idx];
      bool macdAligned = (trend == TREND_BULL) ? (hist > 0.0) : (hist < 0.0);
      health += macdAligned ? 14.0 : 4.0;
   } else {
      health += 7.0;
   }

   if(tmpRSI[idx] != EMPTY_VALUE) {
      bool rsiAligned = (trend == TREND_BULL) ? (tmpRSI[idx] >= 52.0) : (tmpRSI[idx] <= 48.0);
      health += rsiAligned ? 10.0 : 3.0;
   } else {
      health += 6.0;
   }

   if(IsTrendBodyAligned(idx, trend, open, high, low, close))
      health += 10.0;

   health += MathMin((trend == TREND_BULL ? MathMax(0.0, workFlow[idx]) : MathMax(0.0, -workFlow[idx])) * 0.15, 8.0);
   health += MathMin(workMomentum[idx] * 0.15, 8.0);

   if(freshBreakout)
      health += g_effectiveFastBreakoutBonus;

   return ClampPct(health);
}

double CalcExhaustionLite(int idx, double trend, const long &tick_volume[], int rates_total)
{
   if(trend == TREND_NONE)
      return 0.0;

   double exh = 0.0;

   if(tmpRSI[idx] != EMPTY_VALUE) {
      if(trend == TREND_BULL && tmpRSI[idx] > 76.0)
         exh += MathMin((tmpRSI[idx] - 76.0) / 20.0, 1.0) * 28.0;
      else if(trend == TREND_BEAR && tmpRSI[idx] < 24.0)
         exh += MathMin((24.0 - tmpRSI[idx]) / 20.0, 1.0) * 28.0;
   }

   if(idx + 1 < rates_total && tmpMACDMain[idx] != EMPTY_VALUE && tmpMACDSignal[idx] != EMPTY_VALUE &&
      tmpMACDMain[idx + 1] != EMPTY_VALUE && tmpMACDSignal[idx + 1] != EMPTY_VALUE) {
      double hist = tmpMACDMain[idx] - tmpMACDSignal[idx];
      double prevHist = tmpMACDMain[idx + 1] - tmpMACDSignal[idx + 1];
      if(trend == TREND_BULL && hist > 0.0 && hist < prevHist)
         exh += 18.0;
      else if(trend == TREND_BEAR && hist < 0.0 && hist > prevHist)
         exh += 18.0;
   }

   double avgVol = 0.0;
   int volCount = 0;
   for(int j = idx; j < idx + 8 && j < rates_total; j++) {
      avgVol += (double)tick_volume[j];
      volCount++;
   }
   if(volCount > 0 && avgVol > 0.0) {
      double volMA = avgVol / (double)volCount;
      if((double)tick_volume[idx] < volMA * 0.65)
         exh += 12.0;
   }

   if(trend == TREND_BULL && workFlow[idx] < -18.0)
      exh += 18.0;
   else if(trend == TREND_BEAR && workFlow[idx] > 18.0)
      exh += 18.0;

   return ClampPct(exh);
}

int DetectRegimeLite(int idx, const double &close[], int rates_total)
{
   int lookback = MathMin(g_effectiveRegimeLookback, rates_total - idx - 1);
   if(lookback < 3)
      return REGIME_RANGING;

   double adx = (tmpADXMain[idx] != EMPTY_VALUE) ? tmpADXMain[idx] : 18.0;

   double avgATR = 0.0;
   int atrEnd = MathMin(idx + lookback, ArraySize(tmpATR));
   for(int j = idx; j < atrEnd; j++)
      avgATR += tmpATR[j];
   avgATR /= (double)lookback;
   double atrRatio = (avgATR > 0.0) ? tmpATR[idx] / avgATR : 1.0;

   int votes = 0;
   for(int j = idx; j < idx + MathMin(lookback, 4) && j + 1 < rates_total; j++) {
      if(close[j] > close[j + 1]) votes++;
      else if(close[j] < close[j + 1]) votes--;
   }

   bool freshBreakout = IsFreshBreakout(idx) && IsTrendBodyAligned(idx, workTrend[idx], bufOpen, bufHigh, bufLow, bufClose);
   if(freshBreakout && adx >= 18.0 && MathAbs(votes) >= 2 && atrRatio < 1.78)
      return REGIME_TRENDING;
   if(adx >= 22.0 && MathAbs(votes) >= 3 && atrRatio < 1.58)
      return REGIME_TRENDING;
   if(atrRatio > 1.80)
      return REGIME_VOLATILE;
   return REGIME_RANGING;
}

double CalcConfirmedScoreLite(int idx, double trend, int regime)
{
   if(trend == TREND_NONE)
      return 0.0;

   double flowAligned = GetAlignedFlowLite(idx, trend);
   double dirEdge = CalcDirectionalEdgeLite(idx, trend);
   double regimeBonus = (regime == REGIME_TRENDING) ? 6.0 : (regime == REGIME_VOLATILE ? -4.0 : 0.0);
   bool bodyAligned = IsTrendBodyAligned(idx, trend, bufOpen, bufHigh, bufLow, bufClose);
   bool impulseClose = bodyAligned && flowAligned >= 26.0 && workMomentum[idx] >= g_effectiveWatchMomentumThreshold + 4.0;
   double score = workHealth[idx] * 0.40 + flowAligned * 0.20 + workMomentum[idx] * 0.16 + dirEdge * 0.18 + regimeBonus;
   if(bodyAligned)
      score += 4.0;
   if(impulseClose)
      score += 5.0;
   if(IsFreshBreakout(idx) && bodyAligned)
      score += 4.0;
   return ClampPct(score);
}

double CalcGoldConfirmedScore(int idx, double trend, int regime, double sweepDepth, double roundScore, double cycleBias, double sessionMult, double dxyBias, double momentumMult)
{
   if(trend == TREND_NONE)
      return 0.0;

   double baseScore = CalcConfirmedScoreLite(idx, trend, regime);
   double goldScore = baseScore;

   if(InpUseSweepDetection && sweepDepth > 0.0)
      goldScore += MathMin(sweepDepth * 8.0, InpSweepGradeBonus);

   if(InpUseRoundNumbers)
      goldScore += roundScore;

   if(InpUseATRCycle)
      goldScore += cycleBias;

   {
      double range = bufHigh[idx] - bufLow[idx];
      if(range > _Point) {
         double bodyH = MathMax(bufOpen[idx], bufClose[idx]);
         double bodyL = MathMin(bufOpen[idx], bufClose[idx]);
         double upperWick = bufHigh[idx] - bodyH;
         double lowerWick = bodyL - bufLow[idx];
         if(trend == TREND_BULL && upperWick > range * 0.40)
            goldScore -= 8.0;
         else if(trend == TREND_BEAR && lowerWick > range * 0.40)
            goldScore -= 8.0;
      }
   }

   if(InpUseDXYFilter && g_dxyAvailable)
      goldScore += dxyBias * 0.12;

   if(InpUseSessionEngine && MathAbs(momentumMult - 1.0) > 0.01)
      goldScore += workMomentum[idx] * 0.16 * (1.0 / momentumMult - 1.0);

   if(sessionMult > 0.01)
      goldScore /= sessionMult;
   goldScore = ClampPct(goldScore);
   return goldScore;
}

double CalcLiveScoreLite(int idx, double trend, int regime)
{
   if(trend == TREND_NONE)
      return 0.0;

   double alignedFlow = GetAlignedFlowLite(idx, trend);
   double live = workConfirmedScore[idx] * 0.52 + workMomentum[idx] * 0.34 + alignedFlow * 0.14;
   if(IsTrendBodyAligned(idx, trend, bufOpen, bufHigh, bufLow, bufClose))
      live += 6.0;
   if(IsFreshBreakout(idx))
      live += g_effectiveLiveBoost;
   if(regime == REGIME_TRENDING)
      live += 2.0;
   else if(regime == REGIME_VOLATILE)
      live -= 4.0;
   return ClampPct(live);
}

double CalcGoldLiveScore(int idx, double trend, int regime, double sweepDepth, double roundScore, double cycleBias, double sessionMult, double dxyBias, double momentumMult)
{
   if(trend == TREND_NONE)
      return 0.0;

   double baseLive = CalcLiveScoreLite(idx, trend, regime);
   double goldLive = baseLive;

   if(InpUseSweepDetection && sweepDepth > 0.0)
      goldLive += MathMin(sweepDepth * 6.0, InpSweepGradeBonus * 0.7);

   if(InpUseRoundNumbers)
      goldLive += roundScore * 0.7;

   if(InpUseATRCycle)
      goldLive += cycleBias * 0.7;

   {
      double range = bufHigh[idx] - bufLow[idx];
      if(range > _Point) {
         double bodyH = MathMax(bufOpen[idx], bufClose[idx]);
         double bodyL = MathMin(bufOpen[idx], bufClose[idx]);
         double upperWick = bufHigh[idx] - bodyH;
         double lowerWick = bodyL - bufLow[idx];
         if(trend == TREND_BULL && upperWick > range * 0.40)
            goldLive -= 6.0;
         else if(trend == TREND_BEAR && lowerWick > range * 0.40)
            goldLive -= 6.0;
      }
   }

   if(InpUseDXYFilter && g_dxyAvailable)
      goldLive += dxyBias * 0.08;

   if(InpUseSessionEngine && MathAbs(momentumMult - 1.0) > 0.01)
      goldLive += workMomentum[idx] * 0.34 * (1.0 / momentumMult - 1.0);

   if(sessionMult > 0.01)
      goldLive /= sessionMult;
   goldLive = ClampPct(goldLive);
   return goldLive;
}

bool IsWatchSignal(int idx, double trend, double &dirEdge)
{
   dirEdge = 0.0;
   if(idx != 0 || trend == TREND_NONE)
      return false;

   dirEdge = CalcDirectionalEdgeLite(idx, trend);
   bool fresh = IsFreshBreakout(idx);
   bool impulseReady = workMomentum[idx] >= g_goldMomentumFloor + 8.0;

   if(workExhaustion[idx] >= g_effectiveExhaustionBlock - 6.0) return false;
   if(workHealth[idx] < g_goldHealthFloor) return false;
   if(workMomentum[idx] < g_goldMomentumFloor) return false;
   if(workLiveScore[idx] < g_goldWatchThreshold) return false;
   if(dirEdge < 18.0) return false;
   if(!IsTrendBodyAligned(idx, trend, bufOpen, bufHigh, bufLow, bufClose)) return false;
   if(!fresh && !impulseReady) return false;

   return true;
}

bool IsFastConfirmedImpulse(int idx, double trend, double dirEdge)
{
   if(idx <= 0 || trend == TREND_NONE)
      return false;

   double alignedFlow = GetAlignedFlowLite(idx, trend);
   bool bodyAligned = IsTrendBodyAligned(idx, trend, bufOpen, bufHigh, bufLow, bufClose);
   bool fresh = IsFreshBreakout(idx);
   bool regimeReady = ((int)workRegime[idx] == REGIME_TRENDING) || fresh || (workTrendAge[idx] <= (double)(InpEarlyWindowBars + 1));
   bool momentumReady = workMomentum[idx] >= MathMax(g_goldMomentumFloor + 4.0, 48.0);
   bool scoreReady = workConfirmedScore[idx] >= MathMax(g_goldConfirmedThreshold - 6.0, 52.0);
   bool liveReady = workLiveScore[idx] >= MathMax(g_goldWatchThreshold + 2.0, 54.0);
   bool healthReady = workHealth[idx] >= MathMax(g_goldHealthFloor - 6.0, 38.0);
   bool exhaustionReady = workExhaustion[idx] <= g_effectiveExhaustionBlock - 8.0;
   bool edgeReady = dirEdge >= 18.0;
   bool flowReady = alignedFlow >= 26.0;
   bool notVolatile = ((int)workRegime[idx] != REGIME_VOLATILE);
   bool closeContinuation = false;
   if(idx + 1 < ArraySize(bufClose))
      closeContinuation = (trend == TREND_BULL) ? (bufClose[idx] >= bufClose[idx + 1]) : (bufClose[idx] <= bufClose[idx + 1]);

   return bodyAligned && regimeReady && momentumReady && scoreReady && liveReady &&
          healthReady && exhaustionReady && edgeReady && flowReady && notVolatile && closeContinuation;
}

bool IsConfirmedSignal(int idx, double trend, double &dirEdge)
{
   dirEdge = 0.0;
   if(idx < 0 || trend == TREND_NONE)
      return false;

   dirEdge = CalcDirectionalEdgeLite(idx, trend);
   bool fresh = IsFreshBreakout(idx);
   bool risingScore = (idx + 1 < ArraySize(workConfirmedScore)) ? (workConfirmedScore[idx] >= workConfirmedScore[idx + 1] + 3.0) : false;
   bool fastImpulse = IsFastConfirmedImpulse(idx, trend, dirEdge);
   double minExhaustionBlock = fastImpulse ? (g_effectiveExhaustionBlock - 8.0) : g_effectiveExhaustionBlock;
   double minHealth = fastImpulse ? MathMax(g_goldHealthFloor - 6.0, 38.0) : g_goldHealthFloor;
   double minConfirmedScore = fastImpulse ? MathMax(g_goldConfirmedThreshold - 6.0, 52.0) : g_goldConfirmedThreshold;
   double minDirEdge = fastImpulse ? 18.0 : 22.0;

   if(workExhaustion[idx] >= minExhaustionBlock) return false;
   if(workHealth[idx] < minHealth) return false;
   if(workConfirmedScore[idx] < minConfirmedScore) return false;
   if(dirEdge < minDirEdge) return false;
   if(!IsTrendBodyAligned(idx, trend, bufOpen, bufHigh, bufLow, bufClose)) return false;
   if(!fresh && !(workTrendAge[idx] <= (double)(InpEarlyWindowBars + 1) && risingScore) && !fastImpulse) return false;

   bool isFreshFlip = ((int)workTrendAge[idx] == 1);
   if(!isFreshFlip && g_goldMinADX > 0.0 && tmpADXMain[idx] != EMPTY_VALUE && tmpADXMain[idx] < g_goldMinADX)
      return false;

   if(!isFreshFlip && InpSignalCooldownBars > 0) {
      int look = MathMin(InpSignalCooldownBars, ArraySize(bufConfirmedBuy) - idx - 1);
      for(int k = idx + 1; k <= idx + look; k++) {
         if(trend == TREND_BULL && bufConfirmedSell[k] != EMPTY_VALUE) return false;
         if(trend == TREND_BEAR && bufConfirmedBuy[k] != EMPTY_VALUE) return false;
      }
   }

   return true;
}

bool IsGoldConfirmedSignal(int idx, double trend, double &dirEdge, double goldScore, bool sessionBlocked, double sweepDepth, ENUM_ATR_CYCLE cycle)
{
   dirEdge = 0.0;
   if(idx < 0 || trend == TREND_NONE)
      return false;

   dirEdge = CalcDirectionalEdgeLite(idx, trend);

   if(InpUseATRCycle && cycle == CYCLE_CLIMAX)
      return false;

   if(idx >= 0 && idx < ArraySize(tmpATR) && tmpATR[idx] > _Point) {
      double atrSum = 0.0;
      int atrCnt = 0;
      int atrLook = MathMin(20, ArraySize(tmpATR) - idx - 1);
      for(int j = idx + 1; j <= idx + atrLook && j < ArraySize(tmpATR); j++) {
         if(tmpATR[j] > _Point) { atrSum += tmpATR[j]; atrCnt++; }
      }
      if(atrCnt >= 8 && tmpATR[idx] > (atrSum / atrCnt) * 2.8)
         return false;
   }

   if(InpUseSweepDetection && sweepDepth >= InpMinSweepDepthAtr * 1.5) {
      bool fresh = IsFreshBreakout(idx);
      double minSweepScore = MathMax(g_goldConfirmedThreshold - 12.0, 52.0);
      if(goldScore >= minSweepScore && workHealth[idx] >= g_goldHealthFloor - 6.0) {
         if(!sessionBlocked)
            return true;
      }
   }

   return IsConfirmedSignal(idx, trend, dirEdge);
}

double CalcSignalGrade(int idx, double trend, double dirEdge, double htBias)
{
   if(trend == TREND_NONE) return 0.0;
   double conf = workConfirmedScore[idx];
   double live = workLiveScore[idx];
   double mom  = workMomentum[idx];
   double hp   = workHealth[idx];
   double exh  = workExhaustion[idx];
   double flow = GetAlignedFlowLite(idx, trend);
   int regime  = (int)workRegime[idx];

   double grade = conf * 0.32 + live * 0.18 + mom * 0.16 + hp * 0.14 + dirEdge * 0.12 + flow * 0.08;
   if(regime == REGIME_TRENDING) grade += 4.0;
   else if(regime == REGIME_VOLATILE) grade -= 5.0;
   if(IsFreshBreakout(idx)) grade += 3.0;
   grade -= ClampRange(exh - 40.0, 0.0, 60.0) * 0.18;
   grade += htBias;
   return ClampPct(grade);
}

string GradeLetter(double grade)
{
   if(grade >= InpGradeSThreshold) return "S";
   if(grade >= InpGradeAThreshold) return "A";
   if(grade >= 65.0) return "B";
   if(grade >= 50.0) return "C";
   return "D";
}

color GradeColor(double grade)
{
   if(grade >= InpGradeSThreshold) return C'255,210,90';
   if(grade >= InpGradeAThreshold) return C'120,240,170';
   if(grade >= 65.0) return C'120,200,255';
   if(grade >= 50.0) return C'200,200,200';
   return C'180,120,120';
}

bool DetectDivergenceLite(int idx, double trend)
{
   if(trend == TREND_NONE) return false;
   int look = MathMax(InpDivergenceLookback, 6);
   int last = MathMin(idx + look, ArraySize(bufClose) - 1);
   if(last <= idx + 4) return false;

   if(trend == TREND_BULL) {
      double pHigh = bufHigh[idx];
      double rHigh = (tmpRSI[idx] != EMPTY_VALUE) ? tmpRSI[idx] : 50.0;
      double prevHigh = -1e10;
      double prevRsi = 0.0;
      for(int j = idx + 2; j <= last; j++) {
         if(bufHigh[j] > prevHigh) { prevHigh = bufHigh[j]; prevRsi = (tmpRSI[j] != EMPTY_VALUE) ? tmpRSI[j] : 50.0; }
      }
      if(prevHigh > 0 && pHigh > prevHigh && rHigh < prevRsi - 2.0)
         return true;
   } else {
      double pLow = bufLow[idx];
      double rLow = (tmpRSI[idx] != EMPTY_VALUE) ? tmpRSI[idx] : 50.0;
      double prevLow = 1e10;
      double prevRsi = 0.0;
      for(int j = idx + 2; j <= last; j++) {
         if(bufLow[j] < prevLow) { prevLow = bufLow[j]; prevRsi = (tmpRSI[j] != EMPTY_VALUE) ? tmpRSI[j] : 50.0; }
      }
      if(prevLow < 1e10 && pLow < prevLow && rLow > prevRsi + 2.0)
         return true;
   }
   return false;
}

double CalcSwingStop(int idx, double trend, const double &high[], const double &low[])
{
   int n = MathMax(InpSwingLookback, 2);
   int last = MathMin(idx + n, ArraySize(high) - 1);
   if(last <= idx) return (trend == TREND_BULL) ? workFinalDn[idx] : workFinalUp[idx];
   double buf = tmpATR[idx] * MathMax(InpStopAtrBuffer, 0.0);
   if(trend == TREND_BULL) {
      double swingLow = low[idx];
      for(int j = idx; j <= last; j++) if(low[j] < swingLow) swingLow = low[j];
      double stop = swingLow - buf;
      double bandStop = workFinalDn[idx];
      if(bandStop != EMPTY_VALUE && stop < bandStop - tmpATR[idx] * 1.6)
         stop = bandStop - tmpATR[idx] * 1.6;
      return stop;
   } else {
      double swingHi = high[idx];
      for(int j = idx; j <= last; j++) if(high[j] > swingHi) swingHi = high[j];
      double stop = swingHi + buf;
      double bandStop = workFinalUp[idx];
      if(bandStop != EMPTY_VALUE && stop > bandStop + tmpATR[idx] * 1.6)
         stop = bandStop + tmpATR[idx] * 1.6;
      return stop;
   }
}

double CalcAdaptiveTp2(double entry, double stop, double trend, double atr)
{
   double risk = MathAbs(entry - stop);
   if(risk <= _Point || trend == TREND_NONE) return EMPTY_VALUE;
   double rrTp2 = risk * MathMax(InpTp2RiskMultiple, 1.5);
   double atrTp2 = atr * MathMax(InpTp2AtrFactor, 1.5);
   double dist = InpUseAdaptiveTp ? MathMax(rrTp2, atrTp2) : rrTp2;
   return (trend == TREND_BULL) ? entry + dist : entry - dist;
}

ENUM_GOLD_SESSION DetectGoldSession(datetime serverTime)
{
   if(serverTime == g_cacheSessionTime && g_cacheSessionTime > 0 && (int)g_cacheSession >= 0 && (int)g_cacheSession <= 6)
      return g_cacheSession;

   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int hour = dt.hour;

   ENUM_GOLD_SESSION sess;
   if(hour >= 0 && hour < 8)
      sess = SESSION_ASIA;
   else if(hour >= 8 && hour < 9)
      sess = SESSION_LONDON_PRE;
   else if(hour >= 9 && hour < 12)
      sess = SESSION_LONDON_OPEN;
   else if(hour >= 12 && hour < 14)
      sess = SESSION_LONDON_MID;
   else if(hour >= 14 && hour < 16)
      sess = SESSION_NY_OPEN;
   else if(hour >= 16 && hour < 19)
      sess = SESSION_NY_PM;
   else
      sess = SESSION_DEAD;

   g_cacheSession = sess;
   g_cacheSessionTime = serverTime;
   return sess;
}

SessionParams GetSessionParams(ENUM_GOLD_SESSION session)
{
   SessionParams sp;
   sp.thresholdMult = 1.0;
   sp.atrFloor = 10.0;
   sp.momentumMult = 1.0;
   sp.suppressFire = false;
   sp.killzoneWeight = 0.0;

   switch(session) {
      case SESSION_ASIA:
         sp.thresholdMult = InpAsiaThresholdMult;
         sp.suppressFire = InpFilterAsiaSignals;
         sp.atrFloor = 30.0;
         sp.momentumMult = 1.20;
         break;
      case SESSION_LONDON_PRE:
         sp.thresholdMult = InpLondonThresholdMult * 0.95;
         sp.killzoneWeight = 0.7;
         sp.momentumMult = 0.88;
         break;
      case SESSION_LONDON_OPEN:
         sp.thresholdMult = InpLondonThresholdMult;
         sp.killzoneWeight = 1.0;
         sp.momentumMult = 0.82;
         break;
      case SESSION_LONDON_MID:
         sp.thresholdMult = 1.02;
         sp.momentumMult = 0.98;
         break;
      case SESSION_NY_OPEN:
         sp.thresholdMult = InpNYThresholdMult;
         sp.killzoneWeight = 0.7;
         sp.momentumMult = 0.95;
         break;
      case SESSION_NY_PM:
         sp.thresholdMult = InpNYThresholdMult * 0.92;
         sp.momentumMult = 1.08;
         break;
      default:
         sp.thresholdMult = 1.35;
         sp.suppressFire = false;
         sp.momentumMult = 1.12;
         break;
   }
   return sp;
}

bool DetectLiquiditySweep(int idx, double trend, double &sweepDepth, int &sweepBarsAgo)
{
   sweepDepth = 0.0;
   sweepBarsAgo = -1;
   if(idx <= 0 || trend == TREND_NONE) return false;

   int look = InpSweepLookback;
   double atr = (tmpATR[idx] > _Point) ? tmpATR[idx] : 10.0 * _Point;

   if(trend == TREND_BULL) {
      double swingLow = 1e10;
      int swingLowIdx = -1;
      int endJ = MathMin(idx + look, ArraySize(bufLow) - 1);
      for(int j = idx + 1; j <= endJ; j++) {
         if(j + 2 < ArraySize(bufLow) && j - 1 > 0) {
            if(bufLow[j] < bufLow[j-1] && bufLow[j] < bufLow[j+1] && bufLow[j] < bufLow[j+2]) {
               if(bufLow[j] < swingLow) { swingLow = bufLow[j]; swingLowIdx = j; }
            }
         }
      }
      if(swingLowIdx < 0) return false;

      if(bufLow[idx] >= swingLow - atr * InpMinSweepDepthAtr) return false;
      if(bufLow[idx] >= swingLow) return false;
      if(bufClose[idx] <= swingLow + atr * InpSweepRetraceRatio) return false;

      sweepDepth = (swingLow - bufLow[idx]) / atr;
      sweepBarsAgo = swingLowIdx - idx;
   } else {
      double swingHigh = -1e10;
      int swingHighIdx = -1;
      int endJ = MathMin(idx + look, ArraySize(bufHigh) - 1);
      for(int j = idx + 1; j <= endJ; j++) {
         if(j + 2 < ArraySize(bufHigh) && j - 1 > 0) {
            if(bufHigh[j] > bufHigh[j-1] && bufHigh[j] > bufHigh[j+1] && bufHigh[j] > bufHigh[j+2]) {
               if(bufHigh[j] > swingHigh) { swingHigh = bufHigh[j]; swingHighIdx = j; }
            }
         }
      }
      if(swingHighIdx < 0) return false;

      if(bufHigh[idx] <= swingHigh + atr * InpMinSweepDepthAtr) return false;
      if(bufHigh[idx] <= swingHigh) return false;
      if(bufClose[idx] >= swingHigh - atr * InpSweepRetraceRatio) return false;

      sweepDepth = (bufHigh[idx] - swingHigh) / atr;
      sweepBarsAgo = swingHighIdx - idx;
   }

   return true;
}

bool InitDXYFilter()
{
   if(!InpUseDXYFilter) return false;
   g_dxyAvailable = false;

   SymbolSelect(InpDXYSymbol, true);
   double testPrice = SymbolInfoDouble(InpDXYSymbol, SYMBOL_BID);
   if(testPrice <= 0.0) {
      testPrice = SymbolInfoDouble(InpDXYSymbol, SYMBOL_LAST);
      if(testPrice <= 0.0) {
         Print("AurumPulse: Cannot access DXY symbol '", InpDXYSymbol, "'. Ensure symbol exists in Market Watch.");
         return false;
      }
   }

   g_dxyAvailable = true;
   return true;
}

double GetDXYBias(int idx, double trend)
{
   if(!g_dxyAvailable || idx < 0 || trend == TREND_NONE) return 0.0;
   if(idx >= ArraySize(g_dxyCloseCache) || idx + 1 >= ArraySize(g_dxyCloseCache)) return 0.0;

   double dxyNow  = g_dxyCloseCache[idx];
   double dxyPrev = g_dxyCloseCache[idx + 1];
   if(dxyNow <= 0.0 || dxyPrev <= 0.0) return 0.0;

   double dxyDelta = (dxyNow - dxyPrev) / (dxyPrev + _Point);

   double corr = (idx < ArraySize(workDXYCorrelation)) ? workDXYCorrelation[idx] : 0.0;
   double weight = MathMin(MathAbs(corr), 1.0);
   if(corr > InpDXYMinInvCorr) weight *= 0.5;

   if(trend == TREND_BULL) {
      if(dxyDelta < -0.0002) return +12.0 * weight;
      if(dxyDelta > 0.0002)  return -18.0 * weight;
      return -5.0 * weight;
   } else {
      if(dxyDelta > 0.0002)  return +12.0 * weight;
      if(dxyDelta < -0.0002) return -18.0 * weight;
      return -5.0 * weight;
   }
}

double CalcRollingDXYCorrelation(int idx, int lookback, int rates_total)
{
   if(!g_dxyAvailable || idx + lookback >= rates_total) return 0.0;

   double sumXY = 0, sumX = 0, sumY = 0, sumX2 = 0, sumY2 = 0;
   int n = 0;

   for(int j = idx; j < idx + lookback && j < rates_total && j + 1 < rates_total; j++) {
      double goldDenom = bufClose[j+1] + _Point;
      double dxyDenom  = g_dxyCloseCache[j+1] + _Point;
      if(goldDenom <= _Point || dxyDenom <= _Point) continue;
      double goldRet = (bufClose[j] - bufClose[j+1]) / goldDenom;
      double dxyRet  = (g_dxyCloseCache[j] - g_dxyCloseCache[j+1]) / dxyDenom;
      sumX  += goldRet;   sumY  += dxyRet;
      sumX2 += goldRet * goldRet;
      sumY2 += dxyRet  * dxyRet;
      sumXY += goldRet * dxyRet;
      n++;
   }

   if(n < 5) return 0.0;

   double denom = MathSqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
   if(MathAbs(denom) < 1e-12) return 0.0;

   return (n * sumXY - sumX * sumY) / denom;
}

double CalcRoundNumberProximity(double price, int idx, ENUM_ATR_CYCLE cycle)
{
   if(InpRoundNumberInterval <= 0.0) return 0.0;

   if(InpUseATRCycle && cycle == CYCLE_CLIMAX)
      return 0.0;

   double nearest = MathRound(price / InpRoundNumberInterval) * InpRoundNumberInterval;
   double distAbs = MathAbs(price - nearest);
   if(nearest <= 0.0) return 0.0;
   double distPct = (distAbs / nearest) * 100.0;

   double score = 0.0;

   if(distPct < InpRoundCriticalDistPct) {
      score = 8.0;
      bool trendUp = (idx < ArraySize(workTrend)) ? (workTrend[idx] == TREND_BULL) : false;
      if(idx + 2 < ArraySize(bufClose)) {
         bool wasBelow = (bufClose[idx+1] < nearest && bufClose[idx+2] < nearest);
         bool nowAbove = (price > nearest);
         if(wasBelow && nowAbove && trendUp)
            score += InpRoundRetestBonus;
         bool wasAbove = (bufClose[idx+1] > nearest && bufClose[idx+2] > nearest);
         bool nowBelow = (price < nearest);
         if(wasAbove && nowBelow && !trendUp)
            score += InpRoundRetestBonus;
      }
   }
   else if(distPct < InpRoundReactionDistPct)
      score = 4.0;
   else if(distPct < InpRoundWatchDistPct)
      score = 2.0;
   else
      score = 0.0;

   return score;
}

ENUM_ATR_CYCLE DetectATRCycle(int idx)
{
   if(idx + InpATRCycleMALength + 1 >= ArraySize(tmpATR)) return CYCLE_NORMAL;

   double atrNow = tmpATR[idx];
   if(atrNow <= _Point) return CYCLE_NORMAL;

   double sumATR = 0.0;
   int count = 0;
   for(int j = idx; j < idx + InpATRCycleMALength && j < ArraySize(tmpATR); j++) {
      if(tmpATR[j] > _Point) {
         sumATR += tmpATR[j];
         count++;
      }
   }
   if(count < 6) return CYCLE_NORMAL;

   double atrMA = sumATR / (double)count;
   double ratio = atrNow / atrMA;

   if(ratio < InpATRCompressionRatio) return CYCLE_COMPRESSION;
   if(ratio > InpATRClimaxRatio) return CYCLE_CLIMAX;
   if(ratio > InpATRExpansionRatio) return CYCLE_EXPANSION;
   return CYCLE_NORMAL;
}

double GetCycleBias(ENUM_ATR_CYCLE cycle)
{
   switch(cycle) {
      case CYCLE_COMPRESSION: return InpCompressionEntryBonus;
      case CYCLE_EXPANSION:   return 4.0;
      case CYCLE_CLIMAX:      return -15.0;
      default:                return 0.0;
   }
}

bool InitTrendFilter()
{
   if(g_tfMode == FILTER_OFF) return true;

   if(InpTrendFilterTF < PERIOD_CURRENT) {
      Print("AurumPulse: TrendFilterTF < chart TF, overriding to PERIOD_CURRENT");
   }
   ENUM_TIMEFRAMES tf = (InpTrendFilterTF >= PERIOD_CURRENT) ? InpTrendFilterTF : PERIOD_CURRENT;

   hTF_ATR = iATR(_Symbol, tf, (int)g_tfAtrPeriod);
   if(hTF_ATR == INVALID_HANDLE) {
      Print("AurumPulse: Failed to init HTF ATR handle");
      return false;
   }
   return true;
}

void CalcHTFSupertrend(int i, int oldest, const double &close[], int rates_total)
{
   double atrVal = (i < ArraySize(tmpTF_ATR) && tmpTF_ATR[i] > _Point) ? tmpTF_ATR[i]
                   : ((i < ArraySize(tmpATR) && tmpATR[i] > _Point) ? tmpATR[i] : 10.0 * _Point);
   double htfClose = close[i];

   double mid   = (htfClose + htfClose + htfClose + htfClose) / 4.0;
   double bandUp = mid + atrVal * g_tfMult;
   double bandDn = mid - atrVal * g_tfMult;

   if(i == oldest) {
      workHTFFinalUp[i] = bandUp;
      workHTFFinalDn[i] = bandDn;
      workHTFTrend[i]   = (htfClose >= mid) ? TREND_BULL : TREND_BEAR;
      workHTFPrevTrend[i] = TREND_NONE;
      workHTFTrendAge[i]  = 1.0;
   } else {
      int p = i + 1;
      if(p >= ArraySize(workHTFFinalUp)) return;

      workHTFFinalUp[i] = (bandUp < workHTFFinalUp[p] || close[p] > workHTFFinalUp[p])
                          ? bandUp : workHTFFinalUp[p];
      workHTFFinalDn[i] = (bandDn > workHTFFinalDn[p] || close[p] < workHTFFinalDn[p])
                          ? bandDn : workHTFFinalDn[p];
      workHTFPrevTrend[i] = workHTFTrend[p];

      if(workHTFTrend[p] == TREND_BEAR)
         workHTFTrend[i] = (htfClose > workHTFFinalUp[i]) ? TREND_BULL : TREND_BEAR;
      else
         workHTFTrend[i] = (htfClose < workHTFFinalDn[i]) ? TREND_BEAR : TREND_BULL;

      workHTFTrendAge[i] = (workHTFTrend[i] == workHTFTrend[p])
                           ? workHTFTrendAge[p] + 1.0 : 1.0;
   }
}

bool IsSignalAligned(double localTrend, double htTrend)
{
   if(localTrend == TREND_NONE || htTrend == TREND_NONE)
      return false;
   return (localTrend == htTrend);
}

double GetHTFBiasScore(int idx, double localTrend)
{
   if(idx < 0 || idx >= ArraySize(workHTFTrend)) return 0.0;
   if(workHTFTrend[idx] == TREND_NONE) return 0.0;

   bool aligned = IsSignalAligned(localTrend, workHTFTrend[idx]);
   bool newFlip = (idx < ArraySize(workHTFTrendAge) && (int)workHTFTrendAge[idx] < 3);

   if(aligned && newFlip)  return +8.0;
   if(aligned)             return +5.0;
   return -15.0;
}

string GetHTFContextString(int idx)
{
   if(g_tfMode == FILTER_OFF)
      return "";

   if(idx < 0 || idx >= ArraySize(workHTFTrend)) return "";

   double htTrend = workHTFTrend[idx];
   if(htTrend == TREND_NONE)
      return "";

   bool isAligned = (idx < ArraySize(workTrend)) ? IsSignalAligned(workTrend[idx], htTrend) : false;
   string arrow   = (htTrend == TREND_BULL) ? "▲" : "▼";
   string suffix  = isAligned ? "" : " ⚠";
   return StringFormat("%s%s", arrow, suffix);
}

void DrawHTFTrendRow(int x, int &y, int w, int maxChars)
{
   if(g_tfMode == FILTER_OFF) return;

   double htTrend = (ArraySize(workHTFTrend) > 0) ? workHTFTrend[0] : TREND_NONE;
   if(htTrend == TREND_NONE) return;

   string htDir     = (htTrend == TREND_BULL) ? "BULL" : "BEAR";
   string htArrow   = (htTrend == TREND_BULL) ? "▲" : "▼";
   color  htClr     = (htTrend == TREND_BULL) ? InpThemeBullish : InpThemeBearish;
   double htAge     = (ArraySize(workHTFTrendAge) > 0) ? workHTFTrendAge[0] : 0.0;
   double htBias    = (workTrend[0] != TREND_NONE) ? GetHTFBiasScore(0, workTrend[0]) : 0.0;
   string biasStr   = (workTrend[0] != TREND_NONE) ? StringFormat("%+.0f", htBias) : "--";

   string rowText = StringFormat("  %s TREND  %s %s  (%d bars)  bias [%s]",
      TFToStr(InpTrendFilterTF >= PERIOD_CURRENT ? InpTrendFilterTF : PERIOD_CURRENT),
      htArrow, htDir, (int)htAge, biasStr);

   MakeLabel("AU_DB_HTF", x, y, FitText(rowText, maxChars), 9, htClr);
   y += 18;
}

bool IsPivotReversal(int idx, double trend, const double &open[], const double &high[], const double &low[], const double &close[], int rates_total)
{
   if(!InpEarlyReversalMode) return false;
   if(idx <= 0 || idx + 2 >= rates_total) return false;
   if(trend == TREND_NONE) return false;
   if((int)workTrendAge[idx] != 1) return false;
   if(workPrevTrend[idx] == TREND_NONE) return false;
   if(workPrevTrend[idx] == trend) return false;

   double range = high[idx] - low[idx];
   if(range <= _Point) return false;
   double atr = tmpATR[idx];
   if(atr <= _Point) return false;
   double rangeAtr = range / atr;

   double body      = close[idx] - open[idx];
   double bodyRatio = MathAbs(body) / range;
   double upperWick = high[idx] - MathMax(open[idx], close[idx]);
   double lowerWick = MathMin(open[idx], close[idx]) - low[idx];
   double upWickR   = upperWick / range;
   double dnWickR   = lowerWick / range;
   double closeLoc  = (trend == TREND_BULL)
      ? (close[idx] - low[idx]) / range
      : (high[idx] - close[idx]) / range;

   bool dirOk = (trend == TREND_BULL) ? (body > 0.0) : (body < 0.0);
   bool impulseOk = dirOk
                    && bodyRatio >= InpReversalBodyRatio
                    && rangeAtr  >= InpReversalRangeAtr
                    && closeLoc  >= 0.50;

   bool pinOk = false;
   if(trend == TREND_BULL)
      pinOk = (dnWickR >= InpReversalWickRatio) && (closeLoc >= 0.45) && (rangeAtr >= 0.40);
   else
      pinOk = (upWickR >= InpReversalWickRatio) && (closeLoc >= 0.45) && (rangeAtr >= 0.40);

   if(!impulseOk && !pinOk) return false;

   if(workExhaustion[idx] >= InpReversalMaxExh) return false;

   return true;
}

int FindPivotCandleBack(int flipIdx, double newTrend, const double &open[], const double &high[], const double &low[], const double &close[], int rates_total)
{
   if(InpReversalBackScan <= 0) return -1;
   if(flipIdx + InpReversalBackScan >= rates_total) return -1;

   int bestIdx = -1;
   double bestScore = 0.0;

   for(int k = 0; k <= InpReversalBackScan; k++) {
      int j = flipIdx + k;
      if(j <= 0 || j >= rates_total - 1) continue;

      double range = high[j] - low[j];
      if(range <= _Point) continue;
      double atr = tmpATR[j];
      if(atr <= _Point) continue;
      double rangeAtr = range / atr;
      if(rangeAtr < 0.40) continue;

      double wick = (newTrend == TREND_BULL)
         ? (MathMin(open[j], close[j]) - low[j])
         : (high[j] - MathMax(open[j], close[j]));
      double wickR = wick / range;

      bool isExtreme = true;
      for(int m = 1; m <= 3; m++) {
         if(j + m < rates_total) {
            if(newTrend == TREND_BULL && low[j]  >  low[j + m])  { isExtreme = false; break; }
            if(newTrend == TREND_BEAR && high[j] <  high[j + m]) { isExtreme = false; break; }
         }
         if(j - m > 0) {
            if(newTrend == TREND_BULL && low[j]  >  low[j - m])  { isExtreme = false; break; }
            if(newTrend == TREND_BEAR && high[j] <  high[j - m]) { isExtreme = false; break; }
         }
      }
      if(!isExtreme) continue;

      double depth = 0.0;
      double cmpRef = (newTrend == TREND_BULL) ? 1e10 : -1e10;
      for(int dn = 1; dn <= 3; dn++) {
         int jn = j - dn;
         if(jn < 0) break;
         if(newTrend == TREND_BULL) cmpRef = MathMin(cmpRef, low[jn]);
         else                       cmpRef = MathMax(cmpRef, high[jn]);
      }
      if(cmpRef != 1e10 && cmpRef != -1e10) {
         depth = (newTrend == TREND_BULL) ? (cmpRef - low[j]) / atr
                                          : (high[j] - cmpRef) / atr;
         if(depth < 0.0) depth = 0.0;
      }
      double score = depth * 45.0 + rangeAtr * 20.0 + wickR * 25.0;
      if(score > bestScore) { bestScore = score; bestIdx = j; }
   }

   return bestIdx;
}

void ResetTradeTracker()
{
   g_tracker.active = false;
   g_tracker.trend = TREND_NONE;
   g_tracker.entry = 0.0;
   g_tracker.stop = 0.0;
   g_tracker.tp1 = 0.0;
   g_tracker.tp2 = 0.0;
   g_tracker.entryTime = 0;
   g_tracker.grade = "";
   g_tracker.tp1Hit = false;
   g_tracker.tp2Hit = false;
   g_tracker.stoppedOut = false;
   g_tracker.beActive = false;
   g_tracker.peakR = 0.0;
   g_tracker.currentR = 0.0;
   g_tracker.barsInTrade = 0;
}

void InitTradeTracker(int idx, double trend, double grade)
{
   if(!InpShowTradeTracker) return;
   g_tracker.active = true;
   g_tracker.trend = trend;
   g_tracker.entry = bufClose[idx];
   g_tracker.stop  = InpUseSwingStop ? CalcSwingStop(idx, trend, bufHigh, bufLow)
                                     : ((trend == TREND_BULL) ? workFinalDn[idx] : workFinalUp[idx]);
   g_tracker.stop = NormalizeStopSide(idx, g_tracker.entry, g_tracker.stop, trend);
   g_tracker.tp1 = CalcGuideTargetPrice(g_tracker.entry, g_tracker.stop, trend, InpTp1RiskMultiple);
   g_tracker.tp2 = CalcAdaptiveTp2(g_tracker.entry, g_tracker.stop, trend, tmpATR[idx]);
   g_tracker.entryTime = iTime(_Symbol, PERIOD_CURRENT, idx);
   g_tracker.grade = GradeLetter(grade);
   g_tracker.tp1Hit = false;
   g_tracker.tp2Hit = false;
   g_tracker.stoppedOut = false;
   g_tracker.beActive = false;
   g_tracker.peakR = 0.0;
   g_tracker.currentR = 0.0;
   g_tracker.barsInTrade = 0;
}

void UpdateTradeTracker(const double &high[], const double &low[], const double &close[])
{
   if(!g_tracker.active) return;
   double risk = MathAbs(g_tracker.entry - g_tracker.stop);
   if(risk <= _Point) { ResetTradeTracker(); return; }

   if(workTrend[0] != TREND_NONE && workTrend[0] != g_tracker.trend
      && !g_tracker.tp2Hit && !g_tracker.stoppedOut) {
      g_tracker.stoppedOut = true;
   }

   int barsAgo = 0;
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(g_tracker.entryTime > 0 && t0 >= g_tracker.entryTime) {
      int sec = PeriodSeconds();
      if(sec > 0) barsAgo = (int)((t0 - g_tracker.entryTime) / sec);
   }
   g_tracker.barsInTrade = barsAgo;

   double curPrice = close[0];
   if(g_tracker.trend == TREND_BULL) {
      g_tracker.currentR = (curPrice - g_tracker.entry) / risk;
      double peakHi = high[0];
      for(int b = 0; b <= MathMin(barsAgo, ArraySize(high) - 1); b++) if(high[b] > peakHi) peakHi = high[b];
      double pkR = (peakHi - g_tracker.entry) / risk;
      if(pkR > g_tracker.peakR) g_tracker.peakR = pkR;
      double effStop = g_tracker.beActive ? g_tracker.entry : g_tracker.stop;
      for(int b = 0; b <= MathMin(barsAgo, ArraySize(low) - 1); b++) {
         if(!g_tracker.tp1Hit && g_tracker.tp1 != EMPTY_VALUE && high[b] >= g_tracker.tp1) { g_tracker.tp1Hit = true; g_tracker.beActive = true; }
         if(!g_tracker.tp2Hit && g_tracker.tp2 != EMPTY_VALUE && high[b] >= g_tracker.tp2) g_tracker.tp2Hit = true;
         if(!g_tracker.stoppedOut && low[b] <= effStop) g_tracker.stoppedOut = true;
      }
   } else {
      g_tracker.currentR = (g_tracker.entry - curPrice) / risk;
      double peakLo = low[0];
      for(int b = 0; b <= MathMin(barsAgo, ArraySize(low) - 1); b++) if(low[b] < peakLo) peakLo = low[b];
      double pkR = (g_tracker.entry - peakLo) / risk;
      if(pkR > g_tracker.peakR) g_tracker.peakR = pkR;
      double effStop = g_tracker.beActive ? g_tracker.entry : g_tracker.stop;
      for(int b = 0; b <= MathMin(barsAgo, ArraySize(high) - 1); b++) {
         if(!g_tracker.tp1Hit && g_tracker.tp1 != EMPTY_VALUE && low[b] <= g_tracker.tp1) { g_tracker.tp1Hit = true; g_tracker.beActive = true; }
         if(!g_tracker.tp2Hit && g_tracker.tp2 != EMPTY_VALUE && low[b] <= g_tracker.tp2) g_tracker.tp2Hit = true;
         if(!g_tracker.stoppedOut && high[b] >= effStop) g_tracker.stoppedOut = true;
      }
   }

   if(g_tracker.tp2Hit || g_tracker.stoppedOut) {
      if(workTrend[0] != g_tracker.trend) ResetTradeTracker();
   }
}

string SessionToStr(ENUM_GOLD_SESSION session)
{
   switch(session) {
      case SESSION_ASIA:          return "ASIA";
      case SESSION_LONDON_PRE:    return "LONDON PRE";
      case SESSION_LONDON_OPEN:   return "LONDON OPEN";
      case SESSION_LONDON_MID:    return "LONDON MID";
      case SESSION_NY_OPEN:       return "NY OPEN";
      case SESSION_NY_PM:         return "NY PM";
      case SESSION_DEAD:          return "DEAD";
      default:                    return "UNKNOWN";
   }
}

color SessionColor(ENUM_GOLD_SESSION session)
{
   switch(session) {
      case SESSION_ASIA:          return C'120,130,150';
      case SESSION_LONDON_PRE:    return C'200,180,100';
      case SESSION_LONDON_OPEN:   return C'255,200,60';
      case SESSION_NY_OPEN:       return C'255,160,80';
      default:                    return C'140,150,170';
   }
}

string CycleToStr(ENUM_ATR_CYCLE cycle)
{
   switch(cycle) {
      case CYCLE_COMPRESSION: return "COMPRESSION";
      case CYCLE_NORMAL:      return "NORMAL";
      case CYCLE_EXPANSION:   return "EXPANSION";
      case CYCLE_CLIMAX:      return "CLIMAX";
      default:                return "UNKNOWN";
   }
}

color CycleColor(ENUM_ATR_CYCLE cycle)
{
   switch(cycle) {
      case CYCLE_COMPRESSION: return C'100,220,180';
      case CYCLE_NORMAL:      return C'160,180,210';
      case CYCLE_EXPANSION:   return C'255,180,100';
      case CYCLE_CLIMAX:      return C'255,100,120';
      default:                return C'150,150,150';
   }
}


void DrawGaugeBar(string base, int x, int y, int w, int h, double value, double maxV, color fill, color bg, color border)
{
   double pct = (maxV > 0.0) ? ClampRange(value / maxV, 0.0, 1.0) : 0.0;
   int fillW = (int)MathRound(pct * (double)(w - 2));
   UpsertTagBox(base + "_BG", x, y, w, h, bg, border);
   if(fillW > 0)
      UpsertTagBox(base + "_FG", x + 1, y + 1, fillW, h - 2, fill, fill);
   else
      ObjectDelete(0, base + "_FG");
}

void DeleteMomentumStrip()
{
   ObjectsDeleteAll(0, "AU_MS_");
}

void DrawMomentumStrip()
{
   if(!InpShowMomentumStrip) { DeleteMomentumStrip(); return; }
   int n = MathMin(InpMomentumStripBars, ArraySize(workMomentum) - 1);
   if(n < 4) return;
   int barW = 6;
   int gap = 1;
   int totalW = n * (barW + gap);
   int x0 = 16;
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int yBase = chartH - 28;
   int maxH = 36;

   UpsertTagBox("AU_MS_BG", x0 - 8, yBase - maxH - 14, totalW + 16, maxH + 22, C'14,18,28', C'40,52,80');
   UpsertTagLabel("AU_MS_LBL", x0 - 4, yBase + 4, "Momentum Strip", C'140,160,200', 7);

   for(int i = 0; i < n; i++) {
      double m = workMomentum[i];
      double tr = workTrend[i];
      int hPx = (int)MathRound(ClampPct(m) / 100.0 * (double)maxH);
      if(hPx < 1) hPx = 1;
      color clr = (tr == TREND_BULL) ? InpThemeBullish : ((tr == TREND_BEAR) ? InpThemeBearish : (color)C'120,120,140');
      string nm = StringFormat("AU_MS_B%d", i);
      UpsertTagBox(nm, x0 + (n - 1 - i) * (barW + gap), yBase - hPx, barW, hPx, clr, clr);
   }
   for(int j = n; j < n + 8; j++) ObjectDelete(0, StringFormat("AU_MS_B%d", j));
}

void DrawTradeTrackerPanel(int x, int y, int w)
{
   if(!InpShowTradeTracker || !g_tracker.active) {
      ObjectsDeleteAll(0, "AU_TT_");
      return;
   }
   int h = 86;
   color border = (g_tracker.trend == TREND_BULL) ? InpThemeBullish : InpThemeBearish;
   color bg = (g_tracker.trend == TREND_BULL) ? C'10,42,42' : C'48,18,28';
   UpsertTagBox("AU_TT_BG", x, y, w, h, bg, border);

   string statusLbl = "ACTIVE";
   color statusClr = C'180,240,200';
   if(g_tracker.stoppedOut) { statusLbl = "STOPPED"; statusClr = C'255,140,150'; }
   else if(g_tracker.tp2Hit) { statusLbl = "TP2 HIT"; statusClr = C'255,220,120'; }
   else if(g_tracker.tp1Hit) { statusLbl = "TP1 HIT - BE"; statusClr = C'255,220,120'; }

   string side = (g_tracker.trend == TREND_BULL) ? "LONG" : "SHORT";
   string head = StringFormat("LIVE TRADE %s [%s]  %s", side, g_tracker.grade, statusLbl);
   UpsertTagLabel("AU_TT_HEAD", x + 10, y + 6, head, statusClr, 10);

   string l2 = StringFormat("Entry %s  SL %s",
      DoubleToString(g_tracker.entry, Digits()),
      DoubleToString(g_tracker.stop, Digits()));
   UpsertTagLabel("AU_TT_L2", x + 10, y + 24, l2, C'220,228,240', 8);

   string l3 = StringFormat("R now %+.2f  | peak %+.2f  | bars %d",
      g_tracker.currentR, g_tracker.peakR, g_tracker.barsInTrade);
   UpsertTagLabel("AU_TT_L3", x + 10, y + 40, l3, C'200,210,228', 8);

   double rDisp = ClampRange(g_tracker.currentR, -1.0, 3.0);
   double rPct = (rDisp + 1.0) / 4.0;
   color rClr = (g_tracker.currentR >= 0.0) ? border : C'255,160,170';
   DrawGaugeBar("AU_TT_GAUGE", x + 10, y + 58, w - 20, 12, rPct * 100.0, 100.0, rClr, C'24,28,40', C'60,72,100');

   string l4 = StringFormat("TP1 %s %s | TP2 %s %s",
      DoubleToString(g_tracker.tp1, Digits()), g_tracker.tp1Hit ? "OK" : "...",
      DoubleToString(g_tracker.tp2, Digits()), g_tracker.tp2Hit ? "OK" : "...");
   UpsertTagLabel("AU_TT_L4", x + 10, y + 72, l4, C'200,210,228', 7);
}


string TFToStr(ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0)
      s = StringSubstr(s, 7);
   return s;
}

string TrendDirToStr(double trend)
{
   if(trend == TREND_BULL) return "UP";
   if(trend == TREND_BEAR) return "DOWN";
   return "NONE";
}

string SignalToStr(double trend)
{
   if(trend == TREND_BULL) return "BUY";
   if(trend == TREND_BEAR) return "SELL";
   return "NONE";
}

double SignalTrendAt(int idx)
{
   if(idx < 0 || idx >= ArraySize(bufConfirmedBuy)) return TREND_NONE;
   bool hasBuy  = (bufConfirmedBuy[idx]  != EMPTY_VALUE);
   bool hasSell = (bufConfirmedSell[idx] != EMPTY_VALUE);
   if(hasBuy && !hasSell)  return TREND_BULL;
   if(hasSell && !hasBuy)  return TREND_BEAR;
   if(idx < ArraySize(workSignalTrend) && workSignalTrend[idx] != TREND_NONE)
      return workSignalTrend[idx];
   return TREND_NONE;
}

string StateToStr(int state)
{
   if(state == STATE_WATCH) return "WATCH";
   if(state == STATE_CONFIRMED) return "CONFIRMED";
   return "WAIT";
}

string FitText(string text, int maxChars)
{
   if(maxChars <= 0) return "";
   if(StringLen(text) <= maxChars) return text;
   if(maxChars <= 3) return StringSubstr(text, 0, maxChars);
   return StringSubstr(text, 0, maxChars - 3) + "...";
}

string MakeBar(int value, int maxValue, int width)
{
   if(maxValue <= 0 || width <= 0) return "";
   int filled = (int)MathRound((double)value / (double)maxValue * (double)width);
   if(filled < 0) filled = 0;
   if(filled > width) filled = width;
   string bar = "";
   for(int i = 0; i < width; i++)
      bar += (i < filled) ? "#" : ".";
   return bar;
}

void MakePanel(string name, int x, int y, int w, int h)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'16,20,30');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'42,52,78');
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

void MakeLabel(string name, int x, int y, string text, int size, color clr)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void UpsertLine(string name, datetime t1, datetime t2, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   if(price == EMPTY_VALUE || price <= 0.0) {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }

   ObjectMove(0, name, 0, t1, price);
   ObjectMove(0, name, 1, t2, price);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

void UpsertTagBox(string name, int left, int top, int width, int height, color fillClr, color borderClr)
{
   if(width <= 0 || height <= 0) {
      ObjectDelete(0, name);
      return;
   }

   bool needCreate = (ObjectFind(0, name) < 0);
   if(!needCreate) {
      long objType = ObjectGetInteger(0, name, OBJPROP_TYPE);
      if(objType != OBJ_RECTANGLE_LABEL) {
         ObjectDelete(0, name);
         needCreate = true;
      }
   }

   if(needCreate) {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, left);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, top);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fillClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

void UpsertTagLabel(string name, int x, int y, string text, color clr, int size)
{
   if(x < 0 || y < 0) {
      ObjectDelete(0, name);
      return;
   }

   bool needCreate = (ObjectFind(0, name) < 0);
   if(!needCreate) {
      long objType = ObjectGetInteger(0, name, OBJPROP_TYPE);
      if(objType != OBJ_LABEL) {
         ObjectDelete(0, name);
         needCreate = true;
      }
   }

   if(needCreate) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void DeleteConfirmedGuideObjects()
{
   ObjectDelete(0, "AU_CF_TP1");
   ObjectDelete(0, "AU_CF_TP2");
   ObjectDelete(0, "AU_CF_TP1BOX");
   ObjectDelete(0, "AU_CF_TP1TAG");
   ObjectDelete(0, "AU_CF_TP2BOX");
   ObjectDelete(0, "AU_CF_TP2TAG");
   ObjectDelete(0, "AU_CF_BETAGBOX");
   ObjectDelete(0, "AU_CF_BETAG");
}

void DeleteConfirmedObjects()
{
   DeleteConfirmedGuideObjects();
   ObjectDelete(0, "AU_CF_ENTRY");
   ObjectDelete(0, "AU_CF_SL");
   ObjectDelete(0, "AU_CF_BOX");
   ObjectDelete(0, "AU_CF_TAG");
   ObjectDelete(0, "AU_CF_SLBOX");
   ObjectDelete(0, "AU_CF_SLTAG");
}

void DeleteWatchObjects()
{
   ObjectDelete(0, "AU_WT_ENTRY");
   ObjectDelete(0, "AU_WT_BOX");
   ObjectDelete(0, "AU_WT_TAG");
}

void DeleteDashboardObjects()
{
   ObjectsDeleteAll(0, "AU_DB_");
}

void DrawConfirmedLevels(int idx, double trend)
{
   if(idx < 0 || idx >= ArraySize(workTrend) || trend == TREND_NONE) {
      DeleteConfirmedObjects();
      return;
   }

   int periodSec = PeriodSeconds();
   if(periodSec <= 0) periodSec = 60;

   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, idx);
   if(t1 <= 0) return;
   datetime t2 = (datetime)(t1 + periodSec * 2);
   datetime guideT2 = (datetime)(t1 + periodSec * 3);
   datetime tagTime = (datetime)(t2 + periodSec / 5);
   datetime guideTagTime = (datetime)(guideT2 + periodSec / 5);

   double entryPrice = bufClose[idx];
   double stopPrice = InpUseSwingStop ? CalcSwingStop(idx, trend, bufHigh, bufLow)
                                      : ((trend == TREND_BULL) ? workFinalDn[idx] : workFinalUp[idx]);
   stopPrice = NormalizeStopSide(idx, entryPrice, stopPrice, trend);
   double tp1Price = CalcGuideTargetPrice(entryPrice, stopPrice, trend, InpTp1RiskMultiple);
   double tp2Price = CalcAdaptiveTp2(entryPrice, stopPrice, trend, tmpATR[idx]);
   double riskDistance = MathAbs(entryPrice - stopPrice);

   color entryClr = (trend == TREND_BULL) ? C'0,214,180' : C'255,102,128';
   color stopClr = C'255,204,92';
   color tp1Clr = C'72,222,170';
   color tp2Clr = C'92,166,255';
   color beClr = C'255,214,98';
   color boxClr = (trend == TREND_BULL) ? C'14,72,80' : C'86,28,42';
   color stopBoxClr = C'92,70,24';
   color tp1BoxClr = C'18,72,56';
   color tp2BoxClr = C'20,48,86';
   color beBoxClr = C'90,78,24';
   color textClr = C'228,255,249';
   color stopTextClr = C'255,247,224';
   color tpTextClr = C'236,255,248';
   color beTextClr = C'255,248,214';

   UpsertLine("AU_CF_ENTRY", t1, t2, entryPrice, entryClr, STYLE_SOLID, 3);
   UpsertLine("AU_CF_SL", t1, t2, stopPrice, stopClr, STYLE_DASHDOT, 2);

   if(InpShowExecutionGuide && riskDistance > _Point && tp1Price != EMPTY_VALUE && tp2Price != EMPTY_VALUE) {
      UpsertLine("AU_CF_TP1", t1, guideT2, tp1Price, tp1Clr, STYLE_DASH, 2);
      UpsertLine("AU_CF_TP2", t1, guideT2, tp2Price, tp2Clr, STYLE_DOT, 2);
   }
   else {
      DeleteConfirmedGuideObjects();
   }

   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   if(!ChartTimePriceToXY(0, 0, tagTime, entryPrice, x1, y1) || !ChartTimePriceToXY(0, 0, tagTime, stopPrice, x2, y2))
      return;

   string entryText = StringFormat("ENTRY %s", DoubleToString(entryPrice, Digits()));
   string stopText = StringFormat("SL %s", DoubleToString(stopPrice, Digits()));
   int entryWidth = MathMax(StringLen(entryText) * 8 + 20, 94);
   int stopWidth = MathMax(StringLen(stopText) * 8 + 20, 80);
   int height = 19;

   UpsertTagBox("AU_CF_BOX", x1, y1 - 10, entryWidth, height, boxClr, entryClr);
   UpsertTagLabel("AU_CF_TAG", x1 + 10, y1 - 7, entryText, textClr, 9);
   UpsertTagBox("AU_CF_SLBOX", x2, y2 - 10, stopWidth, height, stopBoxClr, stopClr);
   UpsertTagLabel("AU_CF_SLTAG", x2 + 10, y2 - 7, stopText, stopTextClr, 9);

   if(!InpShowExecutionGuide || riskDistance <= _Point || tp1Price == EMPTY_VALUE || tp2Price == EMPTY_VALUE) {
      DeleteConfirmedGuideObjects();
      return;
   }

   int tp1X = 0, tp1Y = 0, tp2X = 0, tp2Y = 0;
   if(!ChartTimePriceToXY(0, 0, guideTagTime, tp1Price, tp1X, tp1Y) || !ChartTimePriceToXY(0, 0, guideTagTime, tp2Price, tp2X, tp2Y)) {
      DeleteConfirmedGuideObjects();
      return;
   }

   string tp1Text = StringFormat("TP1 %s (%.1fR)", DoubleToString(tp1Price, Digits()), InpTp1RiskMultiple);
   string tp2Text = StringFormat("TP2 %s (%.1fR)", DoubleToString(tp2Price, Digits()), InpTp2RiskMultiple);
   string beText = StringFormat("BE @ %s after TP1", DoubleToString(entryPrice, Digits()));
   int tp1Width = MathMax(StringLen(tp1Text) * 8 + 20, 118);
   int tp2Width = MathMax(StringLen(tp2Text) * 8 + 20, 118);
   int beWidth = MathMax(StringLen(beText) * 8 + 20, 144);
   int tp1Top = tp1Y - 10;
   int tp2Top = tp2Y - 10;
   int beTop = y1 + 12;
   if(tp1Top < 4) tp1Top = 4;
   if(tp2Top < 4) tp2Top = 4;
   if(beTop < 4) beTop = 4;

   UpsertTagBox("AU_CF_TP1BOX", tp1X + 8, tp1Top, tp1Width, height, tp1BoxClr, tp1Clr);
   UpsertTagLabel("AU_CF_TP1TAG", tp1X + 18, tp1Top + 3, tp1Text, tpTextClr, 8);
   UpsertTagBox("AU_CF_TP2BOX", tp2X + 8, tp2Top, tp2Width, height, tp2BoxClr, tp2Clr);
   UpsertTagLabel("AU_CF_TP2TAG", tp2X + 18, tp2Top + 3, tp2Text, tpTextClr, 8);
   UpsertTagBox("AU_CF_BETAGBOX", x1 + 8, beTop, beWidth, height, beBoxClr, beClr);
   UpsertTagLabel("AU_CF_BETAG", x1 + 18, beTop + 3, beText, beTextClr, 8);
}


void DrawWatchLevels(int idx, double trend)
{
   if(!InpShowWatchTag || idx < 0 || idx >= ArraySize(workTrend) || trend == TREND_NONE) {
      DeleteWatchObjects();
      return;
   }

   int periodSec = PeriodSeconds();
   if(periodSec <= 0) periodSec = 60;
   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, idx);
   if(t1 <= 0) return;
   datetime t2 = (datetime)(t1 + periodSec);
   datetime tagTime = (datetime)(t1 + periodSec / 2);
   double entryPrice = bufClose[idx];

   color entryClr = (trend == TREND_BULL) ? C'88,244,208' : C'255,158,176';
   color boxClr = (trend == TREND_BULL) ? C'12,58,64' : C'74,24,34';
   color textClr = (trend == TREND_BULL) ? C'228,255,249' : C'255,240,244';

   UpsertLine("AU_WT_ENTRY", t1, t2, entryPrice, entryClr, STYLE_DOT, 2);

   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, tagTime, entryPrice, x, y))
      return;

   string label = StringFormat("WATCH %s %.0f/%.0f",
      (trend == TREND_BULL) ? "BUY" : "SELL",
      workLiveScore[idx], g_effectiveWatchThreshold);
   int width = MathMax(StringLen(label) * 8 + 20, 130);
   int top = (trend == TREND_BULL) ? (y + 8) : (y - 28);
   if(top < 4) top = 4;
   UpsertTagBox("AU_WT_BOX", x + 10, top, width, 19, boxClr, entryClr);
   UpsertTagLabel("AU_WT_TAG", x + 20, top + 3, label, textClr, 8);
}

int FindLatestConfirmedBar(int maxLookback)
{
   int last = MathMin(ArraySize(workTrend) - 1, maxLookback);
   if(last < 1) return -1;
   for(int i = 1; i <= last; i++) {
      if(bufConfirmedBuy[i] != EMPTY_VALUE || bufConfirmedSell[i] != EMPTY_VALUE)
         return i;
   }
   return -1;
}

int FindConfirmedBarInCurrentLeg(int maxLookback)
{
   if(ArraySize(workTrend) <= 1 || workTrend[0] == TREND_NONE)
      return -1;

   double currentTrend = workTrend[0];
   int last = MathMin(ArraySize(workTrend) - 1, maxLookback);
   for(int i = 1; i <= last; i++) {
      double sigTrend = SignalTrendAt(i);
      if(sigTrend != TREND_NONE) {
         if(sigTrend == currentTrend) return i;
         if(workTrend[i] != currentTrend) break;
         continue;
      }
      if(workTrend[i] != currentTrend)
         break;
   }
   return -1;
}

void RefreshVisuals()
{
   int confirmedBar = FindLatestConfirmedBar(MathMax(120, InpSignalLookbackBars));
   if(confirmedBar >= 0)
      DrawConfirmedLevels(confirmedBar, SignalTrendAt(confirmedBar));
   else
      DeleteConfirmedObjects();

   DeleteWatchObjects();
   DrawMomentumStrip();
   DrawSignalMarkers();
   if(InpShowKillzones && InpUseSessionEngine)
      DrawKillzoneMarkers();
}

void DeleteSignalMarkers()
{
   ObjectsDeleteAll(0, "AU_SM_");
}

void DrawSignalMarkers()
{
   DeleteSignalMarkers();
   if(!InpShowSignalMarkers) return;

   int bars    = ArraySize(bufConfirmedBuy);
   if(bars <= 1) return;
   int look    = MathMin(InpSignalMarkerLookback, bars - 1);
   int barSecs = PeriodSeconds(PERIOD_CURRENT);

   for(int i = 1; i <= look; i++) {
      bool isBuy  = (bufConfirmedBuy[i]  != EMPTY_VALUE);
      bool isSell = (bufConfirmedSell[i] != EMPTY_VALUE);
      if(!isBuy && !isSell) continue;

      datetime t = iTime(_Symbol, PERIOD_CURRENT, i);
      if(t == 0) continue;

      double atr = tmpATR[i];
      if(atr <= _Point) atr = 10.0 * _Point;

      double arrowOff = MathMax(atr * 0.30, 20.0 * _Point);
      double labelOff = MathMax(atr * 0.50, 30.0 * _Point);

      double barHigh = bufHigh[i];
      double barLow  = bufLow[i];
      color  col     = isBuy ? InpMarkerBuyColor : InpMarkerSellColor;
      string side    = isBuy ? "BUY" : "SELL";

      double arrowPx = isBuy ? (barLow - arrowOff) : (barHigh + arrowOff);
      if(isBuy) bufConfirmedBuy[i]  = arrowPx;
      else      bufConfirmedSell[i] = arrowPx;

      double labelPx = isBuy ? (arrowPx - labelOff) : (arrowPx + labelOff);

      datetime tL = t - (datetime)(barSecs / 2);
      datetime tR = t + (datetime)(barSecs / 2);
      string boxName = StringFormat("AU_SM_BOX_%d", i);
      if(ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, tL, barHigh, tR, barLow)) {
         ObjectSetInteger(0, boxName, OBJPROP_COLOR,      col);
         ObjectSetInteger(0, boxName, OBJPROP_STYLE,      STYLE_SOLID);
         ObjectSetInteger(0, boxName, OBJPROP_WIDTH,      1);
         ObjectSetInteger(0, boxName, OBJPROP_FILL,       false);
         ObjectSetInteger(0, boxName, OBJPROP_BACK,       true);
         ObjectSetInteger(0, boxName, OBJPROP_HIDDEN,     true);
         ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
      }

      double poleStart = isBuy ? barLow : barHigh;
      string poleName  = StringFormat("AU_SM_POLE_%d", i);
      if(ObjectCreate(0, poleName, OBJ_TREND, 0, t, poleStart, t, arrowPx)) {
         ObjectSetInteger(0, poleName, OBJPROP_COLOR,      col);
         ObjectSetInteger(0, poleName, OBJPROP_WIDTH,      1);
         ObjectSetInteger(0, poleName, OBJPROP_STYLE,      STYLE_DOT);
         ObjectSetInteger(0, poleName, OBJPROP_RAY_LEFT,   false);
         ObjectSetInteger(0, poleName, OBJPROP_RAY_RIGHT,  false);
         ObjectSetInteger(0, poleName, OBJPROP_BACK,       true);
         ObjectSetInteger(0, poleName, OBJPROP_HIDDEN,     true);
         ObjectSetInteger(0, poleName, OBJPROP_SELECTABLE, false);
      }

      string triChar  = isBuy ? "▲" : "▼";
      string triName  = StringFormat("AU_SM_TRI_%d", i);
      ENUM_ANCHOR_POINT triAnchor = isBuy ? ANCHOR_LOWER : ANCHOR_UPPER;
      if(ObjectCreate(0, triName, OBJ_TEXT, 0, t, arrowPx)) {
         ObjectSetString (0, triName, OBJPROP_TEXT,       triChar);
         ObjectSetString (0, triName, OBJPROP_FONT,       "Consolas");
         ObjectSetInteger(0, triName, OBJPROP_FONTSIZE,   11);
         ObjectSetInteger(0, triName, OBJPROP_COLOR,      col);
         ObjectSetInteger(0, triName, OBJPROP_ANCHOR,     triAnchor);
         ObjectSetInteger(0, triName, OBJPROP_HIDDEN,     true);
         ObjectSetInteger(0, triName, OBJPROP_SELECTABLE, false);
      }

      string lblName  = StringFormat("AU_SM_LBL_%d", i);
      ENUM_ANCHOR_POINT lblAnchor = isBuy ? ANCHOR_UPPER : ANCHOR_LOWER;
      if(ObjectCreate(0, lblName, OBJ_TEXT, 0, t, labelPx)) {
         ObjectSetString (0, lblName, OBJPROP_TEXT,       side);
         ObjectSetString (0, lblName, OBJPROP_FONT,       "Consolas");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE,   8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR,      col);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR,     lblAnchor);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN,     true);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      }
   }
}


void DrawDashboard()
{
   if(!InpShowDashboard) {
      DeleteDashboardObjects();
      ObjectsDeleteAll(0, "AU_TT_");
      DeleteMomentumStrip();
      return;
   }

   int bars = ArraySize(workTrend);
   if(bars <= 1) {
      DeleteDashboardObjects();
      return;
   }

   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int panelW = MathMin(480, MathMax(cw - 24, 380));
   int lineH = 18;
   int panelX = cw - panelW - 14;
   if(panelX < 10) panelX = 10;
   int padX = panelX + 14;
   int y = 22;
   int maxChars = MathMax((panelW - 30) / 7, 50);

   int confirmedBar = FindLatestConfirmedBar(MathMax(120, InpSignalLookbackBars));
   bool hasConfirmed = (confirmedBar >= 0);
   int currentLegConfirmedBar = FindConfirmedBarInCurrentLeg(MathMax(120, InpSignalLookbackBars));
   bool currentLegLocked = (currentLegConfirmedBar >= 0);
   if(!hasConfirmed) confirmedBar = (bars > 1) ? 1 : 0;
   double confirmedTrend = hasConfirmed ? SignalTrendAt(confirmedBar) : TREND_NONE;
   if(hasConfirmed && confirmedTrend == TREND_NONE) confirmedTrend = workTrend[confirmedBar];

   int liveRegime = (int)workRegime[0];
   if(liveRegime < 0 || liveRegime > 2) liveRegime = 0;
   int closeRegime = (int)workRegime[confirmedBar];
   if(closeRegime < 0 || closeRegime > 2) closeRegime = 0;
   string regimeNames[3] = {"RANGE", "TREND", "VOL"};

   double liveReadyEdge = 0.0;
   bool liveReady = !currentLegLocked && IsWatchSignal(0, workTrend[0], liveReadyEdge);
   string liveBiasText = SignalToStr(workTrend[0]);
   double liveDirEdge = (workTrend[0] != TREND_NONE) ? CalcDirectionalEdgeLite(0, workTrend[0]) : liveReadyEdge;
   double confirmedDirEdge = hasConfirmed ? CalcDirectionalEdgeLite(confirmedBar, confirmedTrend) : 0.0;
   double confirmedEntry = hasConfirmed ? bufClose[confirmedBar] : 0.0;
   double confirmedStop = hasConfirmed
      ? (InpUseSwingStop ? CalcSwingStop(confirmedBar, confirmedTrend, bufHigh, bufLow)
                         : ((confirmedTrend == TREND_BULL) ? workFinalDn[confirmedBar] : workFinalUp[confirmedBar]))
      : 0.0;
   if(hasConfirmed) confirmedStop = NormalizeStopSide(confirmedBar, confirmedEntry, confirmedStop, confirmedTrend);
   double confirmedTp1 = hasConfirmed ? CalcGuideTargetPrice(confirmedEntry, confirmedStop, confirmedTrend, InpTp1RiskMultiple) : EMPTY_VALUE;
   double confirmedTp2 = hasConfirmed ? CalcAdaptiveTp2(confirmedEntry, confirmedStop, confirmedTrend, tmpATR[confirmedBar]) : EMPTY_VALUE;
   double confirmedGrade = hasConfirmed ? workGrade[confirmedBar] : 0.0;
   string confirmedLetter = hasConfirmed ? GradeLetter(confirmedGrade) : "-";
   color  confirmedGradeClr = hasConfirmed ? GradeColor(confirmedGrade) : (color)C'150,150,150';
   bool confirmedDiv = hasConfirmed && (workDiv[confirmedBar] != 0.0);

   ENUM_GOLD_SESSION session = (ENUM_GOLD_SESSION)(int)workSession[0];
   if((int)session < 0 || (int)session > 6) session = SESSION_DEAD;
   ENUM_ATR_CYCLE cycle = (ENUM_ATR_CYCLE)(int)workCycleState[0];
   if((int)cycle < 0 || (int)cycle > 3) cycle = CYCLE_NORMAL;

   int panelH = 440;
   if(InpUseSessionEngine) panelH += 20;
   if(InpUseDXYFilter && g_dxyAvailable) panelH += 20;
   if(InpUseATRCycle) panelH += 20;
   if(InpShowTradeTracker && g_tracker.active) panelH += 100;

   UpsertTagBox("AU_DB_PANEL", panelX, y - 8, panelW, panelH, C'12,16,26', C'42,52,78');
   UpsertTagBox("AU_DB_HEADBAR", panelX, y - 8, panelW, 30, C'32,22,12', InpThemeAccent);
   MakeLabel("AU_DB_LOGO", padX, y, "AURUMPULSE  v1.0  GOLD", 11, InpThemeAccent);
   MakeLabel("AU_DB_SYM", panelX + panelW - 130, y, StringFormat("%s  %s", _Symbol, TFToStr(Period())), 9, C'180,200,230');
   y += lineH + 10;

   string liveStateTxt;
   color  liveStateClr;
   string liveStateToken;
   if(currentLegLocked) {
      liveStateTxt = StringFormat("LIVE  -  LEG LOCKED %s  (%db ago)", liveBiasText, currentLegConfirmedBar);
      liveStateClr = (workTrend[0] == TREND_BULL) ? InpThemeBullish : InpThemeBearish;
      liveStateToken = "LOCKED";
   } else if(liveReady) {
      liveStateTxt = StringFormat("LIVE  -  READY %s ON CLOSE", liveBiasText);
      liveStateClr = (workTrend[0] == TREND_BULL) ? InpThemeBullish : InpThemeBearish;
      liveStateToken = "READY";
   } else if(workTrend[0] != TREND_NONE) {
      liveStateTxt = StringFormat("LIVE  -  WAIT %s BIAS", liveBiasText);
      liveStateClr = (workTrend[0] == TREND_BULL) ? C'150,210,170' : C'232,160,170';
      liveStateToken = "WAIT";
   } else {
      liveStateTxt = "LIVE  -  WAIT TREND";
      liveStateClr = C'180,180,200';
      liveStateToken = "WAIT";
   }
   MakeLabel("AU_DB_LIVE", padX, y, FitText(liveStateTxt, maxChars), 10, liveStateClr);
   y += lineH;
   MakeLabel("AU_DB_REG", padX, y, StringFormat("Regime: %s  |  State: %s", regimeNames[liveRegime], liveStateToken), 9, C'170,200,230');
   y += lineH + 4;

   DrawHTFTrendRow(padX, y, panelW, maxChars);

   if(InpUseSessionEngine) {
      SessionParams sp = GetSessionParams(session);
      color sc = SessionColor(session);
      string suppTag = (InpFilterAsiaSignals && sp.suppressFire) ? "  SUPPRESSED" : "";
      string sRow = StringFormat("  Session: %s  (%.2fx)%s", SessionToStr(session), sp.thresholdMult, suppTag);
      MakeLabel("AU_DB_SESS", padX, y, FitText(sRow, maxChars), 9, sc);
      y += lineH;
   }

   if(InpUseDXYFilter) {
      string dxyTxt = "  DXY: N/A";
      color dxyClr = C'140,150,170';
      if(g_dxyAvailable && ArraySize(g_dxyCloseCache) > 0 && g_dxyCloseCache[0] > 0.0) {
          double db0 = GetDXYBias(0, workTrend[0]);
          double dc0 = (ArraySize(workDXYCorrelation) > 0) ? workDXYCorrelation[0] : 0.0;
          string dir = (db0 > 0.0) ? "▲" : (db0 < -5.0 ? "▼" : "─");
          string align = (db0 > 5.0) ? " ✓" : (db0 < -5.0 ? " ⚠" : "");
          dxyTxt = StringFormat("  DXY %.2f %s | Corr %+.2f%s", g_dxyCloseCache[0], dir, dc0, align);
          dxyClr = (db0 > 5.0) ? C'100,220,180' : (db0 < -5.0 ? C'255,150,160' : C'180,190,210');
      }
      MakeLabel("AU_DB_DXY", padX, y, FitText(dxyTxt, maxChars), 9, dxyClr);
      y += lineH;
   }

   if(InpUseATRCycle) {
      color cc = CycleColor(cycle);
      string cRow = StringFormat("  ATR Cycle: %s  (bias %+.0f)", CycleToStr(cycle), (ArraySize(workCycleBias) > 0) ? workCycleBias[0] : 0.0);
      MakeLabel("AU_DB_CYC", padX, y, FitText(cRow, maxChars), 9, cc);
      y += lineH;
   }

   if(InpUseRoundNumbers && ArraySize(workRoundScore) > 0) {
      double rn = workRoundScore[0];
      double nearest = MathRound(bufClose[0] / InpRoundNumberInterval) * InpRoundNumberInterval;
      double distPct = (nearest > 0.0) ? MathAbs(bufClose[0] - nearest) / nearest * 100.0 : 0.0;
      string rnTxt = StringFormat("  Round $%.0f  dist %.2f%%  score %+.0f", nearest, distPct, rn);
      color rnClr = (rn > 5.0) ? C'255,210,90' : (rn > 2.0 ? C'180,200,220' : C'130,140,160');
      MakeLabel("AU_DB_RND", padX, y, FitText(rnTxt, maxChars), 8, rnClr);
      y += lineH;
   }

   if(InpUseSweepDetection && ArraySize(workSweepDepth) > 0 && workSweepDepth[0] > 0.0) {
      color swClr = (workSweepDepth[0] > InpMinSweepDepthAtr * 1.5) ? C'100,220,180' : C'140,150,170';
      MakeLabel("AU_DB_SWP", padX, y, StringFormat("  Sweep: %.2f ATR depth", workSweepDepth[0]), 8, swClr);
      y += lineH;
   }

   int gaugeW = (panelW - 40) / 2;

   MakeLabel("AU_DB_LSL", padX, y, StringFormat("Live Score  %.0f / %.0f", workLiveScore[0], g_goldWatchThreshold), 8, C'180,195,220');
   MakeLabel("AU_DB_MOL", padX + gaugeW + 12, y, StringFormat("Momentum  %.0f / %.0f", workMomentum[0], g_goldMomentumFloor), 8, C'180,195,220');
   y += 14;
   DrawGaugeBar("AU_DB_GLS", padX, y, gaugeW, 10,
      workLiveScore[0], 100.0,
      (workLiveScore[0] >= g_goldWatchThreshold) ? liveStateClr : (color)C'120,140,170',
      C'22,28,42', C'58,72,100');
   DrawGaugeBar("AU_DB_GMO", padX + gaugeW + 12, y, gaugeW, 10,
      workMomentum[0], 100.0,
      (workMomentum[0] >= g_goldMomentumFloor) ? (color)C'140,220,200' : (color)C'120,140,170',
      C'22,28,42', C'58,72,100');
   y += 18;

   MakeLabel("AU_DB_HLL", padX, y, StringFormat("Health  %.0f / %.0f", workHealth[0], g_goldHealthFloor), 8, C'180,195,220');
   MakeLabel("AU_DB_EXL", padX + gaugeW + 12, y, StringFormat("Exhaust %.0f / %.0f", workExhaustion[0], g_effectiveExhaustionBlock), 8, C'180,195,220');
   y += 14;
   DrawGaugeBar("AU_DB_GHL", padX, y, gaugeW, 10,
      workHealth[0], 100.0,
      (workHealth[0] >= g_goldHealthFloor) ? (color)C'120,210,160' : (color)C'200,180,120',
      C'22,28,42', C'58,72,100');
   DrawGaugeBar("AU_DB_GEX", padX + gaugeW + 12, y, gaugeW, 10,
      workExhaustion[0], 100.0,
      (workExhaustion[0] >= g_effectiveExhaustionBlock - 10.0) ? (color)C'255,140,150' : (color)C'140,180,120',
      C'22,28,42', C'58,72,100');
   y += 20;

   string metrics = StringFormat("Flow %+.0f | Edge %.0f | ADX %.1f | DI %.1f/%.1f | RSI %.1f | ATR %.0fpt",
      workFlow[0], liveDirEdge, tmpADXMain[0], tmpDIPlus[0], tmpDIMinus[0], tmpRSI[0], tmpATR[0] / _Point);
   MakeLabel("AU_DB_MET", padX, y, FitText(metrics, maxChars), 8, C'150,168,196');
   y += lineH;

   UpsertTagBox("AU_DB_SEP1", padX, y + 2, panelW - 24, 1, C'56,68,96', C'56,68,96');
   y += lineH;

   string confirmedSignal = hasConfirmed ? SignalToStr(confirmedTrend) : "NONE";
   string confirmedHead = hasConfirmed
      ? StringFormat("LAST CONFIRMED  %s  %db ago  -  GRADE %s", confirmedSignal, confirmedBar, confirmedLetter)
      : "LAST CONFIRMED  -  NONE";
   color confirmedHeadClr = hasConfirmed ? confirmedGradeClr : (color)C'140,150,170';
   MakeLabel("AU_DB_CHEAD", padX, y, FitText(confirmedHead, maxChars), 10, confirmedHeadClr);
   if(hasConfirmed && confirmedDiv)
      MakeLabel("AU_DB_CDIV", panelX + panelW - 110, y, "DIV WARN", 8, C'255,180,120');
   else
      ObjectDelete(0, "AU_DB_CDIV");
   y += lineH;

   MakeLabel("AU_DB_CGL", padX, y, StringFormat("Composite Grade  %.0f / 100  (%s)", confirmedGrade, confirmedLetter), 8, C'180,195,220');
   y += 14;
   DrawGaugeBar("AU_DB_CGG", padX, y, panelW - 28, 12, confirmedGrade, 100.0, confirmedGradeClr, C'22,28,42', C'58,72,100');
   y += 20;

   string cInfo = hasConfirmed
      ? StringFormat("Score %.0f/%.0f | H %.0f | Exh %.0f | Edge %.0f | %s",
         workConfirmedScore[confirmedBar], g_goldConfirmedThreshold,
         workHealth[confirmedBar], workExhaustion[confirmedBar], confirmedDirEdge,
         regimeNames[closeRegime])
      : "Score --/-- | H -- | Exh -- | Edge -- | --";
   MakeLabel("AU_DB_CINF", padX, y, FitText(cInfo, maxChars), 8, C'160,180,210');
   y += lineH;

   string cLevels1 = hasConfirmed
      ? StringFormat("Entry %s  |  SL %s",
         DoubleToString(confirmedEntry, Digits()),
         DoubleToString(confirmedStop, Digits()))
      : "Entry --  |  SL --";
   MakeLabel("AU_DB_CL1", padX, y, FitText(cLevels1, maxChars), 9, C'244,224,166');
   y += lineH;

   string cLevels2 = (hasConfirmed && confirmedTp1 != EMPTY_VALUE && confirmedTp2 != EMPTY_VALUE)
      ? StringFormat("TP1 %s (1.0R)  |  TP2 %s%s  |  BE after TP1",
         DoubleToString(confirmedTp1, Digits()),
         DoubleToString(confirmedTp2, Digits()),
         InpUseAdaptiveTp ? " adp" : "")
      : "TP1 --  |  TP2 --";
   MakeLabel("AU_DB_CL2", padX, y, FitText(cLevels2, maxChars), 9, C'232,210,160');
   y += lineH;

   UpsertTagBox("AU_DB_SEP2", padX, y + 2, panelW - 24, 1, C'56,68,96', C'56,68,96');
   y += lineH;

   string ftr = StringFormat("Gold|Swp:%s|DXY:%s|Rnd:%s|Cyc:%s|Div:%s|CBlk:%s|SL:%s|TP:%s",
      InpUseSweepDetection ? "ON" : "OFF",
      g_dxyAvailable ? "ON" : "N/A",
      InpUseRoundNumbers ? "ON" : "OFF",
      InpUseATRCycle ? "ON" : "OFF",
      InpUseDivergenceFilter ? "ON" : "OFF",
      InpBlockGradeC ? "ON" : "OFF",
      InpUseSwingStop ? "Swing" : "Band",
      InpUseAdaptiveTp ? "Adp" : "Fix");
   MakeLabel("AU_DB_FTR", padX, y, FitText(ftr, maxChars), 8, C'130,148,180');
   y += lineH;

   if(InpShowTradeTracker && g_tracker.active) {
      DrawTradeTrackerPanel(panelX + 6, y, panelW - 12);
   } else {
      ObjectsDeleteAll(0, "AU_TT_");
   }

   ChartRedraw(0);
}


void DeleteKillzoneMarkers()
{
   ObjectsDeleteAll(0, "AU_KZ_");
}

void DrawKillzoneMarkers()
{
   DeleteKillzoneMarkers();
   if(!InpShowKillzones || !InpUseSessionEngine) return;

   if(ArraySize(bufClose) <= 1) return;

   datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(todayStart <= 0) return;
   datetime todayEnd = todayStart + PeriodSeconds(PERIOD_D1);

   datetime firstVisible = iTime(_Symbol, PERIOD_CURRENT, MathMin(ArraySize(bufClose) - 1, 300));
   if(firstVisible > todayStart) firstVisible = todayStart;

   int hourMarkers[5] = {8, 9, 14, 17, 19};
   string labelMarkers[5] = {"LO", "LO+", "NYO", "LC", "EOD"};
   color markerColors[5] = {
      C'255,180,60',
      C'255,200,80',
      C'255,140,60',
      C'200,120,50',
      C'120,100,80'
   };

   for(int s = 0; s < 5; s++) {
      datetime markerTime = todayStart + hourMarkers[s] * 3600;
      if(markerTime <= 0 || markerTime < firstVisible || markerTime > todayEnd) continue;

      string vLine = StringFormat("AU_KZ_VL_%d", s);
      double topPrice = iHigh(_Symbol, PERIOD_CURRENT, 0);
      double botPrice = iLow(_Symbol, PERIOD_CURRENT, 0);
      int visBars = MathMin(ArraySize(bufClose) - 1, 100);
      for(int b = 0; b <= visBars; b++) {
         if(bufHigh[b] > topPrice) topPrice = bufHigh[b];
         if(bufLow[b] < botPrice) botPrice = bufLow[b];
      }
      double range = topPrice - botPrice;
      topPrice += range * 0.15;
      botPrice -= range * 0.15;

      if(ObjectCreate(0, vLine, OBJ_VLINE, 0, markerTime, 0)) {
         ObjectSetInteger(0, vLine, OBJPROP_COLOR, markerColors[s]);
         ObjectSetInteger(0, vLine, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, vLine, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, vLine, OBJPROP_BACK, true);
         ObjectSetInteger(0, vLine, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, vLine, OBJPROP_HIDDEN, true);
      }

      string lblName = StringFormat("AU_KZ_LBL_%d", s);
      double lblPrice = (s % 3 == 0) ? topPrice : botPrice;
      ENUM_ANCHOR_POINT anc = (s % 3 == 0) ? ANCHOR_LOWER : ANCHOR_UPPER;
      if(ObjectCreate(0, lblName, OBJ_TEXT, 0, markerTime, lblPrice)) {
         ObjectSetString(0, lblName, OBJPROP_TEXT, labelMarkers[s]);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, markerColors[s]);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, anc);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, true);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
      }
   }
}

void CheckAlerts(int prevCalculated, int rates, const datetime &time[], const double &close[])
{
   if(!InpAlertPopup && !InpAlertPush) return;
   if(prevCalculated <= 0 || prevCalculated >= rates) return;

   static datetime lastConfirmedAlert = 0;

   string sym = _Symbol;
   string tf = TFToStr(Period());

   int alertLookback = MathMax(12, InpReversalBackScan + InpEarlyWindowBars + 3);
   int alertBar = FindLatestConfirmedBar(alertLookback);
   if(alertBar < 1 || alertBar >= rates) return;

   double alertTrend = SignalTrendAt(alertBar);
   if(alertTrend == TREND_NONE || time[alertBar] == lastConfirmedAlert) return;

   string letter = GradeLetter(workGrade[alertBar]);
   string htCtx = GetHTFContextString(alertBar);
   string htPrefix = (htCtx != "") ? htCtx + " " : "";

   string sessionStr = "";
   string dxyStr = "";
   string roundStr = "";
   string sweepStr = "";

   if(InpUseSessionEngine && alertBar < ArraySize(workSession)) {
      ENUM_GOLD_SESSION as = (ENUM_GOLD_SESSION)(int)workSession[alertBar];
      if((int)as >= 0 && (int)as <= 6) {
         sessionStr = StringFormat("%s ", SessionToStr(as));
      }
   }

   if(InpUseDXYFilter && g_dxyAvailable) {
      double db = GetDXYBias(alertBar, alertTrend);
      if(db > 5.0) dxyStr = "DXYv ";
      else if(db < -5.0) dxyStr = "DXY! ";
   }

   if(InpUseRoundNumbers && alertBar < ArraySize(workRoundScore)) {
      double rs = workRoundScore[alertBar];
      if(rs > 5.0) roundStr = StringFormat("$%.0f+%.0f ", MathRound(close[alertBar] / InpRoundNumberInterval) * InpRoundNumberInterval, rs);
      else if(rs > 2.0) roundStr = StringFormat("$%.0f~ ", MathRound(close[alertBar] / InpRoundNumberInterval) * InpRoundNumberInterval);
   }

   if(InpUseSweepDetection && alertBar < ArraySize(workSweepDepth)) {
      double sd = workSweepDepth[alertBar];
      if(sd > InpMinSweepDepthAtr * 1.5) sweepStr = "SWEEP! ";
   }

   string msg = StringFormat(
      "AU %s [%s] %s%s%s%s%s| %s %s | %s | G:%.0f Sc:%.0f H:%.0f Exh:%.0f",
      SignalToStr(alertTrend), letter, htPrefix, sweepStr, sessionStr, dxyStr, roundStr,
      sym, tf, DoubleToString(close[alertBar], Digits()),
      workGrade[alertBar], workConfirmedScore[alertBar], workHealth[alertBar], workExhaustion[alertBar]);
   if(InpAlertPopup) Alert(msg);
   if(InpAlertPush)  SendNotification(msg);
   lastConfirmedAlert = time[alertBar];
}

