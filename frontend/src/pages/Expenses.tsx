import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { formatCurrency } from "@/lib/utils";
import type { Expense } from "@/types";
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
import { Search, Plus, Pencil, Trash2, Filter } from "lucide-react";
import { format } from "date-fns";
import { toast } from "sonner";

const paymentMethods = [
  { value: "cash", label: "Cash" },
  { value: "credit_card", label: "Credit Card" },
  { value: "debit_card", label: "Debit Card" },
  { value: "upi", label: "UPI" },
  { value: "net_banking", label: "Net Banking" },
  { value: "other", label: "Other" },
];

export default function Expenses() {
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<number | undefined>();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState({
    categoryId: "",
    amount: "",
    description: "",
    expenseDate: format(now, "yyyy-MM-dd"),
    paymentMethod: "cash",
    isRecurring: false,
  });

  const queryClient = useQueryClient();
  const { data: categories } = useQuery({ queryKey: ["categories"], queryFn: api.categories.list });
  const { data: expenses, isLoading } = useQuery({
    queryKey: ["expenses", { month, year, categoryId: categoryFilter, search }],
    queryFn: () => api.expenses.list({ month, year, categoryId: categoryFilter, search: search || undefined }),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["expenses"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const createMutation = useMutation({
    mutationFn: api.expenses.create,
    onMutate: async (newExpensePayload) => {
      await queryClient.cancelQueries({ queryKey: ["expenses"] });
      const previousExpenses = queryClient.getQueryData(["expenses", { month, year, categoryId: categoryFilter, search }]);
      
      queryClient.setQueryData(["expenses", { month, year, categoryId: categoryFilter, search }], (old: any) => {
        const optimisticExpense = {
          id: Date.now(),
          ...newExpensePayload,
          categoryName: categories?.find((c) => c.id === newExpensePayload.categoryId)?.name || "Unknown",
        };
        return old ? [optimisticExpense, ...old] : [optimisticExpense];
      });

      return { previousExpenses };
    },
    onError: (error: any, newExp, context) => {
      queryClient.setQueryData(["expenses", { month, year, categoryId: categoryFilter, search }], context?.previousExpenses);
      toast.error(error.message || "Failed to create expense");
    },
    onSettled: () => {
      invalidate();
    },
    onSuccess: () => {
      toast.success("Expense created successfully");
      resetForm();
    }
  });

  const updateMutation = useMutation({
    mutationFn: api.expenses.update,
    onSuccess: () => {
      toast.success("Expense updated successfully");
      invalidate();
      resetForm();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to update expense");
    }
  });

  const deleteMutation = useMutation({
    mutationFn: api.expenses.delete,
    onSuccess: () => {
      toast.success("Expense deleted successfully");
      invalidate();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to delete expense");
    }
  });

  const expenseCategories = categories?.filter((c) => c.type === "expense") ?? [];

  const resetForm = () => {
    setForm({
      categoryId: "",
      amount: "",
      description: "",
      expenseDate: format(new Date(), "yyyy-MM-dd"),
      paymentMethod: "cash",
      isRecurring: false,
    });
    setEditingId(null);
    setDialogOpen(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.categoryId || !form.amount || !form.description) return;

    const payload = {
      categoryId: Number(form.categoryId),
      amount: form.amount,
      description: form.description,
      expenseDate: form.expenseDate,
      paymentMethod: form.paymentMethod as "cash" | "credit_card" | "debit_card" | "upi" | "net_banking" | "other",
      isRecurring: form.isRecurring,
    };

    if (editingId) {
      updateMutation.mutate({ id: editingId, ...payload });
    } else {
      createMutation.mutate(payload);
    }
  };

  const handleEdit = (exp: Expense) => {
    setEditingId(exp.id);
    setForm({
      categoryId: String(exp.categoryId),
      amount: String(exp.amount),
      description: exp.description ?? "",
      expenseDate: exp.expenseDate
        ? format(new Date(exp.expenseDate), "yyyy-MM-dd")
        : format(new Date(), "yyyy-MM-dd"),
      paymentMethod: exp.paymentMethod,
      isRecurring: exp.isRecurring,
    });
    setDialogOpen(true);
  };

  const formatCurrencyLocal = formatCurrency;

  const monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];

  const totalAmount = expenses?.reduce((sum, e) => sum + parseFloat(String(e.amount)), 0) ?? 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Expenses</h2>
          <p className="text-muted-foreground">Track your daily expenses</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Button variant="outline" size="sm" onClick={() => { if (month === 1) { setMonth(12); setYear(year - 1); } else setMonth(month - 1); }}>&larr;</Button>
          <span className="text-sm font-medium px-3 py-1 bg-muted rounded-md">{monthNames[month - 1]} {year}</span>
          <Button variant="outline" size="sm" onClick={() => { if (month === 12) { setMonth(1); setYear(year + 1); } else setMonth(month + 1); }}>&rarr;</Button>
          <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }}>
                <Plus className="w-4 h-4 mr-1" /> Add Expense
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{editingId ? "Edit Expense" : "Add Expense"}</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label>Category</Label>
                  <Select value={form.categoryId} onValueChange={(v) => setForm({ ...form, categoryId: v })}>
                    <SelectTrigger><SelectValue placeholder="Select category" /></SelectTrigger>
                    <SelectContent>
                      {expenseCategories.map((c) => (
                        <SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Amount (₹)</Label>
                  <Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" />
                </div>
                <div>
                  <Label>Description</Label>
                  <Input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="What did you spend on?" />
                </div>
                <div>
                  <Label>Date</Label>
                  <Input type="date" value={form.expenseDate} onChange={(e) => setForm({ ...form, expenseDate: e.target.value })} />
                </div>
                <div>
                  <Label>Payment Method</Label>
                  <Select value={form.paymentMethod} onValueChange={(v) => setForm({ ...form, paymentMethod: v })}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {paymentMethods.map((m) => (
                        <SelectItem key={m.value} value={m.value}>{m.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <DialogFooter>
                  <Button type="button" variant="outline" onClick={resetForm}>Cancel</Button>
                  <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending}>
                    {editingId ? "Update" : "Add"} Expense
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Total: {formatCurrencyLocal(totalAmount)}</CardTitle>
          <div className="flex items-center gap-2">
            <div className="relative">
              <Search className="w-4 h-4 absolute left-2.5 top-2.5 text-muted-foreground" />
              <Input className="pl-9 w-[200px]" placeholder="Search..." value={search} onChange={(e) => setSearch(e.target.value)} />
            </div>
            <Select value={categoryFilter ? String(categoryFilter) : "all"} onValueChange={(v) => setCategoryFilter(v === "all" ? undefined : Number(v))}>
              <SelectTrigger className="w-[140px]"><Filter className="w-4 h-4 mr-1" /><SelectValue placeholder="Filter" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Categories</SelectItem>
                {expenseCategories.map((c) => (
                  <SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => <Skeleton key={i} className="h-14" />)}
            </div>
          ) : expenses?.length === 0 ? (
            <p className="text-center text-muted-foreground py-8">No expenses found for this period</p>
          ) : (
            <div className="space-y-2">
              {expenses?.map((exp) => (
                <div key={exp.id} className="flex items-center justify-between p-3 rounded-lg border hover:bg-muted/50 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full flex items-center justify-center text-white text-xs font-bold" style={{ backgroundColor: exp.categoryColor || "#6366f1" }}>
                      {exp.categoryName?.[0]?.toUpperCase() || "?"}
                    </div>
                    <div>
                      <p className="text-sm font-medium">{exp.description}</p>
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        <span>{exp.categoryName}</span>
                        <span>·</span>
                        <span>{exp.expenseDate ? format(new Date(exp.expenseDate), "dd MMM yyyy") : ""}</span>
                        <Badge variant="outline" className="text-[10px] h-4 px-1">{exp.paymentMethod.replace("_", " ")}</Badge>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-sm font-semibold text-red-600">{formatCurrencyLocal(exp.amount)}</span>
                    <div className="flex gap-1">
                      <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleEdit(exp)}><Pencil className="w-3.5 h-3.5" /></Button>
                      <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => deleteMutation.mutate(exp.id)}><Trash2 className="w-3.5 h-3.5" /></Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
