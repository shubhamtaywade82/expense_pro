import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  FileText,
  TrendingUp,
  TrendingDown,
  ShieldCheck,
  AlertTriangle,
  CheckCircle2,
  Sparkles,
  IndianRupee,
  BarChart3,
  BookOpen,
  Receipt,
  Wallet,
  Building2,
  Coins,
} from "lucide-react";

function currentFy() {
  const now = new Date();
  return now.getMonth() >= 3 ? now.getFullYear() + 1 : now.getFullYear();
}

export default function ITR() {
  const [financialYear, setFinancialYear] = useState(currentFy());

  const { data: itr, isLoading, error } = useQuery({
    queryKey: ["tax", "itr", { financialYear }],
    queryFn: () => api.tax.itrSummary({ financialYear }),
  });

  const formatCurrency = (val: number) =>
    new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0,
    }).format(val || 0);

  const formatLakh = (val: number) => {
    if (val >= 10_00_000) return `₹${(val / 10_00_000).toFixed(2)}Cr`;
    if (val >= 1_00_000) return `₹${(val / 1_00_000).toFixed(2)}L`;
    return formatCurrency(val);
  };

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1 space-y-6 pb-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-card/40 p-4 lg:p-6 rounded-2xl border border-border/40 backdrop-blur-md shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-600 to-cyan-500 flex items-center justify-center shadow-lg shadow-blue-500/20 text-white">
            <FileText className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-2xl font-bold tracking-tight text-foreground">
              Income Tax Return (ITR) Planner
            </h2>
            <p className="text-sm text-muted-foreground">
              Old vs New regime comparison · Capital gains tax · STCG/LTCG · F&O business income
            </p>
          </div>
        </div>

        {/* FY Picker */}
        <div className="flex items-center gap-2 bg-card/60 p-1.5 rounded-xl border border-border/40">
          <Button variant="ghost" size="icon" className="h-8 w-8 rounded-lg" onClick={() => setFinancialYear(financialYear - 1)}>
            &larr;
          </Button>
          <span className="text-xs sm:text-sm font-semibold px-3 py-1 bg-muted/60 rounded-lg min-w-[120px] text-center">
            FY {financialYear - 1}-{String(financialYear).slice(2)}
          </span>
          <Button variant="ghost" size="icon" className="h-8 w-8 rounded-lg" onClick={() => setFinancialYear(financialYear + 1)}>
            &rarr;
          </Button>
        </div>
      </div>

      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-3">
          {[...Array(6)].map((_, i) => <Skeleton key={i} className="h-28 rounded-2xl" />)}
        </div>
      ) : error ? (
        <Card className="border border-rose-500/30 bg-rose-500/5">
          <CardContent className="p-6 text-center text-rose-600">
            Failed to load ITR data. Make sure you have income data recorded.
          </CardContent>
        </Card>
      ) : itr ? (
        <>
          {/* Recommendation Banner */}
          <div className={`p-4 lg:p-5 rounded-2xl border flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 ${
            itr.recommendation.best_regime === "New Tax Regime"
              ? "bg-emerald-500/10 border-emerald-500/30"
              : "bg-blue-500/10 border-blue-500/30"
          }`}>
            <div className="flex items-start gap-3">
              <CheckCircle2 className={`w-6 h-6 mt-0.5 flex-shrink-0 ${itr.recommendation.best_regime === "New Tax Regime" ? "text-emerald-500" : "text-blue-500"}`} />
              <div>
                <h3 className="font-bold text-lg text-foreground">
                  Recommended: {itr.recommendation.best_regime}
                </h3>
                <p className="text-sm text-muted-foreground mt-0.5">
                  Save <span className="font-bold text-foreground">{formatLakh(itr.recommendation.tax_saved)}</span> vs the other regime ·{" "}
                  <span className="font-semibold text-foreground">{itr.recommendation.itr_form}</span> applies to you
                </p>
              </div>
            </div>
            <Badge className={`text-sm px-4 py-1.5 font-bold ${
              itr.recommendation.best_regime === "New Tax Regime"
                ? "bg-emerald-500 text-white"
                : "bg-blue-500 text-white"
            }`}>
              {itr.recommendation.itr_form}
            </Badge>
          </div>

          {/* Gross Income + Trading Summary */}
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Card className="border border-border/40 bg-gradient-to-br from-indigo-500/10 via-card to-card">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Gross Salary / Income</CardTitle>
                <Wallet className="w-4 h-4 text-indigo-400" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-foreground">{formatLakh(itr.gross_salary)}</div>
                <p className="text-xs text-muted-foreground mt-1">FY {itr.financial_year} · AY {itr.assessment_year}</p>
              </CardContent>
            </Card>

            <Card className="border border-border/40 bg-card/60">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Total Trading P&L</CardTitle>
                {itr.trading_summary.total_pnl >= 0
                  ? <TrendingUp className="w-4 h-4 text-emerald-400" />
                  : <TrendingDown className="w-4 h-4 text-rose-400" />}
              </CardHeader>
              <CardContent>
                <div className={`text-2xl font-bold ${itr.trading_summary.total_pnl >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                  {itr.trading_summary.total_pnl >= 0 ? "+" : ""}{formatLakh(itr.trading_summary.total_pnl)}
                </div>
                <p className="text-xs text-muted-foreground mt-1">Combined intraday, F&O, equity & crypto</p>
              </CardContent>
            </Card>

            <Card className={`border ${itr.new_regime.total_tax < itr.old_regime.total_tax ? "border-emerald-500/30 bg-emerald-500/5" : "border-border/40 bg-card/60"}`}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-xs font-medium text-muted-foreground uppercase tracking-wide">New Regime Tax</CardTitle>
                {itr.new_regime.total_tax < itr.old_regime.total_tax && <CheckCircle2 className="w-4 h-4 text-emerald-500" />}
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-foreground">{formatLakh(itr.new_regime.total_tax)}</div>
                <p className="text-xs text-muted-foreground mt-1">Taxable income: {formatLakh(itr.new_regime.taxable_income)}</p>
                {itr.new_regime.rebate_87a > 0 && (
                  <Badge className="text-[10px] mt-1.5 bg-emerald-500/15 text-emerald-600 border-0">87A Rebate Applied</Badge>
                )}
              </CardContent>
            </Card>

            <Card className={`border ${itr.old_regime.total_tax < itr.new_regime.total_tax ? "border-emerald-500/30 bg-emerald-500/5" : "border-border/40 bg-card/60"}`}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Old Regime Tax</CardTitle>
                {itr.old_regime.total_tax < itr.new_regime.total_tax && <CheckCircle2 className="w-4 h-4 text-emerald-500" />}
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-foreground">{formatLakh(itr.old_regime.total_tax)}</div>
                <p className="text-xs text-muted-foreground mt-1">Taxable income: {formatLakh(itr.old_regime.taxable_income)}</p>
                {itr.old_regime.rebate_87a > 0 && (
                  <Badge className="text-[10px] mt-1.5 bg-emerald-500/15 text-emerald-600 border-0">87A Rebate Applied</Badge>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Main 3-column detailed breakdown */}
          <div className="grid gap-6 lg:grid-cols-3">
            {/* Trading & Capital Gains breakdown */}
            <Card className="border border-border/40 shadow-sm lg:col-span-1">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base font-bold">
                  <BarChart3 className="w-4 h-4 text-indigo-500" /> Trading & Capital Gains
                </CardTitle>
                <CardDescription>Classified by income head for ITR filing</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                {[
                  {
                    label: "Speculative Intraday P&L",
                    sublabel: "Sec 43(5) — Business Income Head",
                    val: itr.trading_summary.speculative_intraday_pnl,
                    color: "rose",
                    note: "Taxed at slab rate",
                  },
                  {
                    label: "F&O Trading P&L",
                    sublabel: "Non-Speculative — Business Income Head",
                    val: itr.trading_summary.non_speculative_fo_pnl,
                    color: "indigo",
                    note: "Taxed at slab rate",
                  },
                  {
                    label: "Short-Term Capital Gains",
                    sublabel: "Sec 111A (listed equity/MF < 1 year)",
                    val: itr.trading_summary.stcg_pnl,
                    color: "amber",
                    note: "@ 20% flat",
                  },
                  {
                    label: "Long-Term Capital Gains",
                    sublabel: "Sec 112A (equity/MF > 1 year)",
                    val: itr.trading_summary.ltcg_pnl,
                    color: "emerald",
                    note: "@ 12.5% on gains > ₹1.25L",
                  },
                  {
                    label: "Crypto P&L",
                    sublabel: "Sec 115BBH — Virtual Digital Assets",
                    val: itr.trading_summary.crypto_pnl,
                    color: "purple",
                    note: "@ 30% flat, no deductions",
                  },
                ].map(({ label, sublabel, val, note }) => (
                  <div key={label} className="flex items-start justify-between p-3 rounded-xl bg-muted/30 border border-border/40 gap-2">
                    <div className="min-w-0">
                      <p className="text-xs font-semibold text-foreground leading-snug">{label}</p>
                      <p className="text-[10px] text-muted-foreground mt-0.5">{sublabel}</p>
                      <p className="text-[10px] text-blue-600 dark:text-blue-400 mt-0.5 font-medium">{note}</p>
                    </div>
                    <span className={`text-sm font-bold flex-shrink-0 ${val >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                      {val >= 0 ? "+" : ""}{formatLakh(val)}
                    </span>
                  </div>
                ))}
              </CardContent>
            </Card>

            {/* Deductions */}
            <Card className="border border-border/40 shadow-sm lg:col-span-1">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base font-bold">
                  <ShieldCheck className="w-4 h-4 text-teal-500" /> Deductions & Exemptions
                </CardTitle>
                <CardDescription>Applicable under Old Regime only (unless noted)</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                {[
                  {
                    section: "Standard Deduction (New Regime)",
                    val: itr.deductions.standard_deduction_new,
                    max: "₹75,000",
                    regime: "New",
                  },
                  {
                    section: "Standard Deduction (Old Regime)",
                    val: itr.deductions.standard_deduction_old,
                    max: "₹50,000",
                    regime: "Old",
                  },
                  {
                    section: "Section 80C (ELSS + Home Loan Principal)",
                    val: itr.deductions.section_80c,
                    max: "Max ₹1,50,000",
                    regime: "Old",
                  },
                  {
                    section: "Section 24(b) Home Loan Interest",
                    val: itr.deductions.section_24b_home_loan_interest,
                    max: "Max ₹2,00,000",
                    regime: "Old",
                  },
                ].map(({ section, val, max, regime }) => (
                  <div key={section} className="flex items-start justify-between p-3 rounded-xl bg-muted/30 border border-border/40 gap-2">
                    <div className="min-w-0">
                      <p className="text-xs font-semibold text-foreground leading-snug">{section}</p>
                      <p className="text-[10px] text-muted-foreground mt-0.5">{max}</p>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className="text-sm font-bold text-teal-600 dark:text-teal-400">−{formatLakh(val)}</p>
                      <Badge variant="outline" className={`text-[9px] mt-0.5 ${regime === "New" ? "border-blue-300 text-blue-600" : "border-orange-300 text-orange-600"}`}>
                        {regime} Regime
                      </Badge>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>

            {/* Special taxes and slab comparison */}
            <Card className="border border-border/40 shadow-sm lg:col-span-1">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base font-bold">
                  <Receipt className="w-4 h-4 text-rose-500" /> Special Tax Levies
                </CardTitle>
                <CardDescription>Additional taxes on capital gains and crypto — applicable in both regimes</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-start justify-between p-3 rounded-xl bg-rose-500/5 border border-rose-500/20">
                  <div>
                    <p className="text-xs font-semibold text-foreground">STCG Tax (Sec 111A)</p>
                    <p className="text-[10px] text-muted-foreground">Listed equity & MF STCG @ 20%</p>
                  </div>
                  <span className="text-sm font-bold text-rose-600">{formatLakh(itr.special_taxes.stcg_tax_sec111a)}</span>
                </div>

                <div className="flex items-start justify-between p-3 rounded-xl bg-amber-500/5 border border-amber-500/20">
                  <div>
                    <p className="text-xs font-semibold text-foreground">LTCG Tax (Sec 112A)</p>
                    <p className="text-[10px] text-muted-foreground">Gains above ₹1.25L @ 12.5%</p>
                  </div>
                  <span className="text-sm font-bold text-amber-600">{formatLakh(itr.special_taxes.ltcg_tax_sec112a)}</span>
                </div>

                <div className="flex items-start justify-between p-3 rounded-xl bg-purple-500/5 border border-purple-500/20">
                  <div>
                    <p className="text-xs font-semibold text-foreground">Crypto Tax (Sec 115BBH)</p>
                    <p className="text-[10px] text-muted-foreground">VDA gains @ 30% flat</p>
                  </div>
                  <span className="text-sm font-bold text-purple-600">{formatLakh(itr.special_taxes.crypto_tax_sec115bbh)}</span>
                </div>

                {/* Regime Comparison Table */}
                <div className="mt-4 pt-3 border-t border-border/40 space-y-2">
                  <p className="text-xs font-bold text-foreground uppercase tracking-wide">Regime Comparison</p>
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="p-2.5 rounded-lg bg-blue-500/10 border border-blue-500/20 text-center">
                      <p className="text-[10px] text-muted-foreground font-medium">New Regime</p>
                      <p className="text-base font-bold text-foreground mt-0.5">{formatLakh(itr.new_regime.total_tax)}</p>
                      <p className="text-[10px] text-muted-foreground">incl. cess + special taxes</p>
                    </div>
                    <div className="p-2.5 rounded-lg bg-orange-500/10 border border-orange-500/20 text-center">
                      <p className="text-[10px] text-muted-foreground font-medium">Old Regime</p>
                      <p className="text-base font-bold text-foreground mt-0.5">{formatLakh(itr.old_regime.total_tax)}</p>
                      <p className="text-[10px] text-muted-foreground">incl. cess + special taxes</p>
                    </div>
                  </div>
                  <div className={`p-2.5 rounded-lg text-center text-xs font-semibold ${
                    itr.recommendation.best_regime === "New Tax Regime"
                      ? "bg-emerald-500/10 border border-emerald-500/30 text-emerald-700 dark:text-emerald-300"
                      : "bg-orange-500/10 border border-orange-500/30 text-orange-700 dark:text-orange-300"
                  }`}>
                    <Sparkles className="w-3 h-3 inline mr-1" />
                    {itr.recommendation.best_regime} saves you {formatLakh(itr.recommendation.tax_saved)}
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* ITR Form Guide */}
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base font-bold">
                <BookOpen className="w-4 h-4 text-blue-500" /> ITR Form Guide & Filing Checklist
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4 md:grid-cols-3">
                {[
                  {
                    form: "ITR-1 (Sahaj)",
                    forWho: "Salary only, no capital gains, no F&O",
                    applicable: itr.recommendation.itr_form.includes("ITR-1"),
                    docs: ["Form 16 from employer", "Bank interest certificates", "AIS / 26AS"],
                  },
                  {
                    form: "ITR-2",
                    forWho: "Salary + STCG/LTCG + Crypto — no business income",
                    applicable: itr.recommendation.itr_form.includes("ITR-2"),
                    docs: ["Form 16", "Broker P&L Statement", "Capital Gains Statement", "AIS / 26AS"],
                  },
                  {
                    form: "ITR-3",
                    forWho: "Salary + F&O / Speculative Trading (Business Income)",
                    applicable: itr.recommendation.itr_form.includes("ITR-3"),
                    docs: ["Form 16", "Detailed F&O P&L", "Books of accounts", "Audit if turnover > ₹1Cr", "AIS / 26AS"],
                  },
                ].map(({ form, forWho, applicable, docs }) => (
                  <div
                    key={form}
                    className={`p-4 rounded-xl border transition-all ${
                      applicable
                        ? "border-emerald-500/40 bg-emerald-500/8 ring-1 ring-emerald-500/20"
                        : "border-border/40 bg-muted/20 opacity-70"
                    }`}
                  >
                    <div className="flex items-center gap-2 mb-2">
                      <h4 className="font-bold text-foreground">{form}</h4>
                      {applicable && (
                        <Badge className="bg-emerald-500 text-white text-[10px] font-bold">Your Form</Badge>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground mb-3">{forWho}</p>
                    <ul className="space-y-1">
                      {docs.map((doc) => (
                        <li key={doc} className="flex items-center gap-1.5 text-xs text-foreground">
                          <CheckCircle2 className="w-3 h-3 text-teal-500 flex-shrink-0" />
                          {doc}
                        </li>
                      ))}
                    </ul>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </>
      ) : null}
    </div>
  );
}
