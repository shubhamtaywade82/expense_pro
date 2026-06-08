import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { formatCurrency } from "@/lib/utils";
import type { Expense } from "@/types";
import { CardTitle } from "@/components/ui/card";
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
import { Search, Plus, Pencil, Trash2, Filter, Calendar, CreditCard } from "lucide-react";
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
    onError: (error: any, _newExp, context) => {
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
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div className="flex items-center justify-between flex-wrap gap-4 animate-stagger-fade" style={{ animationDelay: "0ms" }}>
          <div>
            <h2 className="text-2xl font-bold font-display tracking-tight text-foreground">Expenses Ledger</h2>
            <p className="text-sm text-muted-foreground">Log and inspect your outbound transactions</p>
          </div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <div className="flex items-center gap-1 bg-card/45 backdrop-blur-md border border-border/40 p-1 rounded-xl">
              <Button variant="ghost" size="icon" onClick={() => { if (month === 1) { setMonth(12); setYear(year - 1); } else setMonth(month - 1); }} className="h-8 w-8 rounded-lg">
                &larr;
              </Button>
              <span className="text-xs font-semibold px-2 min-w-[110px] text-center text-foreground font-display flex items-center justify-center gap-1">
                <Calendar className="w-3.5 h-3.5 text-primary" />
                {monthNames[month - 1]} {year}
              </span>
              <Button variant="ghost" size="icon" onClick={() => { if (month === 12) { setMonth(1); setYear(year + 1); } else setMonth(month + 1); }} className="h-8 w-8 rounded-lg">
                &rarr;
              </Button>
            </div>
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }} className="rounded-xl bg-gradient-to-tr from-primary to-indigo-600 hover:from-primary/90 hover:to-indigo-600/90 text-white font-medium shadow-md shadow-primary/15 hover-lift">
                  <Plus className="w-4 h-4 mr-1.5" /> Log Expense
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-[425px] bg-card/95 backdrop-blur-xl border border-border/50 rounded-2xl shadow-glass">
                <DialogHeader>
                  <DialogTitle className="font-display font-bold text-lg text-foreground">
                    {editingId ? "Edit Ledger Record" : "Log New Expense"}
                  </DialogTitle>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4 pt-2">
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold text-muted-foreground">Category</Label>
                    <Select value={form.categoryId} onValueChange={(v) => setForm({ ...form, categoryId: v })}>
                      <SelectTrigger className="rounded-xl border-border/60 bg-background/50 focus:ring-primary"><SelectValue placeholder="Select category" /></SelectTrigger>
                      <SelectContent className="bg-card/95 backdrop-blur-md border-border/60">
                        {expenseCategories.map((c) => (
                          <SelectItem key={c.id} value={String(c.id)} className="focus:bg-primary/10 rounded-lg">{c.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold text-muted-foreground">Amount (₹)</Label>
                    <Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" className="rounded-xl border-border/60 bg-background/50 focus-visible:ring-primary font-sans font-medium" />
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold text-muted-foreground">Description</Label>
                    <Input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="E.g., Grocery shopping, AWS hosting..." className="rounded-xl border-border/60 bg-background/50 focus-visible:ring-primary" />
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold text-muted-foreground">Transaction Date</Label>
                    <Input type="date" value={form.expenseDate} onChange={(e) => setForm({ ...form, expenseDate: e.target.value })} className="rounded-xl border-border/60 bg-background/50 focus-visible:ring-primary" />
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold text-muted-foreground">Payment Method</Label>
                    <Select value={form.paymentMethod} onValueChange={(v) => setForm({ ...form, paymentMethod: v })}>
                      <SelectTrigger className="rounded-xl border-border/60 bg-background/50 focus:ring-primary"><SelectValue /></SelectTrigger>
                      <SelectContent className="bg-card/95 backdrop-blur-md border-border/60">
                        {paymentMethods.map((m) => (
                          <SelectItem key={m.value} value={m.value} className="focus:bg-primary/10 rounded-lg">{m.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <DialogFooter className="pt-3">
                    <Button type="button" variant="outline" onClick={resetForm} className="rounded-xl border-border/65">Cancel</Button>
                    <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending} className="rounded-xl bg-primary hover:bg-primary/95 text-white">
                      {editingId ? "Save Changes" : "Create Record"}
                    </Button>
                  </DialogFooter>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-2xl p-0.5 overflow-hidden animate-stagger-fade" style={{ animationDelay: "100ms" }}>
          <div className="bg-card/50 backdrop-blur-lg rounded-[14px]">
            <div className="p-5 flex flex-wrap items-center justify-between border-b border-border/40 gap-4">
              <div>
                <span className="text-[11px] uppercase tracking-wider text-muted-foreground font-semibold font-display block">Total Cash Outflow</span>
                <CardTitle className="text-2xl font-bold font-sans text-red-500 mt-1">
                  {formatCurrencyLocal(totalAmount)}
                </CardTitle>
              </div>
              <div className="flex items-center gap-2.5 flex-wrap">
                <div className="relative">
                  <Search className="w-4 h-4 absolute left-3 top-3 text-muted-foreground/70" />
                  <Input className="pl-9 w-[220px] rounded-xl border-border/50 bg-background/40 focus-visible:ring-primary" placeholder="Search description..." value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
                <Select value={categoryFilter ? String(categoryFilter) : "all"} onValueChange={(v) => setCategoryFilter(v === "all" ? undefined : Number(v))}>
                  <SelectTrigger className="w-[150px] rounded-xl border-border/50 bg-background/40 focus:ring-primary">
                    <Filter className="w-3.5 h-3.5 mr-1.5 text-muted-foreground" />
                    <SelectValue placeholder="Category Filter" />
                  </SelectTrigger>
                  <SelectContent className="bg-card/95 backdrop-blur-md border-border/50">
                    <SelectItem value="all" className="focus:bg-primary/10 rounded-lg">All Categories</SelectItem>
                    {expenseCategories.map((c) => (
                      <SelectItem key={c.id} value={String(c.id)} className="focus:bg-primary/10 rounded-lg">{c.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="p-5">
              {isLoading ? (
                <div className="space-y-3">
                  {[...Array(4)].map((_, i) => <Skeleton key={i} className="h-14 bg-muted/40 rounded-xl" />)}
                </div>
              ) : expenses?.length === 0 ? (
                <p className="text-center text-muted-foreground py-10 text-sm">No recorded outbound transactions found for this query.</p>
              ) : (
                <div className="space-y-3">
                  {expenses?.map((exp, idx) => (
                    <div
                      key={exp.id}
                      className="flex items-center justify-between p-3.5 rounded-xl bg-card/30 border border-border/30 hover:border-primary/25 hover:bg-card/65 transition-all duration-300 group hover:-translate-y-0.5 shadow-sm"
                      style={{ animationDelay: `${idx * 25}ms` }}
                    >
                      <div className="flex items-center gap-3">
                        <div
                          className="w-10 h-10 rounded-xl flex items-center justify-center text-white text-xs font-bold shadow-md transition-transform group-hover:scale-105"
                          style={{
                            backgroundColor: exp.categoryColor || "#6366f1",
                            backgroundImage: `linear-gradient(135deg, ${exp.categoryColor}cc, ${exp.categoryColor}ff)`
                          }}
                        >
                          {exp.categoryName?.[0]?.toUpperCase() || "?"}
                        </div>
                        <div>
                          <p className="text-sm font-semibold text-foreground group-hover:text-primary transition-colors">{exp.description}</p>
                          <div className="flex items-center gap-2 mt-1 flex-wrap">
                            <span className="text-xs font-medium text-foreground/70">{exp.categoryName}</span>
                            <span className="text-[10px] text-muted-foreground">&#8226;</span>
                            <span className="text-xs text-muted-foreground">{exp.expenseDate ? format(new Date(exp.expenseDate), "dd MMM yyyy") : ""}</span>
                            <span className="text-[10px] text-muted-foreground">&#8226;</span>
                            <Badge variant="outline" className="text-[9px] font-semibold h-4 px-1.5 rounded-md border-border/40 bg-muted/30 text-muted-foreground uppercase flex items-center gap-1">
                              <CreditCard className="w-2.5 h-2.5" />
                              {exp.paymentMethod.replace("_", " ")}
                            </Badge>
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-4">
                        <span className="text-sm font-bold text-red-500 font-sans">{formatCurrencyLocal(exp.amount)}</span>
                        <div className="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                          <Button variant="ghost" size="icon" className="h-8 w-8 rounded-lg hover:bg-muted/80 text-foreground" onClick={() => handleEdit(exp)}>
                            <Pencil className="w-3.5 h-3.5" />
                          </Button>
                          <Button variant="ghost" size="icon" className="h-8 w-8 rounded-lg hover:bg-red-500/10 text-red-500" onClick={() => deleteMutation.mutate(exp.id)}>
                            <Trash2 className="w-3.5 h-3.5" />
                          </Button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
