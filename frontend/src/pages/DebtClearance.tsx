import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { toast } from "sonner";
import {
  Shield, Swords, Wallet, CalendarCheck, Target, HandCoins, ArrowUpRight,
} from "lucide-react";
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";
import { PipelineTable } from "@/components/debt/PipelineTable";
import { SimulatorPanel } from "@/components/debt/SimulatorPanel";
import { CaseDetailDialog } from "@/components/debt/CaseDetailDialog";
import { AddDebtAccountDialog } from "@/components/debt/AddDebtAccountDialog";

const fmt = (val: number | null | undefined) =>
  val == null ? "—" : `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

const fmtDate = (d: string | null | undefined) =>
  d == null ? "—" : new Date(d).toLocaleDateString("en-IN", { month: "short", year: "numeric" });

export default function DebtClearance() {
  const queryClient = useQueryClient();
  const [openCaseId, setOpenCaseId] = useState<number | null>(null);
  const [caseDialogOpen, setCaseDialogOpen] = useState(false);
  const [fundCase, setFundCase] = useState<{ id: number; name: string } | null>(null);
  const [fundAmount, setFundAmount] = useState("");

  const { data: overview, isLoading } = useQuery({
    queryKey: ["debt-clearance", "overview"],
    queryFn: () => api.debtClearance.overview(),
  });

  const { data: accounts } = useQuery({
    queryKey: ["debt-clearance", "accounts"],
    queryFn: () => api.debtClearance.debtAccounts.list(),
  });

  const contribute = useMutation({
    mutationFn: () =>
      api.debtClearance.contributions.create(fundCase!.id, { amount: Number(fundAmount.replace(/[^0-9.]/g, "")) }),
    onSuccess: () => {
      toast.success("Contribution saved — the fund is growing");
      setFundAmount("");
      setFundCase(null);
      queryClient.invalidateQueries({ queryKey: ["debt-clearance"] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  if (isLoading || !overview) {
    return <div className="p-8 text-center text-muted-foreground">Loading debt clearance...</div>;
  }

  const { totals, cashflow } = overview;
  const openCase = (id: number) => { setOpenCaseId(id); setCaseDialogOpen(true); };

  const comparisonData = overview.scenarioComparison.map((s) => ({
    label: s.label,
    months: s.monthsUsed ?? 0,
    cost: s.totalSettlementCost,
    allocation: s.monthlyAllocation,
  }));

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-4">
        <div>
          <h1 className="text-3xl font-bold font-display tracking-tight flex items-center gap-2">
            <Swords className="w-8 h-8 text-primary" />
            Debt Clearance
          </h1>
          <p className="text-muted-foreground mt-1">
            Settlement pipeline, funding and the road to debt-free.
          </p>
        </div>
        <AddDebtAccountDialog />
      </div>

      {/* KPI row */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground">Total Debt</p>
            <p className="text-2xl font-black text-destructive">{fmt(totals.totalDebt)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground flex items-center justify-center gap-1">
              <Shield className="w-3 h-3" /> Protected
            </p>
            <p className="text-2xl font-black text-emerald-600">{fmt(totals.protectedDebt)}</p>
            <p className="text-xs text-muted-foreground">{totals.protectedAccounts} accounts</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground flex items-center justify-center gap-1">
              <Swords className="w-3 h-3" /> Settlement
            </p>
            <p className="text-2xl font-black text-amber-600">{fmt(totals.settlementDebt)}</p>
            <p className="text-xs text-muted-foreground">{totals.settlementAccounts} accounts</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground flex items-center justify-center gap-1">
              <Wallet className="w-3 h-3" /> Settlement Fund
            </p>
            <p className="text-2xl font-black text-primary">{fmt(overview.settlementFund)}</p>
            <p className="text-xs text-muted-foreground">of {fmt(overview.fundTarget)} needed</p>
          </CardContent>
        </Card>
        <Card className="bg-primary/10 border-primary/20">
          <CardContent className="p-4 text-center">
            <p className="text-xs uppercase font-bold tracking-wider text-primary/80 flex items-center justify-center gap-1">
              <CalendarCheck className="w-3 h-3" /> Debt-Free By
            </p>
            <p className="text-2xl font-black text-primary">{fmtDate(overview.estimatedDebtFreeOn)}</p>
            <p className="text-xs text-primary/70">est. cost {fmt(overview.totalSettlementCost)}</p>
          </CardContent>
        </Card>
      </div>

      {/* Next settlement banner */}
      {overview.nextSettlement && (
        <Card className="border-primary/30 bg-primary/5">
          <CardContent className="p-4 flex flex-col sm:flex-row sm:items-center gap-3">
            <Target className="w-6 h-6 text-primary shrink-0" />
            <div className="flex-1">
              <p className="font-semibold">Next target: {overview.nextSettlement.name} ({overview.nextSettlement.lender})</p>
              <p className="text-sm text-muted-foreground">
                Claim {fmt(overview.nextSettlement.claim)} · est. total cost {fmt(overview.nextSettlement.estimatedTotal)} ·
                {" "}{overview.nextSettlement.eligible ? "ready to negotiate" : `keep funding (${overview.nextSettlement.fundingProgress}%)`}
              </p>
            </div>
            <Button variant="outline" size="sm" onClick={() => openCase(overview.nextSettlement!.settlementCaseId)}>
              Open case <ArrowUpRight className="w-4 h-4 ml-1" />
            </Button>
          </CardContent>
        </Card>
      )}

      <Tabs defaultValue="pipeline" className="space-y-4">
        <TabsList className="grid w-full grid-cols-4 max-w-2xl">
          <TabsTrigger value="pipeline">Pipeline</TabsTrigger>
          <TabsTrigger value="cashflow">Cashflow</TabsTrigger>
          <TabsTrigger value="simulator">Simulator</TabsTrigger>
          <TabsTrigger value="accounts">Accounts</TabsTrigger>
        </TabsList>

        {/* Pipeline */}
        <TabsContent value="pipeline" className="space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Settlement Queue</CardTitle>
              <CardDescription>
                Stage 1 legal opportunities first, then quick small wins, medium and large accounts.
                Score blends readiness, cost, size, cashflow impact, legal status and age.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <PipelineTable
                pipeline={overview.pipeline}
                onContribute={(id, name) => { setFundCase({ id, name }); setFundAmount(""); }}
              />
            </CardContent>
          </Card>

          {overview.recentContributions.length > 0 && (
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-lg flex items-center gap-2">
                  <HandCoins className="w-5 h-5 text-primary" /> Recent contributions
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-2">
                  {overview.recentContributions.map((c) => (
                    <Badge key={c.id} variant="secondary" className="font-mono">
                      {c.contributedOn}: {fmt(c.amount)} → case #{c.settlementCaseId}
                    </Badge>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        {/* Cashflow + forecast */}
        <TabsContent value="cashflow" className="grid gap-6 lg:grid-cols-2">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Monthly cashflow split</CardTitle>
              {cashflow.scenarioName && (
                <CardDescription>Driven by the “{cashflow.scenarioName}” income scenario</CardDescription>
              )}
            </CardHeader>
            <CardContent className="space-y-3">
              <CashRow label="Income" value={cashflow.income} />
              <CashRow label="Essential commitments" value={cashflow.commitments} />
              <CashRow label="Emergency buffer" value={cashflow.emergencyBuffer} />
              <div className="border-t pt-3">
                <CashRow label="Available monthly surplus" value={cashflow.availableMonthlySurplus} strong />
              </div>
              <CashRow label="→ Settlement allocation" value={cashflow.settlementAllocation} strong />
              <CashRow label="Cash on hand (bank balances)" value={cashflow.cashOnHand} />
              <div className="rounded-lg bg-muted/50 p-3 text-sm">
                Projected settlement capital in {cashflow.projectedSettlementCapital.months} months:{" "}
                <strong>{fmt(cashflow.projectedSettlementCapital.amount)}</strong>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Scenario comparison</CardTitle>
              <CardDescription>Months to debt-free at each monthly allocation</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="h-[220px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={comparisonData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis dataKey="label" tick={{ fontSize: 12 }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontSize: 12 }} axisLine={false} tickLine={false} width={40} />
                    <Tooltip
                      formatter={(value: number, name: string) => (name === "months" ? [`${value} months`, "Time"] : [fmt(value), "Cost"])}
                      contentStyle={{ borderRadius: "8px" }}
                    />
                    <Bar dataKey="months" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Scenario</TableHead>
                    <TableHead className="text-right">Allocation</TableHead>
                    <TableHead className="text-right">Debt-free</TableHead>
                    <TableHead className="text-right">Total cost</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {overview.scenarioComparison.map((s) => (
                    <TableRow key={s.label}>
                      <TableCell className="font-medium">{s.label}</TableCell>
                      <TableCell className="text-right font-mono">{fmt(s.monthlyAllocation)}/mo</TableCell>
                      <TableCell className="text-right">{fmtDate(s.debtFreeOn)}</TableCell>
                      <TableCell className="text-right font-mono">{fmt(s.totalSettlementCost)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Simulator */}
        <TabsContent value="simulator">
          <SimulatorPanel />
        </TabsContent>

        {/* Accounts */}
        <TabsContent value="accounts">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Debt registry</CardTitle>
              <CardDescription>Every debt account — protected ones are serviced, settlement ones feed the pipeline</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Account</TableHead>
                    <TableHead>Class</TableHead>
                    <TableHead className="text-right">Outstanding</TableHead>
                    <TableHead className="text-right">Monthly</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {(accounts ?? []).map((a) => (
                    <TableRow key={a.id}>
                      <TableCell>
                        <div className="font-medium">{a.name}</div>
                        <div className="text-xs text-muted-foreground">{a.lender}{a.formalNotice ? " · formal notice" : ""}</div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline" className={a.classification === "settlement" ? "bg-amber-100 text-amber-700 border-transparent dark:bg-amber-950 dark:text-amber-300" : "bg-emerald-100 text-emerald-700 border-transparent dark:bg-emerald-950 dark:text-emerald-300"}>
                          {a.classification === "settlement" ? "Settlement" : "Protected"}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right font-mono">{fmt(a.currentBalance)}</TableCell>
                      <TableCell className="text-right font-mono">{fmt(a.monthlyCashflowDemand)}</TableCell>
                      <TableCell className="text-sm">{a.status.replace(/_/g, " ")}</TableCell>
                      <TableCell className="text-right">
                        {a.openCaseId && (
                          <Button size="sm" variant="ghost" onClick={() => openCase(a.openCaseId!)}>
                            Case <ArrowUpRight className="w-3 h-3 ml-1" />
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Case detail dialog */}
      <CaseDetailDialog
        caseId={openCaseId}
        open={caseDialogOpen}
        onOpenChange={(v) => { setCaseDialogOpen(v); if (!v) queryClient.invalidateQueries({ queryKey: ["debt-clearance"] }); }}
      />

      {/* Quick fund dialog */}
      {fundCase && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4" onClick={() => setFundCase(null)}>
          <Card className="w-full max-w-sm" onClick={(e) => e.stopPropagation()}>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <HandCoins className="w-5 h-5 text-primary" /> Fund {fundCase.name}
              </CardTitle>
              <CardDescription>Money saved here builds the settlement fund for this case.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-1.5">
                <Label htmlFor="fund-amount">Amount (₹)</Label>
                <Input
                  id="fund-amount"
                  autoFocus
                  value={fundAmount}
                  onChange={(e) => setFundAmount(e.target.value)}
                  placeholder="10000"
                  inputMode="numeric"
                  onKeyDown={(e) => e.key === "Enter" && fundAmount && contribute.mutate()}
                />
              </div>
              <div className="flex justify-end gap-2">
                <Button variant="outline" size="sm" onClick={() => setFundCase(null)}>Cancel</Button>
                <Button size="sm" disabled={!fundAmount || contribute.isPending} onClick={() => contribute.mutate()}>
                  Save contribution
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}

function CashRow({ label, value, strong }: { label: string; value: number; strong?: boolean }) {
  return (
    <div className={`flex justify-between items-center text-sm ${strong ? "font-semibold" : ""}`}>
      <span className="text-muted-foreground">{label}</span>
      <span className={`font-mono ${strong ? "text-base" : ""}`}>{fmt(value)}</span>
    </div>
  );
}
