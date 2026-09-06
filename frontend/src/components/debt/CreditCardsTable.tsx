import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { ArrowUpRight, AlertTriangle, CheckCircle, CreditCard as CardIcon } from "lucide-react";
import type { DebtAccount } from "@/types";

const fmt = (val: number | null | undefined) =>
  val == null ? "—" : `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

function StatusBadge({ status, bureauStatus }: { status: string; bureauStatus?: string | null }) {
  const label = bureauStatus || status.replace(/_/g, " ");
  if (label.includes("Written-Off") || label.includes("Sold to ARC")) {
    return <Badge variant="outline" className="bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-950 dark:text-amber-300">{label}</Badge>;
  }
  if (label.includes("Default") || label.includes("SUIT")) {
    return <Badge variant="outline" className="bg-red-100 text-red-800 border-red-300 dark:bg-red-950 dark:text-red-300">{label}</Badge>;
  }
  if (label.includes("Delinquent")) {
    return <Badge variant="outline" className="bg-orange-100 text-orange-800 border-orange-300 dark:bg-orange-950 dark:text-orange-300">{label}</Badge>;
  }
  if (label.includes("CLOSED") || label.includes("Closed")) {
    return <Badge variant="outline" className="bg-slate-100 text-slate-700 border-slate-300 dark:bg-slate-800 dark:text-slate-400">{label}</Badge>;
  }
  return <Badge variant="outline">{label}</Badge>;
}

export function CreditCardsTable({
  accounts,
  onOpenCase,
}: {
  accounts: DebtAccount[];
  onOpenCase: (caseId: number) => void;
}) {
  const cards = accounts.filter((a) => a.debtType === "credit_card");

  if (!cards.length) {
    return (
      <div className="py-10 text-center text-muted-foreground">
        No credit cards found in the registry.
      </div>
    );
  }

  const totalLimit = cards.reduce((sum, c) => sum + (c.creditLimit || 0), 0);
  const totalBalance = cards.reduce((sum, c) => sum + (c.currentBalance || 0), 0);
  const totalOverdue = cards.reduce((sum, c) => sum + (c.overdueAmount || 0), 0);
  const aggregateUtil = totalLimit > 0 ? ((totalBalance / totalLimit) * 100).round?.(1) ?? Math.round((totalBalance / totalLimit) * 1000) / 10 : 0;

  return (
    <div className="space-y-4">
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Card & Issuer</TableHead>
              <TableHead className="text-right">Credit Limit</TableHead>
              <TableHead className="text-right">Current Balance</TableHead>
              <TableHead className="text-right">Overdue Amt</TableHead>
              <TableHead className="text-center">Utilisation</TableHead>
              <TableHead className="text-center">Billing Days</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {cards.map((c) => {
              const isOverLimit = c.overLimit || (c.creditLimit > 0 && c.currentBalance > c.creditLimit);
              const util = c.utilizationPercentage || (c.creditLimit > 0 ? Math.round((c.currentBalance / c.creditLimit) * 1000) / 10 : 0);

              return (
                <TableRow key={c.id}>
                  <TableCell>
                    <div className="font-medium flex items-center gap-1.5">
                      <CardIcon className="w-4 h-4 text-muted-foreground shrink-0" />
                      {c.name}
                    </div>
                    <div className="text-xs text-muted-foreground">{c.lender}</div>
                  </TableCell>
                  <TableCell className="text-right font-mono">{fmt(c.creditLimit)}</TableCell>
                  <TableCell className="text-right font-mono font-semibold">{fmt(c.currentBalance)}</TableCell>
                  <TableCell className="text-right font-mono text-destructive font-semibold">
                    {c.overdueAmount > 0 ? fmt(c.overdueAmount) : "₹0"}
                  </TableCell>
                  <TableCell className="text-center">
                    {c.creditLimit > 0 ? (
                      <div className="inline-flex items-center gap-1">
                        <span className={`text-xs font-mono font-bold ${isOverLimit ? "text-destructive" : "text-muted-foreground"}`}>
                          {util}%
                        </span>
                        {isOverLimit && <AlertTriangle className="w-3.5 h-3.5 text-destructive" title="Over credit limit!" />}
                      </div>
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </TableCell>
                  <TableCell className="text-center text-xs text-muted-foreground">
                    Stmt: {c.statementDay ?? "—"} | Due: {c.dueDay ?? "—"}
                  </TableCell>
                  <TableCell>
                    <StatusBadge status={c.status} bureauStatus={c.bureauStatus} />
                  </TableCell>
                  <TableCell className="text-right">
                    {c.openCaseId ? (
                      <Button size="sm" variant="ghost" onClick={() => onOpenCase(c.openCaseId!)}>
                        Case <ArrowUpRight className="w-3 h-3 ml-1" />
                      </Button>
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </TableCell>
                </TableRow>
              );
            })}

            {/* Aggregated Totals Row */}
            <TableRow className="bg-muted/50 font-bold border-t-2">
              <TableCell>Total Credit Cards ({cards.length})</TableCell>
              <TableCell className="text-right font-mono">{fmt(totalLimit)}</TableCell>
              <TableCell className="text-right font-mono text-destructive">{fmt(totalBalance)}</TableCell>
              <TableCell className="text-right font-mono text-destructive">{fmt(totalOverdue)}</TableCell>
              <TableCell className="text-center font-mono">{aggregateUtil}%</TableCell>
              <TableCell colSpan={3} className="text-right text-xs text-muted-foreground">
                Reconciled against CRIF High Mark (Sept 2026)
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
