import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Income as IncomeType } from "@/types";
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
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Plus, Pencil, Trash2, TrendingUp, Wallet, Check } from "lucide-react";
import { format } from "date-fns";

export default function Income() {
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState({ 
    source: "", 
    amount: "", 
    incomeDate: format(now, "yyyy-MM-dd"), 
    isRecurring: false, 
    frequency: "monthly" as string, 
    notes: "",
    parentId: null as number | null,
    isReceived: true,
    endDate: ""
  });

  const queryClient = useQueryClient();
  const { data: incomes, isLoading } = useQuery({ queryKey: ["incomes", { month, year }], queryFn: () => api.incomes.list({ month, year }) });
  const { data: summary } = useQuery({ queryKey: ["incomes", "summary", { month, year }], queryFn: () => api.incomes.summary({ month, year }) });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["incomes"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const createMutation = useMutation({ mutationFn: api.incomes.create, onSuccess: () => { invalidate(); resetForm(); } });
  const updateMutation = useMutation({ mutationFn: api.incomes.update, onSuccess: () => { invalidate(); resetForm(); } });
  const deleteMutation = useMutation({ mutationFn: api.incomes.delete, onSuccess: invalidate });
  const toggleReceivedMutation = useMutation({ mutationFn: api.incomes.toggleReceived, onSuccess: invalidate });

  const handleToggleReceived = (inc: IncomeType) => {
    if (inc.id) {
      toggleReceivedMutation.mutate(inc.id);
    } else {
      createMutation.mutate({
        source: inc.source,
        amount: inc.amount,
        incomeDate: inc.incomeDate,
        isRecurring: false,
        frequency: inc.frequency,
        notes: inc.notes,
        parentId: inc.parentId,
        isReceived: true
      });
    }
  };

  const resetForm = () => { 
    setForm({ 
      source: "", 
      amount: "", 
      incomeDate: format(new Date(), "yyyy-MM-dd"), 
      isRecurring: false, 
      frequency: "monthly", 
      notes: "",
      parentId: null,
      isReceived: true,
      endDate: ""
    }); 
    setEditingId(null); 
    setDialogOpen(false); 
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.source || !form.amount) return;
    const payload = { 
      source: form.source, 
      amount: form.amount, 
      incomeDate: form.incomeDate, 
      isRecurring: form.isRecurring, 
      frequency: form.frequency as "monthly" | "quarterly" | "yearly" | "one_time", 
      notes: form.notes || undefined,
      parentId: form.parentId,
      isReceived: form.isReceived,
      endDate: form.isRecurring && form.endDate ? form.endDate : null
    };
    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  const handleEdit = (inc: IncomeType) => {
    setEditingId(inc.id);
    setForm({ 
      source: inc.source, 
      amount: String(inc.amount), 
      incomeDate: inc.incomeDate ? format(new Date(inc.incomeDate), "yyyy-MM-dd") : format(new Date(), "yyyy-MM-dd"), 
      isRecurring: inc.isRecurring, 
      frequency: inc.frequency, 
      notes: inc.notes || "",
      parentId: inc.parentId || null,
      isReceived: inc.isReceived,
      endDate: inc.endDate ? format(new Date(inc.endDate), "yyyy-MM-dd") : ""
    });
    setDialogOpen(true);
  };

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(num);
  };

  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Income</h2>
            <p className="text-muted-foreground">Track your income sources</p>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => { if (month === 1) { setMonth(12); setYear(year - 1); } else setMonth(month - 1); }}>&larr;</Button>
            <span className="text-sm font-medium px-3 py-1 bg-muted rounded-md">{monthNames[month - 1]} {year}</span>
            <Button variant="outline" size="sm" onClick={() => { if (month === 12) { setMonth(1); setYear(year + 1); } else setMonth(month + 1); }}>&rarr;</Button>
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }}><Plus className="w-4 h-4 mr-1" /> Add Income</Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader><DialogTitle>{editingId ? "Edit Income" : "Add Income"}</DialogTitle></DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4">
                  <div><Label>Source</Label><Input value={form.source} onChange={(e) => setForm({ ...form, source: e.target.value })} placeholder="e.g., Salary, Freelance" /></div>
                  <div><Label>Amount (₹)</Label><Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" /></div>
                  <div><Label>Date</Label><Input type="date" value={form.incomeDate} onChange={(e) => setForm({ ...form, incomeDate: e.target.value })} /></div>
                  <div><Label>Frequency</Label>
                    <Select value={form.frequency} onValueChange={(v) => setForm({ ...form, frequency: v })}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="monthly">Monthly</SelectItem>
                        <SelectItem value="quarterly">Quarterly</SelectItem>
                        <SelectItem value="yearly">Yearly</SelectItem>
                        <SelectItem value="one_time">One Time</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex items-center gap-2"><Switch checked={form.isRecurring} onCheckedChange={(v) => setForm({ ...form, isRecurring: v })} /><Label>Recurring</Label></div>
                  {form.isRecurring && (
                    <div>
                      <Label>End Date (Optional)</Label>
                      <Input type="date" value={form.endDate} onChange={(e) => setForm({ ...form, endDate: e.target.value })} />
                    </div>
                  )}
                  <div className="flex items-center gap-2"><Switch checked={form.isReceived} onCheckedChange={(v) => setForm({ ...form, isReceived: v })} /><Label>Received</Label></div>
                  <div><Label>Notes</Label><Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Optional" /></div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={resetForm}>Cancel</Button>
                    <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending}>{editingId ? "Update" : "Add"}</Button>
                  </DialogFooter>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <Card><CardHeader className="flex flex-row items-center justify-between pb-2"><CardTitle className="text-sm">Total Income</CardTitle><Wallet className="w-4 h-4 text-muted-foreground" /></CardHeader><CardContent><div className="text-2xl font-bold text-green-600">{formatCurrency(summary?.total ?? "0")}</div><p className="text-xs text-muted-foreground">{summary?.count ?? 0} entries</p></CardContent></Card>
          <Card><CardHeader className="flex flex-row items-center justify-between pb-2"><CardTitle className="text-sm">Recurring Income</CardTitle><TrendingUp className="w-4 h-4 text-muted-foreground" /></CardHeader><CardContent><div className="text-2xl font-bold">{formatCurrency(incomes?.filter((i) => i.isRecurring).reduce((sum, i) => sum + parseFloat(String(i.amount)), 0) ?? 0)}</div><p className="text-xs text-muted-foreground">{incomes?.filter((i) => i.isRecurring).length ?? 0} recurring sources</p></CardContent></Card>
        </div>

        <Card>
          <CardHeader><CardTitle>Income Entries</CardTitle></CardHeader>
          <CardContent>
            {isLoading ? <div className="space-y-3">{[...Array(4)].map((_, i) => <Skeleton key={i} className="h-14" />)}</div> : incomes?.length === 0 ? (
              <p className="text-center text-muted-foreground py-8">No income recorded for this period</p>
            ) : (
              <div className="space-y-2">
                {incomes?.map((inc) => (
                  <div key={inc.id} className="flex items-center justify-between p-3 rounded-lg border hover:bg-muted/50 transition-colors">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-green-100 flex items-center justify-center"><TrendingUp className="w-4 h-4 text-green-600" /></div>
                      <div>
                        <p className="text-sm font-medium">{inc.source}</p>
                        <div className="flex items-center gap-2 text-xs text-muted-foreground">
                          <span>{inc.incomeDate ? format(new Date(inc.incomeDate), "dd MMM yyyy") : ""}</span>
                          <Badge variant="outline" className="text-[10px] h-4">{inc.frequency}</Badge>
                          {inc.isRecurring && <Badge variant="secondary" className="text-[10px] h-4">Recurring</Badge>}
                          {inc.isRecurring && inc.endDate && (
                            <Badge variant="outline" className="text-[10px] h-4 text-rose-600 border-rose-200 bg-rose-50/50">
                              Ends: {format(new Date(inc.endDate), "dd MMM yyyy")}
                            </Badge>
                          )}
                          {inc.id === null && <Badge variant="outline" className="text-[10px] h-4 border-dashed">Projected</Badge>}
                          {inc.isReceived ? (
                            <Badge variant="secondary" className="text-[10px] h-4 bg-green-100 text-green-700 hover:bg-green-100 border-green-200">Received</Badge>
                          ) : (
                            <Badge variant="secondary" className="text-[10px] h-4 bg-yellow-100 text-yellow-700 hover:bg-yellow-100 border-yellow-200">Expected</Badge>
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="text-sm font-semibold text-green-600">+{formatCurrency(inc.amount)}</span>
                      <div className="flex gap-1">
                        {!inc.isReceived && (
                          <Button variant="ghost" size="icon" className="h-7 w-7 text-green-600" onClick={() => handleToggleReceived(inc)} title="Mark as Received"><Check className="w-3.5 h-3.5" /></Button>
                        )}
                        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleEdit(inc)}><Pencil className="w-3.5 h-3.5" /></Button>
                        {inc.id !== null && (
                          <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => deleteMutation.mutate(inc.id!)}><Trash2 className="w-3.5 h-3.5" /></Button>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
