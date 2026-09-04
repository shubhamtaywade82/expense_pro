import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { Wand2, ArrowRight, PartyPopper } from "lucide-react";
import { StageBadge } from "./PipelineTable";

const fmt = (val: number) => `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

export function SimulatorPanel() {
  const [amountInput, setAmountInput] = useState("100000");
  const [amount, setAmount] = useState<number | null>(null);

  const { data: sim, isFetching } = useQuery({
    queryKey: ["debt-clearance", "simulator", amount],
    queryFn: () => api.debtClearance.simulate(amount!),
    enabled: amount != null && amount > 0,
  });

  const run = () => setAmount(Number(amountInput.replace(/[^0-9.]/g, "")));

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Wand2 className="w-5 h-5 text-primary" />
            What can I settle with...?
          </CardTitle>
          <CardDescription>
            Enter the cash you can put on the table. ExpensePro walks the settlement queue
            cheapest-first (legal opportunities first) and fully settles every account it can fund.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col sm:flex-row gap-3 items-end">
          <div className="flex-1 w-full space-y-1.5">
            <Label htmlFor="sim-amount">Available capital (₹)</Label>
            <Input
              id="sim-amount"
              value={amountInput}
              onChange={(e) => setAmountInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && run()}
              placeholder="e.g. 100000"
              inputMode="numeric"
            />
          </div>
          <Button onClick={run} disabled={isFetching}>Run simulation</Button>
        </CardContent>
      </Card>

      {sim && (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <Card>
              <CardContent className="p-4 text-center">
                <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground">Accounts Eliminated</p>
                <p className="text-3xl font-black text-emerald-600">{sim.accountsEliminated}</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4 text-center">
                <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground">Debt Removed</p>
                <p className="text-3xl font-black text-primary">{fmt(sim.debtRemoved)}</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4 text-center">
                <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground">Cashflow Recovered</p>
                <p className="text-3xl font-black text-amber-500">{fmt(sim.monthlyCashflowRecovered)}<span className="text-sm font-normal">/mo</span></p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4 text-center">
                <p className="text-xs uppercase font-bold tracking-wider text-muted-foreground">Cash Remaining</p>
                <p className="text-3xl font-black">{fmt(sim.remainingCash)}</p>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Settlement plan for {fmt(sim.availableCash)}</CardTitle>
            </CardHeader>
            <CardContent>
              {sim.allocations.length ? (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Account</TableHead>
                      <TableHead>Stage</TableHead>
                      <TableHead className="text-right">Claim</TableHead>
                      <TableHead className="text-right">Settlement Cost</TableHead>
                      <TableHead className="text-right">EMI Released</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {sim.allocations.map((a) => (
                      <TableRow key={a.settlementCaseId}>
                        <TableCell className="font-medium">{a.name}</TableCell>
                        <TableCell><StageBadge stage={a.stage} /></TableCell>
                        <TableCell className="text-right font-mono">{fmt(a.claim)}</TableCell>
                        <TableCell className="text-right font-mono text-emerald-600">{fmt(a.settlementCost)}</TableCell>
                        <TableCell className="text-right font-mono">{fmt(a.cashflowReleased)}/mo</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              ) : (
                <p className="py-6 text-center text-muted-foreground">
                  Not enough cash to fully settle the first account in the queue yet.
                </p>
              )}

              {sim.nextTarget && (
                <div className="mt-4 flex items-start gap-3 rounded-lg border bg-muted/40 p-4">
                  <PartyPopper className="w-5 h-5 text-primary mt-0.5" />
                  <div className="text-sm space-y-1">
                    <p className="font-medium">
                      Next target: {sim.nextTarget.name} — {fmt(sim.nextTarget.settlementCost)}
                    </p>
                    <p className="text-muted-foreground">
                      You are <strong>{fmt(sim.nextTarget.shortfall)}</strong> short.
                      {sim.nextTarget.monthsToFund != null && (
                        <> At your current allocation you get there in about <strong>{sim.nextTarget.monthsToFund} months</strong>.</>
                      )}
                    </p>
                  </div>
                  <ArrowRight className="w-4 h-4 ml-auto text-muted-foreground" />
                </div>
              )}
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}
