import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Budget as BudgetType } from "@/types";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { AlertTriangle, Plus, Pencil, Trash2, PiggyBank } from "lucide-react";

export default function Budget() {
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState({ categoryId: "", amount: "", alertThreshold: 80 });

  const queryClient = useQueryClient();
  const { data: categories } = useQuery({ queryKey: ["categories"], queryFn: api.categories.list });
  const { data: budgets, isLoading } = useQuery({ queryKey: ["budgets", { month, year }], queryFn: () => api.budgets.list({ month, year }) });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["budgets"] });

  const createMutation = useMutation({ mutationFn: api.budgets.create, onSuccess: () => { invalidate(); resetForm(); } });
  const updateMutation = useMutation({ mutationFn: api.budgets.update, onSuccess: () => { invalidate(); resetForm(); } });
  const deleteMutation = useMutation({ mutationFn: api.budgets.delete, onSuccess: invalidate });

  const expenseCategories = categories?.filter((c) => c.type === "expense") ?? [];

  const resetForm = () => { setForm({ categoryId: "", amount: "", alertThreshold: 80 }); setEditingId(null); setDialogOpen(false); };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.categoryId || !form.amount) return;
    const payload = { categoryId: Number(form.categoryId), amount: form.amount, month, year, alertThreshold: form.alertThreshold };
    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  const handleEdit = (b: BudgetType) => {
    setEditingId(b.id);
    setForm({ categoryId: String(b.categoryId), amount: String(b.amount), alertThreshold: b.alertThreshold });
    setDialogOpen(true);
  };

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(num);
  };

  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

  const totalBudget = budgets?.reduce((sum, b) => sum + parseFloat(String(b.amount)), 0) ?? 0;
  const totalSpent = budgets?.reduce((sum, b) => sum + b.spent, 0) ?? 0;
  const overallProgress = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0;

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Budget Planner</h2>
            <p className="text-muted-foreground">Set and track your monthly budgets</p>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => { if (month === 1) { setMonth(12); setYear(year - 1); } else setMonth(month - 1); }}>&larr;</Button>
            <span className="text-sm font-medium px-3 py-1 bg-muted rounded-md">{monthNames[month - 1]} {year}</span>
            <Button variant="outline" size="sm" onClick={() => { if (month === 12) { setMonth(1); setYear(year + 1); } else setMonth(month + 1); }}>&rarr;</Button>
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }}><Plus className="w-4 h-4 mr-1" /> Set Budget</Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader><DialogTitle>{editingId ? "Edit Budget" : "Set Budget"}</DialogTitle></DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4">
                  <div><Label>Category</Label>
                    <Select value={form.categoryId} onValueChange={(v) => setForm({ ...form, categoryId: v })}>
                      <SelectTrigger><SelectValue placeholder="Select category" /></SelectTrigger>
                      <SelectContent>{expenseCategories.map((c) => (<SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>))}</SelectContent>
                    </Select>
                  </div>
                  <div><Label>Budget Amount (₹)</Label><Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" /></div>
                  <div><Label>Alert Threshold (%)</Label><Input type="number" min={1} max={100} value={form.alertThreshold} onChange={(e) => setForm({ ...form, alertThreshold: Number(e.target.value) })} /></div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={resetForm}>Cancel</Button>
                    <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending}>{editingId ? "Update" : "Set"} Budget</Button>
                  </DialogFooter>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-sm">Overall Budget</CardTitle>
            <div className="text-right">
              <p className="text-sm font-medium">{formatCurrency(totalSpent)} / {formatCurrency(totalBudget)}</p>
            </div>
          </CardHeader>
          <CardContent>
            <Progress value={Math.min(overallProgress, 100)} className={`h-3 ${overallProgress > 100 ? "bg-red-200" : overallProgress > 80 ? "bg-orange-200" : ""}`} />
            <p className="text-xs text-muted-foreground mt-2">
              {overallProgress > 100 ? "Budget exceeded!" : overallProgress > 80 ? "Approaching budget limit" : `${(100 - overallProgress).toFixed(1)}% remaining`}
            </p>
          </CardContent>
        </Card>

        <div className="grid gap-4 md:grid-cols-2">
          {isLoading ? [...Array(4)].map((_, i) => <Skeleton key={i} className="h-32" />) : budgets?.length === 0 ? (
            <div className="col-span-2 text-center text-muted-foreground py-8">
              <PiggyBank className="w-12 h-12 mx-auto mb-3 opacity-50" />
              <p>No budgets set for this month</p>
              <Button variant="outline" size="sm" className="mt-2" onClick={() => { resetForm(); setDialogOpen(true); }}>Set Your First Budget</Button>
            </div>
          ) : (
            budgets?.map((b) => {
              const isOver = b.percentage > 100;
              const isWarning = b.percentage >= b.alertThreshold && !isOver;
              return (
                <Card key={b.id} className={`${isOver ? "border-red-200" : isWarning ? "border-orange-200" : ""}`}>
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold" style={{ backgroundColor: b.categoryColor || "#6366f1" }}>
                          {b.categoryName?.[0]?.toUpperCase() || "?"}
                        </div>
                        <div>
                          <p className="font-medium text-sm">{b.categoryName}</p>
                          <p className="text-xs text-muted-foreground">Budget: {formatCurrency(b.amount)}</p>
                        </div>
                      </div>
                      <div className="flex gap-1">
                        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleEdit(b)}><Pencil className="w-3.5 h-3.5" /></Button>
                        <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => deleteMutation.mutate(b.id)}><Trash2 className="w-3.5 h-3.5" /></Button>
                      </div>
                    </div>
                    <div className="flex justify-between text-xs mb-1">
                      <span>Spent: {formatCurrency(b.spent)}</span>
                      <span className={`font-medium ${isOver ? "text-red-600" : isWarning ? "text-orange-600" : ""}`}>
                        {isOver && <AlertTriangle className="w-3 h-3 inline mr-1" />}
                        {b.percentage.toFixed(0)}%
                      </span>
                    </div>
                    <Progress value={Math.min(b.percentage, 100)} className={`h-2 ${isOver ? "bg-red-200" : isWarning ? "bg-orange-200" : ""}`} />
                    <p className="text-xs text-muted-foreground mt-1">Remaining: {formatCurrency(b.remaining)}</p>
                  </CardContent>
                </Card>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
