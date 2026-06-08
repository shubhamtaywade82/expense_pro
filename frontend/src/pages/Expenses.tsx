import { useState, useMemo } from "react";
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
import { 
  Search, 
  Plus, 
  Pencil, 
  Trash2, 
  Filter, 
  Calendar as CalendarIcon, 
  CreditCard, 
  Smartphone, 
  Banknote, 
  Building2, 
  History,
  TrendingDown,
  ArrowRight
} from "lucide-react";
import { format, isToday, isYesterday, parseISO } from "date-fns";
import { toast } from "sonner";

const paymentMethods = [
  { value: "cash", label: "Cash", icon: Banknote },
  { value: "credit_card", label: "Credit Card", icon: CreditCard },
  { value: "debit_card", label: "Debit Card", icon: CreditCard },
  { value: "upi", label: "UPI / Scan", icon: Smartphone },
  { value: "net_banking", label: "Net Banking", icon: Building2 },
  { value: "other", label: "Other", icon: History },
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
    onSuccess: () => {
      toast.success("Expense logged successfully");
      resetForm();
      invalidate();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to create expense");
    }
  });

  const updateMutation = useMutation({
    mutationFn: api.expenses.update,
    onSuccess: () => {
      toast.success("Transaction updated");
      invalidate();
      resetForm();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to update record");
    }
  });

  const deleteMutation = useMutation({
    mutationFn: api.expenses.delete,
    onSuccess: () => {
      toast.success("Entry removed from ledger");
      invalidate();
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to delete expense");
    }
  });

  const expenseCategories = categories?.filter((c) => c.type === "expense") ?? [];

  const groupedExpenses = useMemo(() => {
    if (!expenses) return [];
    const groups: Record<string, Expense[]> = {};
    
    expenses.forEach(exp => {
      const date = exp.expenseDate || format(new Date(), "yyyy-MM-dd");
      if (!groups[date]) groups[date] = [];
      groups[date].push(exp);
    });

    return Object.entries(groups).sort((a, b) => b[0].localeCompare(a[0]));
  }, [expenses]);

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
      paymentMethod: form.paymentMethod as any,
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
      expenseDate: exp.expenseDate,
      paymentMethod: exp.paymentMethod,
      isRecurring: exp.isRecurring,
    });
    setDialogOpen(true);
  };

  const totalAmount = expenses?.reduce((sum, e) => sum + parseFloat(String(e.amount)), 0) ?? 0;

  const monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];

  const getPaymentIcon = (method: string) => {
    const found = paymentMethods.find(m => m.value === method);
    const Icon = found?.icon || History;
    return <Icon className="w-3 h-3" />;
  };

  const formatDateHeader = (dateStr: string) => {
    const date = parseISO(dateStr);
    if (isToday(date)) return "Today";
    if (isYesterday(date)) return "Yesterday";
    return format(date, "EEEE, dd MMM");
  };

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1 scroll-smooth">
      <div className="space-y-6 pb-8">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 animate-stagger-fade" style={{ animationDelay: "0ms" }}>
          <div>
            <h2 className="text-2xl font-bold font-display tracking-tight text-foreground flex items-center gap-2">
              Expense Ledger
              <Badge variant="outline" className="text-[10px] font-black uppercase tracking-widest bg-primary/5 text-primary border-primary/10 px-2 py-0.5">Verified</Badge>
            </h2>
            <p className="text-sm text-muted-foreground">Track and manage your outbound cashflow</p>
          </div>
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex items-center gap-1 bg-card/60 backdrop-blur-xl border border-border/40 p-1 rounded-2xl shadow-sm">
              <Button variant="ghost" size="icon" onClick={() => { if (month === 1) { setMonth(12); setYear(year - 1); } else setMonth(month - 1); }} className="h-9 w-9 rounded-xl hover:bg-muted/80">
                <ArrowRight className="w-4 h-4 rotate-180" />
              </Button>
              <span className="text-xs font-bold px-3 min-w-[130px] text-center text-foreground font-display flex items-center justify-center gap-2">
                <CalendarIcon className="w-4 h-4 text-primary" />
                {monthNames[month - 1]} {year}
              </span>
              <Button variant="ghost" size="icon" onClick={() => { if (month === 12) { setMonth(1); setYear(year + 1); } else setMonth(month + 1); }} className="h-9 w-9 rounded-xl hover:bg-muted/80">
                <ArrowRight className="w-4 h-4" />
              </Button>
            </div>
            
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }} className="rounded-xl h-10 px-4 bg-primary hover:bg-primary/90 text-white font-bold shadow-lg shadow-primary/20 hover-lift active:scale-95 transition-all">
                  <Plus className="w-4 h-4 mr-2" /> Log Transaction
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-[440px] bg-card/95 backdrop-blur-2xl border border-border/50 rounded-3xl shadow-glass p-0 overflow-hidden">
                <div className="bg-primary/5 p-6 border-b border-border/40">
                  <DialogHeader>
                    <DialogTitle className="font-display font-black text-xl text-foreground flex items-center gap-2">
                      <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                        <TrendingDown className="w-5 h-5 text-primary" />
                      </div>
                      {editingId ? "Modify Entry" : "New Expenditure"}
                    </DialogTitle>
                  </DialogHeader>
                </div>
                <form onSubmit={handleSubmit} className="p-6 space-y-5">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-1.5">
                      <Label className="text-[11px] font-black uppercase tracking-widest text-muted-foreground ml-1">Category</Label>
                      <Select value={form.categoryId} onValueChange={(v) => setForm({ ...form, categoryId: v })}>
                        <SelectTrigger className="rounded-2xl border-border/60 bg-background/50 focus:ring-primary h-11"><SelectValue placeholder="Pick one" /></SelectTrigger>
                        <SelectContent className="bg-card/95 backdrop-blur-md border-border/60 rounded-xl shadow-glass">
                          {expenseCategories.map((c) => (
                            <SelectItem key={c.id} value={String(c.id)} className="focus:bg-primary/10 rounded-lg">{c.name}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-1.5">
                      <Label className="text-[11px] font-black uppercase tracking-widest text-muted-foreground ml-1">Amount (₹)</Label>
                      <Input type="number" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" className="rounded-2xl border-border/60 bg-background/50 focus-visible:ring-primary h-11 font-sans font-black text-base" />
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <Label className="text-[11px] font-black uppercase tracking-widest text-muted-foreground ml-1">Description</Label>
                    <Input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="What did you spend on?" className="rounded-2xl border-border/60 bg-background/50 focus-visible:ring-primary h-11" />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-1.5">
                      <Label className="text-[11px] font-black uppercase tracking-widest text-muted-foreground ml-1">Date</Label>
                      <Input type="date" value={form.expenseDate} onChange={(e) => setForm({ ...form, expenseDate: e.target.value })} className="rounded-2xl border-border/60 bg-background/50 focus-visible:ring-primary h-11" />
                    </div>
                    <div className="space-y-1.5">
                      <Label className="text-[11px] font-black uppercase tracking-widest text-muted-foreground ml-1">Method</Label>
                      <Select value={form.paymentMethod} onValueChange={(v) => setForm({ ...form, paymentMethod: v })}>
                        <SelectTrigger className="rounded-2xl border-border/60 bg-background/50 focus:ring-primary h-11"><SelectValue /></SelectTrigger>
                        <SelectContent className="bg-card/95 backdrop-blur-md border-border/60 rounded-xl">
                          {paymentMethods.map((m) => (
                            <SelectItem key={m.value} value={m.value} className="focus:bg-primary/10 rounded-lg">
                              <div className="flex items-center gap-2">
                                <m.icon className="w-3.5 h-3.5 opacity-60" />
                                {m.label}
                              </div>
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <DialogFooter className="pt-4 gap-2">
                    <Button type="button" variant="ghost" onClick={resetForm} className="rounded-xl h-11 font-bold text-muted-foreground hover:bg-muted/50">Cancel</Button>
                    <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending} className="rounded-xl h-11 px-8 bg-primary hover:bg-primary/95 text-white font-black shadow-lg shadow-primary/20 flex-1">
                      {editingId ? "Update Ledger" : "Commit Entry"}
                    </Button>
                  </DialogFooter>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-3xl p-0.5 overflow-hidden animate-stagger-fade" style={{ animationDelay: "100ms" }}>
          <div className="bg-card/50 backdrop-blur-xl rounded-[22px]">
            <div className="p-6 flex flex-col md:flex-row md:items-center justify-between border-b border-border/40 gap-6">
              <div className="space-y-1">
                <span className="text-[10px] uppercase tracking-widest text-muted-foreground font-black block ml-1 opacity-70">Monthly Outflow</span>
                <CardTitle className="text-3xl font-black font-sans text-red-500 tracking-tighter">
                  {formatCurrency(totalAmount)}
                </CardTitle>
              </div>
              <div className="flex items-center gap-3 flex-wrap">
                <div className="relative group">
                  <Search className="w-4 h-4 absolute left-3.5 top-3.5 text-muted-foreground/60 group-focus-within:text-primary transition-colors" />
                  <Input className="h-11 pl-10 w-[240px] rounded-2xl border-border/50 bg-background/40 focus-visible:ring-primary shadow-inner" placeholder="Search ledger..." value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
                <Select value={categoryFilter ? String(categoryFilter) : "all"} onValueChange={(v) => setCategoryFilter(v === "all" ? undefined : Number(v))}>
                  <SelectTrigger className="h-11 w-[160px] rounded-2xl border-border/50 bg-background/40 focus:ring-primary">
                    <div className="flex items-center gap-2">
                      <Filter className="w-3.5 h-3.5 text-muted-foreground" />
                      <SelectValue placeholder="All Categories" />
                    </div>
                  </SelectTrigger>
                  <SelectContent className="bg-card/95 backdrop-blur-xl border-border/50 rounded-xl shadow-glass">
                    <SelectItem value="all" className="focus:bg-primary/10 rounded-lg">All Categories</SelectItem>
                    {expenseCategories.map((c) => (
                      <SelectItem key={c.id} value={String(c.id)} className="focus:bg-primary/10 rounded-lg">{c.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            
            <div className="p-6">
              {isLoading ? (
                <div className="space-y-6">
                  {[...Array(3)].map((_, i) => (
                    <div key={i} className="space-y-3">
                      <Skeleton className="h-4 w-32 bg-muted/40 rounded" />
                      <Skeleton className="h-16 w-full bg-muted/30 rounded-2xl" />
                      <Skeleton className="h-16 w-full bg-muted/30 rounded-2xl" />
                    </div>
                  ))}
                </div>
              ) : groupedExpenses.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-20 text-center space-y-4">
                  <div className="w-20 h-20 rounded-full bg-muted/30 flex items-center justify-center">
                    <History className="w-10 h-10 text-muted-foreground/40" />
                  </div>
                  <div className="space-y-1">
                    <h4 className="font-bold font-display text-foreground">Clean Slate</h4>
                    <p className="text-xs text-muted-foreground max-w-[240px]">No recorded transactions found for this period or search criteria.</p>
                  </div>
                  <Button variant="outline" size="sm" onClick={() => { setSearch(""); setCategoryFilter(undefined); }} className="rounded-xl border-border/60">Reset Filters</Button>
                </div>
              ) : (
                <div className="space-y-10">
                  {groupedExpenses.map(([date, items], groupIdx) => (
                    <div key={date} className="space-y-4">
                      <div className="flex items-center gap-4">
                        <h3 className="text-xs font-black uppercase tracking-widest text-muted-foreground whitespace-nowrap bg-muted/40 px-3 py-1 rounded-full border border-border/20">
                          {formatDateHeader(date)}
                        </h3>
                        <div className="h-[1px] flex-1 bg-border/30" />
                        <span className="text-[10px] font-bold text-muted-foreground/60 tracking-widest uppercase">
                          {items.length} {items.length === 1 ? 'Entry' : 'Entries'}
                        </span>
                      </div>
                      
                      <div className="space-y-3">
                        {items.map((exp, idx) => (
                          <div
                            key={exp.id}
                            className="flex items-center justify-between p-4 rounded-2xl bg-card/30 border border-border/30 hover:border-primary/30 hover:bg-card/60 transition-all duration-300 group hover:-translate-y-0.5 shadow-sm relative overflow-hidden"
                            style={{ animationDelay: `${groupIdx * 50 + idx * 30}ms` }}
                          >
                            <div className="flex items-center gap-4 relative z-10">
                              <div
                                className="w-12 h-12 rounded-2xl flex items-center justify-center text-white text-xs font-black shadow-lg transition-transform group-hover:scale-110"
                                style={{
                                  backgroundColor: exp.categoryColor || "#6366f1",
                                  backgroundImage: `linear-gradient(135deg, ${exp.categoryColor}cc, ${exp.categoryColor}ff)`
                                }}
                              >
                                {exp.categoryName?.[0]?.toUpperCase() || "?"}
                              </div>
                              <div className="min-w-0">
                                <p className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate max-w-[200px] md:max-w-md">
                                  {exp.description || exp.categoryName}
                                </p>
                                <div className="flex items-center gap-3 mt-1.5 flex-wrap">
                                  <span className="text-[10px] font-bold text-foreground/60">{exp.categoryName}</span>
                                  <span className="w-1 h-1 rounded-full bg-muted-foreground/30" />
                                  <Badge variant="outline" className="text-[9px] font-black h-5 px-2 rounded-lg border-border/60 bg-muted/40 text-muted-foreground uppercase flex items-center gap-1.5 transition-colors group-hover:bg-primary/5 group-hover:border-primary/20 group-hover:text-primary/80">
                                    {getPaymentIcon(exp.paymentMethod)}
                                    {exp.paymentMethod.replace("_", " ")}
                                  </Badge>
                                  {exp.isRecurring && (
                                    <span className="text-[9px] font-black text-indigo-500 uppercase tracking-widest flex items-center gap-1 bg-indigo-500/5 px-1.5 py-0.5 rounded border border-indigo-500/10">
                                      Recurring
                                    </span>
                                  )}
                                </div>
                              </div>
                            </div>
                            
                            <div className="flex items-center gap-6 relative z-10">
                              <div className="text-right">
                                <span className="text-base font-black text-red-500 font-sans tracking-tight">
                                  -{formatCurrency(exp.amount)}
                                </span>
                                <p className="text-[9px] font-bold text-muted-foreground uppercase tracking-widest mt-0.5 opacity-0 group-hover:opacity-100 transition-opacity">Settled</p>
                              </div>
                              <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-all duration-300 -translate-x-2 group-hover:translate-x-0">
                                <Button variant="ghost" size="icon" className="h-9 w-9 rounded-xl hover:bg-muted/80 text-foreground" onClick={() => handleEdit(exp)}>
                                  <Pencil className="w-4 h-4" />
                                </Button>
                                <Button variant="ghost" size="icon" className="h-9 w-9 rounded-xl hover:bg-red-500/10 text-red-500" onClick={() => deleteMutation.mutate(exp.id)}>
                                  <Trash2 className="w-4 h-4" />
                                </Button>
                              </div>
                            </div>
                            
                            {/* Accent background for recurring */}
                            {exp.isRecurring && <div className="absolute top-0 right-0 w-1 h-full bg-indigo-500/20" />}
                          </div>
                        ))}
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
