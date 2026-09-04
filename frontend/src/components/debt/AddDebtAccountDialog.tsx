import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";
import { Plus } from "lucide-react";

const DEBT_TYPES = [
  ["personal_loan", "Personal Loan"],
  ["credit_card", "Credit Card"],
  ["nbfc_loan", "NBFC / App Loan"],
  ["home_loan", "Home Loan"],
  ["auto_loan", "Auto Loan"],
  ["education_loan", "Education Loan"],
  ["gold_loan", "Gold Loan"],
  ["business_loan", "Business Loan"],
  ["other", "Other"],
];

export function AddDebtAccountDialog({ onCreated }: { onCreated?: (id: number) => void }) {
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    name: "",
    lender: "",
    debtType: "personal_loan",
    classification: "settlement",
    currentBalance: "",
    monthlyObligation: "",
    dpd: "0",
    formalNotice: false,
  });

  const create = useMutation({
    mutationFn: () =>
      api.debtClearance.debtAccounts.create({
        name: form.name,
        lender: form.lender,
        debtType: form.debtType,
        classification: form.classification,
        status: "current",
        currentBalance: Number(form.currentBalance.replace(/[^0-9.]/g, "")),
        originalPrincipal: Number(form.currentBalance.replace(/[^0-9.]/g, "")),
        monthlyObligation: form.monthlyObligation ? Number(form.monthlyObligation.replace(/[^0-9.]/g, "")) : 0,
        dpd: Number(form.dpd) || 0,
        formalNotice: form.formalNotice,
      } as never),
    onSuccess: async (account) => {
      toast.success(`${account.name} added to the debt registry`);
      queryClient.invalidateQueries({ queryKey: ["debt-clearance"] });
      if (form.classification === "settlement") {
        // Open a settlement case right away so the pipeline picks it up.
        await api.debtClearance.settlementCases.create({ debtAccountId: account.id });
        queryClient.invalidateQueries({ queryKey: ["debt-clearance"] });
      }
      onCreated?.(account.id);
      setOpen(false);
      setForm({ ...form, name: "", lender: "", currentBalance: "", monthlyObligation: "", dpd: "0", formalNotice: false });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button><Plus className="w-4 h-4 mr-1" /> Add debt account</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add a debt account</DialogTitle>
          <DialogDescription>
            Settlement accounts automatically get a settlement case and enter the pipeline.
            Protected accounts (home loan, etc.) are tracked as serviced debt.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-3">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>Account name</Label>
              <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="IDFC PL" />
            </div>
            <div className="space-y-1.5">
              <Label>Lender</Label>
              <Input value={form.lender} onChange={(e) => setForm({ ...form, lender: e.target.value })} placeholder="IDFC First Bank" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>Type</Label>
              <Select value={form.debtType} onValueChange={(v) => setForm({ ...form, debtType: v })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {DEBT_TYPES.map(([value, label]) => (
                    <SelectItem key={value} value={value}>{label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Classification</Label>
              <Select value={form.classification} onValueChange={(v) => setForm({ ...form, classification: v })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="settlement">Settlement target</SelectItem>
                  <SelectItem value="serviced">Protected (serviced)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div className="space-y-1.5">
              <Label>Outstanding (₹)</Label>
              <Input value={form.currentBalance} onChange={(e) => setForm({ ...form, currentBalance: e.target.value })} placeholder="64888" inputMode="numeric" />
            </div>
            <div className="space-y-1.5">
              <Label>EMI / min due (₹)</Label>
              <Input value={form.monthlyObligation} onChange={(e) => setForm({ ...form, monthlyObligation: e.target.value })} placeholder="0" inputMode="numeric" />
            </div>
            <div className="space-y-1.5">
              <Label>Days past due</Label>
              <Input value={form.dpd} onChange={(e) => setForm({ ...form, dpd: e.target.value })} inputMode="numeric" />
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Switch checked={form.formalNotice} onCheckedChange={(v) => setForm({ ...form, formalNotice: v })} id="formal-notice" />
            <Label htmlFor="formal-notice" className="font-normal">
              Formal / legal notice received (Lok Adalat, 138 notice...) — queues this account first
            </Label>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
          <Button disabled={!form.name || !form.currentBalance || create.isPending} onClick={() => create.mutate()}>
            {form.classification === "settlement" ? "Add & open case" : "Add account"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
