import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Button } from "@/components/ui/button";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { Gavel, AlertCircle, CircleDollarSign, Building2, CheckCircle2 } from "lucide-react";
import type { PipelineEntry } from "@/types";

const STAGE_META: Record<string, { label: string; className: string; icon: React.ReactNode }> = {
  legal_opportunity: { label: "Stage 1 · Legal", className: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300", icon: <Gavel className="w-3 h-3" /> },
  small_balance: { label: "Stage 2 · Small", className: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300", icon: <CircleDollarSign className="w-3 h-3" /> },
  medium_balance: { label: "Stage 3 · Medium", className: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300", icon: <Building2 className="w-3 h-3" /> },
  large_unsecured: { label: "Stage 4 · Large", className: "bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-300", icon: <AlertCircle className="w-3 h-3" /> },
};

const fmt = (val: number) => `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

export function StageBadge({ stage }: { stage: string }) {
  const meta = STAGE_META[stage] ?? STAGE_META.large_unsecured;
  return (
    <Badge variant="outline" className={`gap-1 border-transparent ${meta.className}`}>
      {meta.icon}
      {meta.label}
    </Badge>
  );
}

export function PipelineTable({
  pipeline,
  onContribute,
}: {
  pipeline: PipelineEntry[];
  onContribute: (caseId: number, name: string) => void;
}) {
  if (!pipeline.length) {
    return (
      <div className="py-10 text-center text-muted-foreground">
        No open settlement cases yet. Add a settlement debt account and open a case to build your pipeline.
      </div>
    );
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>#</TableHead>
          <TableHead>Account</TableHead>
          <TableHead>Stage</TableHead>
          <TableHead className="text-right">Claim</TableHead>
          <TableHead className="text-right">Est. Total</TableHead>
          <TableHead className="w-[160px]">Funding</TableHead>
          <TableHead className="text-center">Score</TableHead>
          <TableHead></TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {pipeline.map((entry, idx) => (
          <TableRow key={entry.settlementCaseId}>
            <TableCell className="font-mono text-muted-foreground">{idx + 1}</TableCell>
            <TableCell>
              <div className="font-medium">{entry.name}</div>
              <div className="text-xs text-muted-foreground">{entry.lender} · {entry.status.replace(/_/g, " ")}</div>
            </TableCell>
            <TableCell><StageBadge stage={entry.stage} /></TableCell>
            <TableCell className="text-right font-mono">{fmt(entry.claim)}</TableCell>
            <TableCell className="text-right font-mono">{fmt(entry.estimatedTotal)}</TableCell>
            <TableCell>
              <div className="flex items-center gap-2">
                <Progress value={entry.fundingProgress} className="h-2" />
                <span className="text-xs font-mono w-12 text-right">{entry.fundingProgress}%</span>
              </div>
              {entry.eligible && (
                <span className="mt-1 inline-flex items-center gap-1 text-xs text-emerald-600 font-medium">
                  <CheckCircle2 className="w-3 h-3" /> Eligible to negotiate
                </span>
              )}
            </TableCell>
            <TableCell className="text-center">
              <span className="font-mono font-semibold">{entry.score}</span>
            </TableCell>
            <TableCell className="text-right">
              <Button size="sm" variant="outline" onClick={() => onContribute(entry.settlementCaseId, entry.name)}>
                Fund
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
