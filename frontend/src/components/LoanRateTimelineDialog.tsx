import { useState, useEffect } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Trash2, TrendingUp, Layers } from "lucide-react";
import type { LoanDetail, RateRevision, DisbursementTranche } from "@/types";

type Props = {
  loan: LoanDetail | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (data: { rateRevisions: RateRevision[]; disbursements: DisbursementTranche[] }) => void;
  isPending: boolean;
};

export function LoanRateTimelineDialog({ loan, open, onOpenChange, onSave, isPending }: Props) {
  const [rates, setRates] = useState<RateRevision[]>([]);
  const [disbursements, setDisbursements] = useState<DisbursementTranche[]>([]);

  useEffect(() => {
    if (loan) {
      setRates(
        loan.rateRevisions?.length
          ? [...loan.rateRevisions]
          : [{ effectiveDate: loan.startDate, interestRate: parseFloat(loan.interestRate), strategy: "adjust_tenure" }]
      );
      setDisbursements(
        loan.disbursements?.length
          ? [...loan.disbursements]
          : [{ disbursedOn: loan.startDate, amount: parseFloat(loan.principalAmount), isPreEmi: false }]
      );
    }
  }, [loan]);

  const addRate = () => {
    setRates([...rates, { effectiveDate: new Date().toISOString().split("T")[0], interestRate: 8.5, strategy: "adjust_tenure" }]);
  };

  const removeRate = (idx: number) => {
    setRates(rates.filter((_, i) => i !== idx));
  };

  const updateRate = (idx: number, field: keyof RateRevision, val: any) => {
    const next = [...rates];
    next[idx] = { ...next[idx], [field]: val };
    setRates(next);
  };

  const addDisb = () => {
    setDisbursements([...disbursements, { disbursedOn: new Date().toISOString().split("T")[0], amount: 100000, isPreEmi: false }]);
  };

  const removeDisb = (idx: number) => {
    setDisbursements(disbursements.filter((_, i) => i !== idx));
  };

  const updateDisb = (idx: number, field: keyof DisbursementTranche, val: any) => {
    const next = [...disbursements];
    next[idx] = { ...next[idx], [field]: val };
    setDisbursements(next);
  };

  const handleSave = () => {
    onSave({ rateRevisions: rates, disbursements });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-primary" />
            Floating Rate & Disbursement Timeline
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-6 py-2">
          {/* Rate Revisions Section */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <Label className="text-sm font-semibold flex items-center gap-1.5">
                  <TrendingUp className="w-4 h-4 text-indigo-500" /> Floating Rate History (ROI)
                </Label>
                <p className="text-xs text-muted-foreground">Add rate revisions (e.g. 8.6% → 8.85% → 9.15% → 8.15%)</p>
              </div>
              <Button type="button" size="sm" variant="outline" onClick={addRate}>
                <Plus className="w-3.5 h-3.5 mr-1" /> Add Rate Reset
              </Button>
            </div>

            <div className="space-y-2">
              {rates.map((r, i) => (
                <div key={i} className="flex items-center gap-2 bg-muted/40 p-2.5 rounded-lg border">
                  <div className="flex-1">
                    <Label className="text-[11px] text-muted-foreground">Effective Date</Label>
                    <Input
                      type="date"
                      value={r.effectiveDate}
                      onChange={(e) => updateRate(i, "effectiveDate", e.target.value)}
                      className="h-8 text-xs"
                    />
                  </div>
                  <div className="w-28">
                    <Label className="text-[11px] text-muted-foreground">ROI (% p.a.)</Label>
                    <Input
                      type="number"
                      step="0.01"
                      value={r.interestRate}
                      onChange={(e) => updateRate(i, "interestRate", parseFloat(e.target.value) || 0)}
                      className="h-8 text-xs font-mono"
                    />
                  </div>
                  <div className="w-36">
                    <Label className="text-[11px] text-muted-foreground">Adjustment Mode</Label>
                    <Select
                      value={r.strategy || "adjust_tenure"}
                      onValueChange={(val) => updateRate(i, "strategy", val)}
                    >
                      <SelectTrigger className="h-8 text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="adjust_tenure">Keep EMI (Tenure)</SelectItem>
                        <SelectItem value="adjust_emi">Adjust EMI</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  {rates.length > 1 && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8 mt-4 text-red-500 hover:text-red-600"
                      onClick={() => removeRate(i)}
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Tranche Disbursements Section */}
          <div className="space-y-3 border-t pt-4">
            <div className="flex items-center justify-between">
              <div>
                <Label className="text-sm font-semibold flex items-center gap-1.5">
                  <Layers className="w-4 h-4 text-emerald-500" /> Tranche Disbursements
                </Label>
                <p className="text-xs text-muted-foreground">Record initial disbursals (e.g. ₹19L) and subsequent parts</p>
              </div>
              <Button type="button" size="sm" variant="outline" onClick={addDisb}>
                <Plus className="w-3.5 h-3.5 mr-1" /> Add Tranche
              </Button>
            </div>

            <div className="space-y-2">
              {disbursements.map((d, i) => (
                <div key={i} className="flex items-center gap-2 bg-muted/40 p-2.5 rounded-lg border">
                  <div className="flex-1">
                    <Label className="text-[11px] text-muted-foreground">Disbursal Date</Label>
                    <Input
                      type="date"
                      value={d.disbursedOn}
                      onChange={(e) => updateDisb(i, "disbursedOn", e.target.value)}
                      className="h-8 text-xs"
                    />
                  </div>
                  <div className="w-36">
                    <Label className="text-[11px] text-muted-foreground">Amount (₹)</Label>
                    <Input
                      type="number"
                      value={d.amount}
                      onChange={(e) => updateDisb(i, "amount", parseFloat(e.target.value) || 0)}
                      className="h-8 text-xs font-mono"
                    />
                  </div>
                  {disbursements.length > 1 && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8 mt-4 text-red-500 hover:text-red-600"
                      onClick={() => removeDisb(i)}
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>

        <DialogFooter className="border-t pt-3">
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button type="button" onClick={handleSave} disabled={isPending}>
            {isPending ? "Re-calculating..." : "Apply & Re-amortize"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
