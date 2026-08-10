import { useState, useEffect } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Edit3 } from "lucide-react";
import type { EmiScheduleItem } from "@/types";

type Props = {
  installment: EmiScheduleItem | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (scheduleId: number, data: Partial<EmiScheduleItem>) => void;
  isPending: boolean;
};

export function EditInstallmentDialog({ installment, open, onOpenChange, onSave, isPending }: Props) {
  const [form, setForm] = useState({
    dueDate: "",
    emiAmount: "",
    principalComponent: "",
    interestComponent: "",
    status: "pending",
    paidOn: "",
  });

  useEffect(() => {
    if (installment) {
      setForm({
        dueDate: installment.dueDate ? String(installment.dueDate).split("T")[0] : "",
        emiAmount: String(installment.emiAmount || installment.amount || ""),
        principalComponent: String(installment.principalComponent || installment.principalAmount || ""),
        interestComponent: String(installment.interestComponent || installment.interestAmount || ""),
        status: installment.status || (installment.isPaid ? "paid" : "pending"),
        paidOn: installment.paidOn ? String(installment.paidOn).split("T")[0] : "",
      });
    }
  }, [installment]);

  const handleSave = () => {
    if (!installment) return;
    onSave(installment.id, {
      dueDate: form.dueDate,
      emiAmount: parseFloat(form.emiAmount) || 0,
      principalComponent: parseFloat(form.principalComponent) || 0,
      interestComponent: parseFloat(form.interestComponent) || 0,
      status: form.status as "pending" | "paid" | "overdue",
      paidOn: form.status === "paid" ? form.paidOn || form.dueDate : null,
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-base">
            <Edit3 className="w-4 h-4 text-primary" />
            Edit Installment #{installment?.installmentNumber || installment?.emiNumber}
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-3 py-2 text-sm">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label className="text-xs">Due Date</Label>
              <Input
                type="date"
                value={form.dueDate}
                onChange={(e) => setForm({ ...form, dueDate: e.target.value })}
                className="h-8 text-xs"
              />
            </div>
            <div>
              <Label className="text-xs">Total EMI (₹)</Label>
              <Input
                type="number"
                value={form.emiAmount}
                onChange={(e) => setForm({ ...form, emiAmount: e.target.value })}
                className="h-8 text-xs font-mono"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label className="text-xs">Principal (₹)</Label>
              <Input
                type="number"
                value={form.principalComponent}
                onChange={(e) => setForm({ ...form, principalComponent: e.target.value })}
                className="h-8 text-xs font-mono text-green-600"
              />
            </div>
            <div>
              <Label className="text-xs">Interest (₹)</Label>
              <Input
                type="number"
                value={form.interestComponent}
                onChange={(e) => setForm({ ...form, interestComponent: e.target.value })}
                className="h-8 text-xs font-mono text-orange-600"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label className="text-xs">Status</Label>
              <Select value={form.status} onValueChange={(v) => setForm({ ...form, status: v })}>
                <SelectTrigger className="h-8 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="pending">Pending</SelectItem>
                  <SelectItem value="paid">Paid</SelectItem>
                  <SelectItem value="overdue">Overdue</SelectItem>
                </SelectContent>
              </Select>
            </div>
            {form.status === "paid" && (
              <div>
                <Label className="text-xs">Paid On</Label>
                <Input
                  type="date"
                  value={form.paidOn}
                  onChange={(e) => setForm({ ...form, paidOn: e.target.value })}
                  className="h-8 text-xs"
                />
              </div>
            )}
          </div>
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button type="button" onClick={handleSave} disabled={isPending}>
            {isPending ? "Saving..." : "Save Installment"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
