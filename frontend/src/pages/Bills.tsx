import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { MonthlyBill } from "@/types";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Plus, Pencil, Trash2, CheckCircle2, XCircle, AlertTriangle } from "lucide-react";
import { toast } from "sonner";

export default function Bills() {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState({
    categoryId: "",
    name: "",
    amount: "",
    dueDate: 1,
    reminderDays: 3,
    notes: "",
  });

  const queryClient = useQueryClient();
  const { data: categories } = useQuery({ queryKey: ["categories"], queryFn: api.categories.list });
  const { data: bills, isLoading } = useQuery({ queryKey: ["bills"], queryFn: api.bills.list });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["bills"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const createMutation = useMutation({
    mutationFn: api.bills.create,
    onSuccess: () => {
      toast.success("Bill created successfully");
      invalidate();
      resetForm();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to create bill");
    }
  });
  const updateMutation = useMutation({
    mutationFn: api.bills.update,
    onSuccess: () => {
      toast.success("Bill updated successfully");
      invalidate();
      resetForm();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to update bill");
    }
  });
  const deleteMutation = useMutation({
    mutationFn: api.bills.delete,
    onSuccess: () => {
      toast.success("Bill deleted successfully");
      invalidate();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to delete bill");
    }
  });
  const toggleMutation = useMutation({
    mutationFn: api.bills.togglePaid,
    onSuccess: (updatedBill) => {
      toast.success(`Bill marked as ${updatedBill.isPaid ? "paid" : "unpaid"}`);
      invalidate();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to update bill status");
    }
  });

  const billCategories = categories?.filter((c) => c.type === "bill") ?? [];

  const resetForm = () => {
    setForm({ categoryId: "", name: "", amount: "", dueDate: 1, reminderDays: 3, notes: "" });
    setEditingId(null);
    setDialogOpen(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.categoryId || !form.name || !form.amount) return;
    const payload = { categoryId: Number(form.categoryId), name: form.name, amount: form.amount, dueDate: form.dueDate, reminderDays: form.reminderDays, notes: form.notes || undefined };
    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  const handleEdit = (bill: MonthlyBill) => {
    setEditingId(bill.id);
    setForm({ categoryId: String(bill.categoryId), name: bill.name, amount: String(bill.amount), dueDate: bill.dueDate, reminderDays: bill.reminderDays, notes: bill.notes || "" });
    setDialogOpen(true);
  };

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(num);
  };

  const totalAmount = bills?.reduce((sum, b) => sum + (b.isActive ? parseFloat(String(b.amount)) : 0), 0) ?? 0;
  const paidAmount = bills?.reduce((sum, b) => sum + (b.isPaid && b.isActive ? parseFloat(String(b.amount)) : 0), 0) ?? 0;
  const pendingAmount = totalAmount - paidAmount;

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Monthly Bills</h2>
            <p className="text-muted-foreground">Manage your recurring monthly bills</p>
          </div>
          <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }}><Plus className="w-4 h-4 mr-1" /> Add Bill</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>{editingId ? "Edit Bill" : "Add Monthly Bill"}</DialogTitle></DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div><Label>Category</Label>
                  <Select value={form.categoryId} onValueChange={(v) => setForm({ ...form, categoryId: v })}>
                    <SelectTrigger><SelectValue placeholder="Select category" /></SelectTrigger>
                    <SelectContent>{billCategories.map((c) => (<SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>))}</SelectContent>
                  </Select>
                </div>
                <div><Label>Bill Name</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g., Electricity Bill" /></div>
                <div><Label>Amount (₹)</Label><Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" /></div>
                <div><Label>Due Date (Day of Month)</Label><Input type="number" min={1} max={31} value={form.dueDate} onChange={(e) => setForm({ ...form, dueDate: Number(e.target.value) })} /></div>
                <div><Label>Reminder Days Before</Label><Input type="number" min={0} max={30} value={form.reminderDays} onChange={(e) => setForm({ ...form, reminderDays: Number(e.target.value) })} /></div>
                <div><Label>Notes</Label><Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Optional notes" /></div>
                <DialogFooter>
                  <Button type="button" variant="outline" onClick={resetForm}>Cancel</Button>
                  <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending}>{editingId ? "Update" : "Add"} Bill</Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <Card><CardHeader className="pb-2"><CardTitle className="text-sm">Total Bills</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold">{formatCurrency(totalAmount)}</div></CardContent></Card>
          <Card><CardHeader className="pb-2"><CardTitle className="text-sm text-green-600">Paid</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold text-green-600">{formatCurrency(paidAmount)}</div></CardContent></Card>
          <Card><CardHeader className="pb-2"><CardTitle className="text-sm text-orange-600">Pending</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold text-orange-600">{formatCurrency(pendingAmount)}</div></CardContent></Card>
        </div>

        <Card>
          <CardHeader><CardTitle>Your Bills</CardTitle></CardHeader>
          <CardContent>
            {isLoading ? <div className="space-y-3">{[...Array(4)].map((_, i) => <Skeleton key={i} className="h-16" />)}</div> : bills?.length === 0 ? (
              <p className="text-center text-muted-foreground py-8">No bills added yet</p>
            ) : (
              <div className="space-y-3">
                {bills?.filter((b) => b.isActive).map((bill) => {
                  const today = new Date().getDate();
                  const isOverdue = !bill.isPaid && bill.dueDate < today;
                  return (
                    <div key={bill.id} className={`flex items-center justify-between p-4 rounded-lg border ${isOverdue ? "border-red-200 bg-red-50" : bill.isPaid ? "border-green-200 bg-green-50" : "hover:bg-muted/50"} transition-colors`}>
                      <div className="flex items-center gap-3">
                        <button
                          type="button"
                          onClick={() => toggleMutation.mutate(bill.id)}
                          disabled={toggleMutation.isPending}
                          className="flex-shrink-0 focus:outline-none focus:ring-2 focus:ring-primary rounded-full disabled:opacity-50 transition-opacity"
                        >
                          {bill.isPaid ? <CheckCircle2 className="w-6 h-6 text-green-600" /> : isOverdue ? <AlertTriangle className="w-6 h-6 text-red-500" /> : <XCircle className="w-6 h-6 text-muted-foreground" />}
                        </button>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="text-sm font-medium">{bill.name}</p>
                            {isOverdue && <Badge variant="destructive" className="text-[10px] h-4">Overdue</Badge>}
                            {bill.isPaid && <Badge variant="default" className="text-[10px] h-4 bg-green-600">Paid</Badge>}
                          </div>
                          <p className="text-xs text-muted-foreground">Due on {bill.dueDate}{getDaySuffix(bill.dueDate)} · {bill.categoryName}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-sm font-semibold">{formatCurrency(bill.amount)}</span>
                        <div className="flex gap-1">
                          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleEdit(bill)}><Pencil className="w-3.5 h-3.5" /></Button>
                          <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => deleteMutation.mutate(bill.id)}><Trash2 className="w-3.5 h-3.5" /></Button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function getDaySuffix(day: number): string {
  if (day > 3 && day < 21) return "th";
  switch (day % 10) { case 1: return "st"; case 2: return "nd"; case 3: return "rd"; default: return "th"; }
}
