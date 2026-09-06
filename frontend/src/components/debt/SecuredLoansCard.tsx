import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { ShieldCheck, Home, CheckCircle2 } from "lucide-react";
import type { DebtAccount } from "@/types";

const fmt = (val: number | null | undefined) =>
  val == null ? "—" : `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

export function SecuredLoansCard({ accounts }: { accounts: DebtAccount[] }) {
  const securedAccounts = accounts.filter((a) => a.classification === "serviced" && a.status !== "closed");
  const closedJanakalyan = accounts.find((a) => a.name.includes("Janakalyan"));

  const totalSecuredBalance = securedAccounts.reduce((sum, a) => sum + (a.currentBalance || 0), 0);
  const totalSecuredEmi = securedAccounts.reduce((sum, a) => sum + (a.monthlyCashflowDemand || a.monthlyObligation || 0), 0);

  return (
    <div className="space-y-6">
      {/* Overview Card */}
      <Card className="border-emerald-500/30 bg-emerald-500/5">
        <CardHeader className="pb-3">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
            <div>
              <CardTitle className="text-xl flex items-center gap-2 text-emerald-700 dark:text-emerald-400">
                <ShieldCheck className="w-6 h-6" />
                Protected Secured Assets (Non-Negotiable Priority)
              </CardTitle>
              <CardDescription>
                Zero overdue, 100% current repayment history. Must be serviced uninterrupted via auto-debits to protect primary real estate.
              </CardDescription>
            </div>
            <Badge className="bg-emerald-600 text-white font-mono">
              Total EMI: {fmt(totalSecuredEmi)}/mo
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="rounded-md border bg-card">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Asset / Facility</TableHead>
                  <TableHead className="text-right">Outstanding Principal</TableHead>
                  <TableHead className="text-right">Monthly EMI</TableHead>
                  <TableHead className="text-center">Interest (ROI)</TableHead>
                  <TableHead className="text-center">Remaining Tenure</TableHead>
                  <TableHead className="text-center">Auto-Debit Due</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {securedAccounts.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell>
                      <div className="font-semibold flex items-center gap-2">
                        <Home className="w-4 h-4 text-emerald-600" />
                        {a.name}
                      </div>
                      <div className="text-xs text-muted-foreground">{a.lender}</div>
                    </TableCell>
                    <TableCell className="text-right font-mono font-bold text-emerald-700 dark:text-emerald-400">
                      {fmt(a.currentBalance)}
                    </TableCell>
                    <TableCell className="text-right font-mono font-bold">
                      {fmt(a.monthlyCashflowDemand || a.monthlyObligation)}
                    </TableCell>
                    <TableCell className="text-center font-mono text-sm">
                      {a.interestRate ? `${a.interestRate}%` : "—"}
                    </TableCell>
                    <TableCell className="text-center font-mono text-sm">
                      {a.remainingTenureMonths ? `${a.remainingTenureMonths} mos` : a.tenureMonths ? `${a.tenureMonths} mos` : "—"}
                    </TableCell>
                    <TableCell className="text-center">
                      <Badge variant="secondary" className="font-mono text-xs">
                        {a.dueDay ? `${a.dueDay}th of month` : "Auto-Debit"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge className="bg-emerald-100 text-emerald-800 border-transparent dark:bg-emerald-950 dark:text-emerald-300">
                        100% Current
                      </Badge>
                    </TableCell>
                  </TableRow>
                ))}

                <TableRow className="bg-muted/40 font-bold border-t-2">
                  <TableCell>Total Secured Portfolio</TableCell>
                  <TableCell className="text-right font-mono text-emerald-700 dark:text-emerald-400">
                    {fmt(totalSecuredBalance)}
                  </TableCell>
                  <TableCell className="text-right font-mono text-emerald-700 dark:text-emerald-400">
                    {fmt(totalSecuredEmi)}
                  </TableCell>
                  <TableCell colSpan={4} className="text-right text-xs text-muted-foreground">
                    Direct auto-debits active on 3rd and 5th of each month
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>

          {/* Janakalyan Closure Victory Card */}
          {closedJanakalyan && (
            <div className="flex items-center gap-3 p-4 rounded-lg bg-emerald-500/10 border border-emerald-500/30 text-emerald-900 dark:text-emerald-200">
              <CheckCircle2 className="w-6 h-6 text-emerald-600 shrink-0" />
              <div className="text-sm">
                <span className="font-bold">Janakalyan Bank Home Loan Closed Upfront:</span>{" "}
                Successfully paid off from personal capital, permanently eliminating ₹8.29L in liabilities and freeing{" "}
                <strong className="underline decoration-emerald-500">₹20,000/month</strong> recurring cash flow into your settlement reserve!
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
