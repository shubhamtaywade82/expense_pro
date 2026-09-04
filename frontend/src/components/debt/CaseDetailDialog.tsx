import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { toast } from "sonner";
import { HandCoins, FileSignature, BadgeCheck } from "lucide-react";

const fmt = (val: number) => `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

export function CaseDetailDialog({
  caseId,
  open,
  onOpenChange,
}: {
  caseId: number | null;
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const queryClient = useQueryClient();
  const [offerPct, setOfferPct] = useState("30");
  const [contribution, setContribution] = useState("");

  const { data: c } = useQuery({
    queryKey: ["debt-clearance", "case", caseId],
    queryFn: () => api.debtClearance.settlementCases.show(caseId!),
    enabled: open && caseId != null,
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["debt-clearance"] });
  };

  const addOffer = useMutation({
    mutationFn: () =>
      api.debtClearance.offers.create(caseId!, {
        claimAmount: c!.currentClaim,
        settlementPercentage: Number(offerPct),
      }),
    onSuccess: () => { toast.success("Offer recorded with fee/GST breakdown"); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  const acceptOffer = useMutation({
    mutationFn: (offerId: number) => api.debtClearance.offers.accept(caseId!, offerId),
    onSuccess: () => { toast.success("Offer accepted"); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  const addContribution = useMutation({
    mutationFn: () =>
      api.debtClearance.contributions.create(caseId!, { amount: Number(contribution.replace(/[^0-9.]/g, "")) }),
    onSuccess: () => { toast.success("Contribution saved to settlement fund"); setContribution(""); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  const recordPayment = useMutation({
    mutationFn: (offerId?: number) =>
      api.debtClearance.settlementCases.recordPayment(caseId!, { settlementOfferId: offerId }),
    onSuccess: () => { toast.success("Settlement payment recorded — account closed"); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  if (!c) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {c.debtAccount.name}
            <Badge variant="outline">{c.status.replace(/_/g, " ")}</Badge>
          </DialogTitle>
          <DialogDescription>
            {c.debtAccount.lender} · claim {fmt(c.currentClaim)} · terms {c.targetMinPercentage}–{c.targetMaxPercentage}%,
            fee {c.serviceFeePercentage}%, GST {c.gstPercentage}%
          </DialogDescription>
        </DialogHeader>

        {/* Fund state */}
        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">Settlement fund: <strong className="text-foreground">{fmt(c.settlementFund)}</strong> of est. {fmt(c.estimatedTotal)}</span>
            <span className="font-mono">{c.fundingProgress}% {c.eligible && "· eligible"}</span>
          </div>
          <Progress value={c.fundingProgress} className="h-2.5" />
          <div className="flex gap-2 pt-1">
            <Input
              value={contribution}
              onChange={(e) => setContribution(e.target.value)}
              placeholder="Add to settlement fund (₹)"
              inputMode="numeric"
              className="flex-1"
            />
            <Button variant="outline" disabled={!contribution || addContribution.isPending} onClick={() => addContribution.mutate()}>
              <HandCoins className="w-4 h-4 mr-1" /> Save
            </Button>
          </div>
        </div>

        {/* Scenario ladder */}
        <div>
          <h4 className="text-sm font-semibold mb-2 flex items-center gap-2">
            <FileSignature className="w-4 h-4 text-primary" /> Scenario ladder (what each level really costs)
          </h4>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Settlement</TableHead>
                <TableHead className="text-right">Amount</TableHead>
                <TableHead className="text-right">Fee</TableHead>
                <TableHead className="text-right">GST</TableHead>
                <TableHead className="text-right">Total</TableHead>
                <TableHead></TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {(c.scenarioTable ?? []).map((row) => (
                <TableRow key={row.settlementPercentage}>
                  <TableCell className="font-medium">{row.settlementPercentage}%</TableCell>
                  <TableCell className="text-right font-mono">{fmt(row.settlementAmount)}</TableCell>
                  <TableCell className="text-right font-mono">{fmt(row.serviceFee)}</TableCell>
                  <TableCell className="text-right font-mono">{fmt(row.gst)}</TableCell>
                  <TableCell className="text-right font-mono font-semibold">{fmt(row.total)}</TableCell>
                  <TableCell className="text-right">
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => { setOfferPct(String(row.settlementPercentage)); addOffer.mutate(); }}
                    >
                      Record offer
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>

        {/* Offers */}
        {(c.offers ?? []).length > 0 && (
          <div>
            <h4 className="text-sm font-semibold mb-2">Offers on the table</h4>
            <div className="space-y-2">
              {c.offers!.map((o) => (
                <div key={o.id} className="flex items-center gap-3 rounded-lg border p-3 text-sm">
                  <BadgeCheck className={`w-5 h-5 ${o.status === "accepted" ? "text-emerald-600" : "text-muted-foreground"}`} />
                  <div className="flex-1">
                    <span className="font-medium">{o.settlementPercentage}%</span> · {fmt(o.settlementAmount)} + fee {fmt(o.serviceFee)} + GST {fmt(o.gst)} = <strong>{fmt(o.totalAmount)}</strong>
                    <div className="text-xs text-muted-foreground">
                      {o.status} · {o.offeredOn}{o.validUntil ? ` · valid until ${o.validUntil}` : ""}
                    </div>
                  </div>
                  {o.status !== "accepted" && (
                    <div className="flex gap-2">
                      <Button size="sm" variant="outline" onClick={() => acceptOffer.mutate(o.id)}>Accept</Button>
                      <Button
                        size="sm"
                        variant="default"
                        disabled={recordPayment.isPending}
                        onClick={() => recordPayment.mutate(o.id)}
                      >
                        Pay &amp; close
                      </Button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex justify-end gap-2 border-t pt-3">
          <Button
            variant="destructive"
            size="sm"
            disabled={recordPayment.isPending}
            onClick={() => recordPayment.mutate(undefined)}
          >
            Record settlement payment (worst case {fmt(c.estimatedTotal)})
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
