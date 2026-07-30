import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Progress } from "@/components/ui/progress";
import { IndianRupee, TrendingDown, Target, AlertCircle, CheckCircle2 } from "lucide-react";

export default function DebtPlanner() {
  const [strategy, setStrategy] = useState("avalanche");
  const [extraMonthly, setExtraMonthly] = useState(0);

  const { data: summary, isLoading } = useQuery({
    queryKey: ["debt", "summary"],
    queryFn: () => api.debtPlans.summary(),
  });

  const { data: simulation, isFetching: simLoading } = useQuery({
    queryKey: ["debt", "simulate", strategy, extraMonthly],
    queryFn: () => api.debtPlans.simulate({ strategy, extraMonthly }),
    enabled: !isLoading,
  });

  const formatCurrency = (val: number) =>
    new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(val);

  const payoffMonths = simulation && !simulation.error ? simulation.totalMonths : 0;
  const payoffYears = Math.floor(payoffMonths / 12);
  const payoffRemainingMonths = payoffMonths % 12;

  if (isLoading) {
    return (
      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        <Skeleton className="h-8 w-48" />
        <div className="grid gap-4 md:grid-cols-3">
          {[1, 2, 3].map(i => <Skeleton key={i} className="h-32 rounded-2xl" />)}
        </div>
        <Skeleton className="h-64 rounded-2xl" />
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold flex items-center gap-2">
            <Target className="w-6 h-6 text-primary" />
            Debt Payoff Planner
          </h2>
          <p className="text-sm text-muted-foreground">Avalanche vs Snowball — find your fastest path to debt freedom</p>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card className="glass-card border-red-500/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Total Outstanding</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-black text-red-500">{formatCurrency(summary?.totalOutstanding ?? 0)}</p>
            <div className="flex gap-2 mt-1 text-[11px] font-medium">
              <span className="text-amber-500">Secured: {formatCurrency(summary?.securedDebt ?? 0)}</span>
              <span className="text-red-500">Unsecured: {formatCurrency(summary?.unsecuredDebt ?? 0)}</span>
            </div>
          </CardContent>
        </Card>

        <Card className="glass-card border-amber-500/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Debt-to-Income Ratio</CardTitle>
          </CardHeader>
          <CardContent>
            <p className={`text-2xl font-black ${summary && summary.debtToIncomeRatio > 40 ? "text-red-500" : "text-amber-500"}`}>
              {summary?.debtToIncomeRatio ?? 0}%
            </p>
            <p className="text-[11px] text-muted-foreground mt-1">
              {summary && summary.debtToIncomeRatio > 40
                ? "High — above 40% is risky"
                : summary && summary.debtToIncomeRatio > 20
                ? "Moderate — keep reducing"
                : "Healthy — below 20%"}
            </p>
          </CardContent>
        </Card>

        <Card className="glass-card border-emerald-500/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Monthly Surplus</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-black text-emerald-500">{formatCurrency(summary?.monthlySurplus ?? 0)}</p>
            <p className="text-[11px] text-muted-foreground mt-1">Available for extra debt payments</p>
          </CardContent>
        </Card>
      </div>

      {/* Loan list */}
      {summary && summary.loans.length > 0 && (
        <Card className="glass-card">
          <CardHeader>
            <CardTitle className="text-sm font-bold">Your Loans</CardTitle>
            <CardDescription>{summary.loans.length} active loan{summary.loans.length > 1 ? "s" : ""}</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {summary.loans.map((loan) => (
                <div key={loan.id} className="flex items-center justify-between p-3 rounded-xl bg-card/50 border border-border/30">
                  <div className="space-y-1">
                    <p className="text-sm font-bold">{loan.name}</p>
                    <div className="flex gap-3 text-[10px] text-muted-foreground">
                      <span>{loan.type} @ {loan.rate}%</span>
                      <span>EMI: {formatCurrency(loan.emi)}</span>
                      <span>{loan.paidEmis}/{loan.tenure} paid</span>
                    </div>
                    <Progress value={(loan.paidEmis / loan.tenure) * 100} className="h-1.5 w-48" />
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-black text-red-500">{formatCurrency(loan.outstanding)}</p>
                    <p className="text-[10px] text-muted-foreground">{loan.remainingEmis} EMIs left</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Strategy selector + simulation */}
      <Card className="glass-card border-primary/10">
        <CardHeader>
          <CardTitle className="text-sm font-bold flex items-center gap-2">
            <TrendingDown className="w-4 h-4 text-primary" />
            Payoff Simulation
          </CardTitle>
          <CardDescription>Compare avalanche (highest rate first) vs snowball (smallest balance first)</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-4">
            <Button
              variant={strategy === "avalanche" ? "default" : "outline"}
              onClick={() => setStrategy("avalanche")}
              className="flex-1"
            >
              Avalanche — Highest Rate
            </Button>
            <Button
              variant={strategy === "snowball" ? "default" : "outline"}
              onClick={() => setStrategy("snowball")}
              className="flex-1"
            >
              Snowball — Smallest First
            </Button>
          </div>

          <div className="flex items-center gap-4">
            <label className="text-sm font-medium text-muted-foreground">Extra monthly payment:</label>
            <div className="flex items-center gap-2">
              <IndianRupee className="w-4 h-4 text-muted-foreground" />
              <input
                type="number"
                value={extraMonthly}
                onChange={(e) => setExtraMonthly(Number(e.target.value))}
                className="w-24 px-3 py-1.5 rounded-lg bg-card border border-border/50 text-sm"
                min={0}
                step={1000}
              />
              <span className="text-[11px] text-muted-foreground">/month</span>
            </div>
          </div>

          {simLoading ? (
            <Skeleton className="h-24 w-full rounded-xl" />
          ) : simulation && !simulation.error ? (
            <div className="grid gap-3 md:grid-cols-3">
              <div className="p-4 rounded-xl bg-primary/5 border border-primary/10 text-center">
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-bold">Payoff Time</p>
                <p className="text-xl font-black text-primary mt-1">
                  {payoffYears > 0 ? `${payoff}y ${payoffRemainingMonths}m` : `${payoffMonths} months`}
                </p>
                <p className="text-[10px] text-muted-foreground mt-1">by {simulation.projectedPayoffDate}</p>
              </div>
              <div className="p-4 rounded-xl bg-amber-500/5 border border-amber-500/10 text-center">
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-bold">Interest Paid</p>
                <p className="text-xl font-black text-amber-500 mt-1">{formatCurrency(simulation.totalInterestPaid)}</p>
              </div>
              <div className="p-4 rounded-xl bg-emerald-500/5 border border-emerald-500/10 text-center">
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-bold">Per Month</p>
                <p className="text-xl font-black text-emerald-500 mt-1">
                  {formatCurrency(
                    summary && summary.loans.length > 0
                      ? summary.loans.reduce((s, l) => s + l.emi, 0) + extraMonthly
                      : 0
                  )}
                </p>
              </div>
            </div>
          ) : simulation?.error ? (
            <div className="flex items-center gap-3 p-4 rounded-xl bg-amber-500/5 border border-amber-500/20">
              <AlertCircle className="w-5 h-5 text-amber-500" />
              <p className="text-sm text-muted-foreground">{simulation.error}</p>
            </div>
          ) : null}

          {summary && summary.loans.length === 0 && (
            <div className="flex items-center gap-3 p-4 rounded-xl bg-emerald-500/5 border border-emerald-500/20">
              <CheckCircle2 className="w-5 h-5 text-emerald-500" />
              <p className="text-sm text-emerald-600 font-medium">No active loans. You're debt-free!</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
