import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Income as IncomeType } from "@/types";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
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
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import {
  Plus,
  Pencil,
  Trash2,
  TrendingUp,
  Wallet,
  Check,
  Calendar,
  Layers,
  Repeat,
  Search,
  ChevronDown,
  ChevronUp,
  ArrowUpRight,
  Sparkles,
  CheckCircle2,
  Clock,
  SlidersHorizontal,
  Info,
  AlertTriangle,
  Link2,
} from "lucide-react";
import { format } from "date-fns";

export default function Income() {
  const now = new Date();
  const [activeTab, setActiveTab] = useState<"monthly" | "yearly" | "all" | "recurring">("monthly");
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [searchQuery, setSearchQuery] = useState("");
  const [frequencyFilter, setFrequencyFilter] = useState<string>("all");
  const [expandedMonth, setExpandedMonth] = useState<number | null>(month);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [isCustomOverride, setIsCustomOverride] = useState(false);
  
  const [form, setForm] = useState({
    source: "",
    amount: "",
    originalAmount: "",
    incomeDate: format(now, "yyyy-MM-dd"),
    isRecurring: false,
    frequency: "monthly" as string,
    notes: "",
    parentId: null as number | null,
    isReceived: true,
    endDate: "",
    isCustom: false,
    changeReason: "",
  });

  const queryClient = useQueryClient();

  // Queries
  const { data: monthlyIncomes, isLoading: isLoadingMonthly } = useQuery({
    queryKey: ["incomes", "monthly", { month, year }],
    queryFn: () => api.incomes.list({ month, year }),
    enabled: activeTab === "monthly",
  });

  const { data: monthlySummary } = useQuery({
    queryKey: ["incomes", "summary", { month, year }],
    queryFn: () => api.incomes.summary({ month, year }),
    enabled: activeTab === "monthly",
  });

  const { data: yearlyData, isLoading: isLoadingYearly } = useQuery({
    queryKey: ["incomes", "yearly", { year }],
    queryFn: () => api.incomes.yearly({ year }),
    enabled: activeTab === "yearly",
  });

  const { data: allIncomes, isLoading: isLoadingAll } = useQuery({
    queryKey: ["incomes", "all"],
    queryFn: () => api.incomes.list({}),
    enabled: activeTab === "all" || activeTab === "recurring",
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["incomes"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    queryClient.invalidateQueries({ queryKey: ["reports"] });
  };

  const createMutation = useMutation({
    mutationFn: api.incomes.create,
    onSuccess: () => {
      invalidate();
      resetForm();
    },
  });

  const updateMutation = useMutation({
    mutationFn: api.incomes.update,
    onSuccess: () => {
      invalidate();
      resetForm();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: api.incomes.delete,
    onSuccess: invalidate,
  });

  const toggleReceivedMutation = useMutation({
    mutationFn: api.incomes.toggleReceived,
    onSuccess: invalidate,
  });

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
        isReceived: true,
        isCustom: inc.isCustom || false,
        changeReason: inc.changeReason || undefined,
        originalAmount: inc.originalAmount ? String(inc.originalAmount) : undefined,
      });
    }
  };

  const resetForm = () => {
    setForm({
      source: "",
      amount: "",
      originalAmount: "",
      incomeDate: format(new Date(), "yyyy-MM-dd"),
      isRecurring: false,
      frequency: "monthly",
      notes: "",
      parentId: null,
      isReceived: true,
      endDate: "",
      isCustom: false,
      changeReason: "",
    });
    setEditingId(null);
    setIsCustomOverride(false);
    setDialogOpen(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.source || !form.amount) return;

    const hasAmountChanged =
      form.originalAmount && parseFloat(form.amount) !== parseFloat(form.originalAmount);
    const isCustomFlag = form.isCustom || Boolean(hasAmountChanged) || Boolean(form.changeReason);

    const payload = {
      source: form.source,
      amount: form.amount,
      incomeDate: form.incomeDate,
      isRecurring: form.isRecurring,
      frequency: form.frequency as "monthly" | "quarterly" | "yearly" | "one_time",
      notes: form.notes || undefined,
      parentId: form.parentId,
      isReceived: form.isReceived,
      endDate: form.isRecurring && form.endDate ? form.endDate : null,
      isCustom: isCustomFlag,
      changeReason: form.changeReason || (hasAmountChanged ? "Month Custom Adjustment" : undefined),
      originalAmount: form.originalAmount || undefined,
    };

    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  const handleEdit = (inc: IncomeType) => {
    const isProjected = inc.id === null;
    const isOverride = Boolean(inc.parentId) || Boolean(inc.isCustom);
    setEditingId(inc.id);
    setIsCustomOverride(isOverride || isProjected);

    const origAmt = inc.originalAmount ? String(inc.originalAmount) : String(inc.amount);

    setForm({
      source: inc.source,
      amount: String(inc.amount),
      originalAmount: origAmt,
      incomeDate: inc.incomeDate
        ? format(new Date(inc.incomeDate), "yyyy-MM-dd")
        : format(new Date(), "yyyy-MM-dd"),
      isRecurring: inc.isRecurring,
      frequency: inc.frequency,
      notes: inc.notes || "",
      parentId: inc.parentId || null,
      isReceived: inc.isReceived,
      endDate: inc.endDate ? format(new Date(inc.endDate), "yyyy-MM-dd") : "",
      isCustom: inc.isCustom || isOverride,
      changeReason: inc.changeReason || "",
    });
    setDialogOpen(true);
  };

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 2,
    }).format(num || 0);
  };

  const monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  // Filtering for All Time list
  const filteredAllIncomes = (allIncomes || []).filter((inc) => {
    const matchesSearch =
      inc.source.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (inc.notes && inc.notes.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (inc.changeReason && inc.changeReason.toLowerCase().includes(searchQuery.toLowerCase()));
    const matchesFrequency = frequencyFilter === "all" || inc.frequency === frequencyFilter;
    return matchesSearch && matchesFrequency;
  });

  // Filter recurring templates
  const recurringTemplates = (allIncomes || []).filter((inc) => inc.isRecurring && !inc.parentId);

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-6">
        {/* Top Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-card/40 p-4 lg:p-6 rounded-2xl border border-border/40 backdrop-blur-md shadow-sm">
          <div>
            <div className="flex items-center gap-2.5">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-500 to-teal-400 flex items-center justify-center shadow-lg shadow-emerald-500/20 text-white">
                <Wallet className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-2xl font-bold tracking-tight text-foreground">Income Dashboard</h2>
                <p className="text-sm text-muted-foreground">
                  Track recurring salary, prefilled date ranges, gaps, and custom month overrides
                </p>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button
                  size="default"
                  className="rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 shadow-md shadow-emerald-600/20 text-white font-medium"
                  onClick={() => {
                    resetForm();
                    setDialogOpen(true);
                  }}
                >
                  <Plus className="w-4 h-4 mr-2" /> Add Income Source
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                  <DialogTitle className="text-xl font-bold flex items-center gap-2">
                    {editingId ? "Edit Income Entry" : "Record New Income"}
                    {isCustomOverride && (
                      <Badge className="bg-amber-500/10 text-amber-600 border-amber-500/30 text-xs">
                        Custom Override
                      </Badge>
                    )}
                  </DialogTitle>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4 pt-2">
                  <div>
                    <Label className="text-sm font-medium">Income Source</Label>
                    <Input
                      className="mt-1"
                      value={form.source}
                      onChange={(e) => setForm({ ...form, source: e.target.value })}
                      placeholder="e.g., Monthly Salary, Consulting Retainer, Performance Bonus"
                      required
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label className="text-sm font-medium">Amount (₹)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        className="mt-1 font-semibold text-emerald-600"
                        value={form.amount}
                        onChange={(e) => setForm({ ...form, amount: e.target.value })}
                        placeholder="0.00"
                        required
                      />
                      {form.originalAmount &&
                        parseFloat(form.amount) !== parseFloat(form.originalAmount) && (
                          <p className="text-[11px] text-muted-foreground mt-1">
                            Baseline Template: {formatCurrency(form.originalAmount)}
                          </p>
                        )}
                    </div>
                    <div>
                      <Label className="text-sm font-medium">Start Date</Label>
                      <Input
                        type="date"
                        className="mt-1"
                        value={form.incomeDate}
                        onChange={(e) => setForm({ ...form, incomeDate: e.target.value })}
                        required
                      />
                    </div>
                  </div>

                  {/* Change Reason / Custom Note (for Increments / Bonuses / Deductions) */}
                  {(form.parentId || form.isCustom || (form.originalAmount && parseFloat(form.amount) !== parseFloat(form.originalAmount))) && (
                    <div className="p-3 rounded-xl bg-amber-500/5 border border-amber-500/20 space-y-2">
                      <div className="flex items-center justify-between">
                        <Label className="text-xs font-semibold text-amber-700 dark:text-amber-400 flex items-center gap-1">
                          <SlidersHorizontal className="w-3.5 h-3.5" /> Month Variation / Reason
                        </Label>
                        <Badge variant="outline" className="text-[10px] border-amber-300 text-amber-600">
                          Custom Month Flag
                        </Badge>
                      </div>
                      <Input
                        className="text-xs bg-card"
                        value={form.changeReason}
                        onChange={(e) => setForm({ ...form, changeReason: e.target.value, isCustom: true })}
                        placeholder="e.g., Salary Increment (+₹15,000), Annual Bonus, Tax Adjustment"
                      />
                    </div>
                  )}

                  <div>
                    <Label className="text-sm font-medium">Frequency</Label>
                    <Select
                      value={form.frequency}
                      onValueChange={(v) => setForm({ ...form, frequency: v })}
                    >
                      <SelectTrigger className="mt-1">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="monthly">Monthly</SelectItem>
                        <SelectItem value="quarterly">Quarterly</SelectItem>
                        <SelectItem value="yearly">Yearly</SelectItem>
                        <SelectItem value="one_time">One Time</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-xl bg-muted/40 border border-border/50">
                    <div className="space-y-0.5">
                      <Label className="text-sm font-medium">Recurring Rule</Label>
                      <p className="text-xs text-muted-foreground">
                        Prefills upcoming date range automatically
                      </p>
                    </div>
                    <Switch
                      checked={form.isRecurring}
                      onCheckedChange={(v) => setForm({ ...form, isRecurring: v })}
                    />
                  </div>

                  {form.isRecurring && (
                    <div className="space-y-1.5 p-3 rounded-xl bg-blue-500/5 border border-blue-500/20">
                      <div className="flex items-center justify-between">
                        <Label className="text-xs font-semibold text-blue-700 dark:text-blue-400 flex items-center gap-1">
                          <Calendar className="w-3.5 h-3.5" /> Rule End Date (Optional)
                        </Label>
                        <span className="text-[10px] text-muted-foreground">
                          Leave blank for Latest / Ongoing Rule
                        </span>
                      </div>
                      <Input
                        type="date"
                        className="mt-1 text-xs bg-card"
                        value={form.endDate}
                        onChange={(e) => setForm({ ...form, endDate: e.target.value })}
                      />
                      <p className="text-[11px] text-muted-foreground leading-tight pt-1">
                        💡 <span className="font-semibold">Rule Rule Invariant:</span> Only the latest active recurring rule for a source can be ongoing without an end date. Historical rules will require start & end dates.
                      </p>
                    </div>
                  )}

                  <div className="flex items-center justify-between p-3 rounded-xl bg-muted/40 border border-border/50">
                    <div className="space-y-0.5">
                      <Label className="text-sm font-medium">Status: Received</Label>
                      <p className="text-xs text-muted-foreground">
                        Mark if payment is already credited to your account
                      </p>
                    </div>
                    <Switch
                      checked={form.isReceived}
                      onCheckedChange={(v) => setForm({ ...form, isReceived: v })}
                    />
                  </div>

                  <div>
                    <Label className="text-sm font-medium">Notes (Optional)</Label>
                    <Input
                      className="mt-1"
                      value={form.notes}
                      onChange={(e) => setForm({ ...form, notes: e.target.value })}
                      placeholder="Add details, transaction reference, or category tag"
                    />
                  </div>

                  <DialogFooter className="pt-2">
                    <Button type="button" variant="outline" onClick={resetForm} className="rounded-xl">
                      Cancel
                    </Button>
                    <Button
                      type="submit"
                      disabled={createMutation.isPending || updateMutation.isPending}
                      className="rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white"
                    >
                      {editingId ? "Save Changes" : "Create Income"}
                    </Button>
                  </DialogFooter>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        {/* View Mode Navigation Tabs */}
        <Tabs
          value={activeTab}
          onValueChange={(val) => setActiveTab(val as any)}
          className="w-full space-y-6"
        >
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-border/40 pb-3">
            <TabsList className="bg-card/60 backdrop-blur-md p-1 rounded-xl border border-border/40">
              <TabsTrigger value="monthly" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Calendar className="w-4 h-4" /> Monthly Prefilled List
              </TabsTrigger>
              <TabsTrigger value="yearly" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Layers className="w-4 h-4" /> Yearly Breakdown
              </TabsTrigger>
              <TabsTrigger value="all" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Wallet className="w-4 h-4" /> All Incomes
              </TabsTrigger>
              <TabsTrigger value="recurring" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Repeat className="w-4 h-4" /> Recurring Master Rules
              </TabsTrigger>
            </TabsList>

            {/* Month / Year Controls for Monthly and Yearly Tabs */}
            {activeTab === "monthly" && (
              <div className="flex items-center gap-2 bg-card/60 p-1.5 rounded-xl border border-border/40">
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 rounded-lg"
                  onClick={() => {
                    if (month === 1) {
                      setMonth(12);
                      setYear(year - 1);
                    } else setMonth(month - 1);
                  }}
                >
                  &larr;
                </Button>
                <span className="text-xs sm:text-sm font-semibold px-3 py-1 bg-muted/60 rounded-lg min-w-[120px] text-center">
                  {monthNames[month - 1]} {year}
                </span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 rounded-lg"
                  onClick={() => {
                    if (month === 12) {
                      setMonth(1);
                      setYear(year + 1);
                    } else setMonth(month + 1);
                  }}
                >
                  &rarr;
                </Button>
              </div>
            )}

            {activeTab === "yearly" && (
              <div className="flex items-center gap-2 bg-card/60 p-1.5 rounded-xl border border-border/40">
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 rounded-lg"
                  onClick={() => setYear(year - 1)}
                >
                  &larr;
                </Button>
                <span className="text-xs sm:text-sm font-semibold px-4 py-1 bg-muted/60 rounded-lg">
                  Year {year}
                </span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 rounded-lg"
                  onClick={() => setYear(year + 1)}
                >
                  &rarr;
                </Button>
              </div>
            )}
          </div>

          {/* TAB 1: MONTHLY VIEW */}
          <TabsContent value="monthly" className="space-y-6 m-0">
            {/* Summary Cards */}
            <div className="grid gap-4 md:grid-cols-3">
              <Card className="border border-border/40 bg-gradient-to-br from-emerald-500/10 via-card to-card">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Total Monthly Income
                  </CardTitle>
                  <Wallet className="w-4 h-4 text-emerald-500" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
                    {formatCurrency(monthlySummary?.total ?? "0")}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    {monthlySummary?.count ?? 0} prefilled & active entries
                  </p>
                </CardContent>
              </Card>

              <Card className="border border-border/40 bg-card/50">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Received Amount
                  </CardTitle>
                  <CheckCircle2 className="w-4 h-4 text-teal-500" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-foreground">
                    {formatCurrency(monthlySummary?.received ?? 0)}
                  </div>
                  <p className="text-xs text-emerald-600 dark:text-emerald-400 mt-1 font-medium">
                    {monthlySummary?.total
                      ? `${Math.round(((monthlySummary.received || 0) / (parseFloat(monthlySummary.total) || 1)) * 100)}% credited`
                      : "0% credited"}
                  </p>
                </CardContent>
              </Card>

              <Card className="border border-border/40 bg-card/50">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Expected / Pending
                  </CardTitle>
                  <Clock className="w-4 h-4 text-amber-500" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-amber-600 dark:text-amber-400">
                    {formatCurrency(monthlySummary?.expected ?? 0)}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">Pending receipt for {monthNames[month - 1]}</p>
                </CardContent>
              </Card>
            </div>

            {/* Income Entries List */}
            <Card className="border border-border/40 shadow-sm">
              <CardHeader className="flex flex-row items-center justify-between">
                <div>
                  <CardTitle className="text-lg font-bold">
                    Prefilled Income List ({monthNames[month - 1]} {year})
                  </CardTitle>
                  <CardDescription>
                    Prefilled from recurring rules. Modify any month to record increments or custom variations.
                  </CardDescription>
                </div>
              </CardHeader>
              <CardContent>
                {isLoadingMonthly ? (
                  <div className="space-y-3">
                    {[...Array(4)].map((_, i) => (
                      <Skeleton key={i} className="h-16 rounded-xl" />
                    ))}
                  </div>
                ) : !monthlyIncomes || monthlyIncomes.length === 0 ? (
                  <div className="text-center py-12 border border-dashed border-border/60 rounded-2xl bg-muted/20">
                    <Wallet className="w-10 h-10 mx-auto text-muted-foreground mb-3 opacity-60" />
                    <h3 className="font-semibold text-lg">No income recorded</h3>
                    <p className="text-sm text-muted-foreground mt-1 mb-4">
                      No income records or recurring rules found for {monthNames[month - 1]} {year}
                    </p>
                    <Button
                      size="sm"
                      onClick={() => {
                        resetForm();
                        setForm((f) => ({
                          ...f,
                          incomeDate: `${year}-${String(month).padStart(2, "0")}-01`,
                        }));
                        setDialogOpen(true);
                      }}
                      className="rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white"
                    >
                      <Plus className="w-4 h-4 mr-1" /> Add Income for this month
                    </Button>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {monthlyIncomes.map((inc, index) => {
                      const isCustom = Boolean(inc.isCustom);
                      const diff = inc.amountDifference ?? 0;
                      const hasDiff = Math.abs(diff) > 0.01;

                      return (
                        <div
                          key={inc.id ?? `proj-${index}`}
                          className={`flex flex-col sm:flex-row sm:items-center justify-between p-4 rounded-xl border transition-all gap-4 ${
                            isCustom
                              ? "border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10"
                              : "border-border/50 bg-card/60 hover:bg-muted/40"
                          }`}
                        >
                          <div className="flex items-center gap-3.5">
                            <div
                              className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
                                isCustom
                                  ? "bg-amber-500/15 text-amber-600 border border-amber-500/30"
                                  : "bg-emerald-500/10 border border-emerald-500/20 text-emerald-600"
                              }`}
                            >
                              {isCustom ? (
                                <SlidersHorizontal className="w-5 h-5" />
                              ) : (
                                <TrendingUp className="w-5 h-5" />
                              )}
                            </div>
                            <div>
                              <div className="flex items-center gap-2 flex-wrap">
                                <span className="font-semibold text-foreground text-base">
                                  {inc.source}
                                </span>
                                <Badge variant="outline" className="text-[10px] h-5 capitalize">
                                  {inc.frequency}
                                </Badge>
                                {inc.isRecurring && (
                                  <Badge
                                    variant="secondary"
                                    className="text-[10px] h-5 bg-emerald-500/10 text-emerald-600 border-emerald-500/20"
                                  >
                                    Recurring
                                  </Badge>
                                )}
                                {inc.id === null && (
                                  <Badge
                                    variant="outline"
                                    className="text-[10px] h-5 border-dashed border-indigo-300 text-indigo-600 bg-indigo-50/50"
                                  >
                                    Prefilled
                                  </Badge>
                                )}
                                {isCustom && (
                                  <Badge className="text-[10px] h-5 bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30 font-semibold">
                                    Custom Override
                                  </Badge>
                                )}
                                {hasDiff && diff > 0 && (
                                  <Badge className="text-[10px] h-5 bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30 font-bold">
                                    +{formatCurrency(diff)} Increment
                                  </Badge>
                                )}
                                {hasDiff && diff < 0 && (
                                  <Badge className="text-[10px] h-5 bg-rose-500/15 text-rose-700 dark:text-rose-300 border-rose-500/30 font-bold">
                                    {formatCurrency(diff)} Adjustment
                                  </Badge>
                                )}
                              </div>

                              <div className="flex items-center gap-3 text-xs text-muted-foreground mt-1 flex-wrap">
                                <span>
                                  Date: {inc.incomeDate ? format(new Date(inc.incomeDate), "dd MMM yyyy") : ""}
                                </span>
                                {inc.changeReason && (
                                  <span className="text-amber-600 dark:text-amber-400 font-medium">
                                    • Reason: {inc.changeReason}
                                  </span>
                                )}
                                {inc.notes && <span>• {inc.notes}</span>}
                                {inc.originalAmount && hasDiff && (
                                  <span className="text-muted-foreground">
                                    (Baseline: {formatCurrency(inc.originalAmount)})
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>

                          <div className="flex items-center justify-between sm:justify-end gap-4 border-t sm:border-t-0 pt-2 sm:pt-0 border-border/40">
                            <div className="text-right">
                              <div className="text-base font-bold text-emerald-600 dark:text-emerald-400">
                                +{formatCurrency(inc.amount)}
                              </div>
                              <div className="mt-0.5">
                                {inc.isReceived ? (
                                  <Badge
                                    variant="secondary"
                                    className="text-[10px] bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30"
                                  >
                                    Received
                                  </Badge>
                                ) : (
                                  <Badge
                                    variant="secondary"
                                    className="text-[10px] bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30"
                                  >
                                    Expected
                                  </Badge>
                                )}
                              </div>
                            </div>

                            <div className="flex items-center gap-1">
                              {!inc.isReceived && (
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 text-emerald-600 hover:bg-emerald-500/10 rounded-lg"
                                  onClick={() => handleToggleReceived(inc)}
                                  title="Mark as Received"
                                >
                                  <Check className="w-4 h-4" />
                                </Button>
                              )}
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-8 text-xs gap-1 rounded-lg text-muted-foreground hover:text-foreground"
                                onClick={() => handleEdit(inc)}
                                title="Customize or change month income data"
                              >
                                <Pencil className="w-3.5 h-3.5" />
                                <span>{isCustom ? "Edit Custom" : inc.id === null ? "Customize Month" : "Edit"}</span>
                              </Button>
                              {inc.id !== null && (
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 text-rose-500 hover:bg-rose-500/10 rounded-lg"
                                  onClick={() => deleteMutation.mutate(inc.id!)}
                                  title="Delete / Reset"
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </Button>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* TAB 2: YEARLY BREAKDOWN */}
          <TabsContent value="yearly" className="space-y-6 m-0">
            {/* Yearly Overview Stats */}
            <div className="grid gap-4 md:grid-cols-3">
              <Card className="border border-border/40 bg-gradient-to-br from-indigo-500/10 via-card to-card">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Total Income for {year}
                  </CardTitle>
                  <Sparkles className="w-4 h-4 text-indigo-500" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-indigo-600 dark:text-indigo-400">
                    {formatCurrency(yearlyData?.total_income ?? 0)}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">Full 12-month prefilled & custom total</p>
                </CardContent>
              </Card>

              <Card className="border border-border/40 bg-card/50">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Total Received YTD
                  </CardTitle>
                  <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
                    {formatCurrency(yearlyData?.total_received ?? 0)}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">Actual credited earnings</p>
                </CardContent>
              </Card>

              <Card className="border border-border/40 bg-card/50">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    Average Monthly Income
                  </CardTitle>
                  <TrendingUp className="w-4 h-4 text-teal-500" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-foreground">
                    {formatCurrency((yearlyData?.total_income ?? 0) / 12)}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">Monthly average for {year}</p>
                </CardContent>
              </Card>
            </div>

            {/* 12-Month Breakdown Table */}
            <Card className="border border-border/40 shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg font-bold">
                  12-Month Income Breakdown ({year})
                </CardTitle>
                <CardDescription>
                  Month-by-month summary showing prefilled recurring income, custom overrides, and bonuses
                </CardDescription>
              </CardHeader>
              <CardContent>
                {isLoadingYearly ? (
                  <div className="space-y-3">
                    {[...Array(6)].map((_, i) => (
                      <Skeleton key={i} className="h-12 rounded-xl" />
                    ))}
                  </div>
                ) : (
                  <div className="space-y-3">
                    {yearlyData?.months.map((m) => {
                      const isExpanded = expandedMonth === m.month;
                      const customCount = m.incomes.filter((i) => i.isCustom).length;

                      return (
                        <div
                          key={m.month}
                          className="border border-border/50 rounded-xl overflow-hidden bg-card/60"
                        >
                          <div
                            onClick={() => setExpandedMonth(isExpanded ? null : m.month)}
                            className="flex items-center justify-between p-4 cursor-pointer hover:bg-muted/40 transition-colors"
                          >
                            <div className="flex items-center gap-3">
                              <div className="w-9 h-9 rounded-lg bg-primary/10 border border-primary/20 flex items-center justify-center font-bold text-sm text-primary">
                                {m.month_name}
                              </div>
                              <div>
                                <div className="flex items-center gap-2">
                                  <h4 className="font-semibold text-foreground text-sm">
                                    {m.full_month_name} {year}
                                  </h4>
                                  {customCount > 0 && (
                                    <Badge className="text-[10px] h-4 bg-amber-500/15 text-amber-600 border-amber-500/30">
                                      {customCount} Custom Overrides
                                    </Badge>
                                  )}
                                </div>
                                <p className="text-xs text-muted-foreground">
                                  {m.count} income entries ({m.incomes.filter((i) => i.isReceived).length} received)
                                </p>
                              </div>
                            </div>

                            <div className="flex items-center gap-6">
                              <div className="text-right">
                                <div className="text-sm font-bold text-emerald-600 dark:text-emerald-400">
                                  {formatCurrency(m.total)}
                                </div>
                                <div className="text-[11px] text-muted-foreground">
                                  Received: {formatCurrency(m.received)}
                                </div>
                              </div>
                              <Button variant="ghost" size="icon" className="h-8 w-8">
                                {isExpanded ? (
                                  <ChevronUp className="w-4 h-4" />
                                ) : (
                                  <ChevronDown className="w-4 h-4" />
                                )}
                              </Button>
                            </div>
                          </div>

                          {/* Expanded Incomes List for this Month */}
                          {isExpanded && (
                            <div className="border-t border-border/40 p-4 bg-muted/20 space-y-2">
                              {m.incomes.length === 0 ? (
                                <p className="text-xs text-muted-foreground text-center py-3">
                                  No income entries recorded for {m.full_month_name}
                                </p>
                              ) : (
                                m.incomes.map((inc, i) => (
                                  <div
                                    key={inc.id ?? `ym-${i}`}
                                    className="flex items-center justify-between p-3 rounded-lg bg-card border border-border/30 text-xs"
                                  >
                                    <div className="flex items-center gap-2.5">
                                      <span className="font-medium text-foreground">{inc.source}</span>
                                      <Badge variant="outline" className="text-[10px] h-4">
                                        {inc.frequency}
                                      </Badge>
                                      {inc.isCustom && (
                                        <Badge className="text-[9px] h-4 bg-amber-500/15 text-amber-600 border-0">
                                          Custom Override
                                        </Badge>
                                      )}
                                      {inc.changeReason && (
                                        <span className="text-amber-600 text-[11px]">
                                          ({inc.changeReason})
                                        </span>
                                      )}
                                    </div>
                                    <div className="flex items-center gap-3">
                                      <span className="font-semibold text-emerald-600">
                                        +{formatCurrency(inc.amount)}
                                      </span>
                                      <Button
                                        variant="ghost"
                                        size="sm"
                                        className="h-6 text-[11px] px-2"
                                        onClick={() => handleEdit(inc)}
                                      >
                                        Edit
                                      </Button>
                                    </div>
                                  </div>
                                ))
                              )}
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* TAB 3: ALL INCOMES / MASTER INDEX */}
          <TabsContent value="all" className="space-y-6 m-0">
            <Card className="border border-border/40 shadow-sm">
              <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                  <CardTitle className="text-lg font-bold">Master Income Index</CardTitle>
                  <CardDescription>
                    Complete list of all recorded income transactions and custom month overrides
                  </CardDescription>
                </div>

                {/* Filter Controls */}
                <div className="flex flex-wrap items-center gap-3">
                  <div className="relative w-full sm:w-60">
                    <Search className="w-4 h-4 absolute left-3 top-2.5 text-muted-foreground" />
                    <Input
                      placeholder="Search source or reason..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-9 h-9 text-xs rounded-xl"
                    />
                  </div>

                  <Select value={frequencyFilter} onValueChange={setFrequencyFilter}>
                    <SelectTrigger className="w-[140px] h-9 text-xs rounded-xl">
                      <SelectValue placeholder="Frequency" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Frequencies</SelectItem>
                      <SelectItem value="monthly">Monthly</SelectItem>
                      <SelectItem value="quarterly">Quarterly</SelectItem>
                      <SelectItem value="yearly">Yearly</SelectItem>
                      <SelectItem value="one_time">One Time</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </CardHeader>
              <CardContent>
                {isLoadingAll ? (
                  <div className="space-y-3">
                    {[...Array(5)].map((_, i) => (
                      <Skeleton key={i} className="h-14 rounded-xl" />
                    ))}
                  </div>
                ) : filteredAllIncomes.length === 0 ? (
                  <div className="text-center py-10 text-muted-foreground">
                    No matching income records found
                  </div>
                ) : (
                  <div className="space-y-2">
                    {filteredAllIncomes.map((inc) => (
                      <div
                        key={inc.id}
                        className="flex flex-col sm:flex-row sm:items-center justify-between p-3.5 rounded-xl border border-border/50 bg-card/60 hover:bg-muted/40 transition-colors gap-3"
                      >
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-600">
                            <ArrowUpRight className="w-4 h-4" />
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <span className="font-semibold text-sm">{inc.source}</span>
                              <Badge variant="outline" className="text-[10px] h-4 capitalize">
                                {inc.frequency}
                              </Badge>
                              {inc.isRecurring && (
                                <Badge variant="secondary" className="text-[10px] h-4">
                                  Recurring
                                </Badge>
                              )}
                              {inc.isCustom && (
                                <Badge className="text-[10px] h-4 bg-amber-500/15 text-amber-600 border-0">
                                  Custom Override
                                </Badge>
                              )}
                            </div>
                            <div className="text-xs text-muted-foreground mt-0.5">
                              Date: {inc.incomeDate ? format(new Date(inc.incomeDate), "dd MMM yyyy") : ""}
                              {inc.changeReason && (
                                <span className="text-amber-600 font-medium"> • {inc.changeReason}</span>
                              )}
                              {inc.notes && ` • ${inc.notes}`}
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center justify-between sm:justify-end gap-3">
                          <span className="font-bold text-sm text-emerald-600">
                            +{formatCurrency(inc.amount)}
                          </span>
                          <div className="flex items-center gap-1">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-7 w-7 text-muted-foreground hover:text-foreground"
                              onClick={() => handleEdit(inc)}
                            >
                              <Pencil className="w-3.5 h-3.5" />
                            </Button>
                            {inc.id !== null && (
                              <Button
                                variant="ghost"
                                size="icon"
                                className="h-7 w-7 text-rose-500"
                                onClick={() => deleteMutation.mutate(inc.id!)}
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </Button>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              CardContent>
            </Card>
          </TabsContent>

          {/* TAB 4: RECURRING MASTER RULES & DATE RANGE VALIDATIONS */}
          <TabsContent value="recurring" className="space-y-6 m-0">
            <Card className="border border-border/40 shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg font-bold">Recurring Master Rules & Range Audits</CardTitle>
                <CardDescription>
                  Master income rules. Only the latest rule can be ongoing. Historical rules require start & end dates.
                </CardDescription>
              </CardHeader>
              <CardContent>
                {isLoadingAll ? (
                  <div className="space-y-3">
                    {[...Array(3)].map((_, i) => (
                      <Skeleton key={i} className="h-16 rounded-xl" />
                    ))}
                  </div>
                ) : recurringTemplates.length === 0 ? (
                  <div className="text-center py-10 text-muted-foreground">
                    No recurring income rules set up yet. When adding an income, toggle "Recurring Rule" to prefill date ranges.
                  </div>
                ) : (
                  <div className="grid gap-4 md:grid-cols-2">
                    {recurringTemplates.map((template) => {
                      const annualImpact =
                        template.frequency === "monthly"
                          ? parseFloat(template.amount) * 12
                          : template.frequency === "quarterly"
                          ? parseFloat(template.amount) * 4
                          : parseFloat(template.amount);

                      const isLatest = template.isLatestRecurring ?? !template.endDate;
                      const gapMessage = template.gapInfo;

                      return (
                        <Card
                          key={template.id}
                          className={`border transition-all ${
                            isLatest
                              ? "border-emerald-500/30 bg-card/80 hover:bg-card"
                              : "border-border/60 bg-muted/20 opacity-90"
                          }`}
                        >
                          <CardContent className="p-4 space-y-3">
                            <div className="flex items-start justify-between">
                              <div>
                                <div className="flex items-center gap-2 flex-wrap">
                                  <h4 className="font-bold text-base text-foreground">
                                    {template.source}
                                  </h4>
                                  {isLatest ? (
                                    <Badge className="bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30 text-[10px]">
                                      Latest / Ongoing Rule
                                    </Badge>
                                  ) : (
                                    <Badge variant="outline" className="text-[10px] text-muted-foreground">
                                      Historical Period
                                    </Badge>
                                  )}
                                </div>
                                <div className="flex items-center gap-2 mt-1 flex-wrap text-xs text-muted-foreground">
                                  <Badge className="bg-emerald-500/10 text-emerald-600 border-emerald-500/20 capitalize text-[10px]">
                                    {template.frequency}
                                  </Badge>
                                  <span>
                                    Start: {format(new Date(template.incomeDate), "dd MMM yyyy")}
                                  </span>
                                  <span>•</span>
                                  <span>
                                    End: {template.endDate ? format(new Date(template.endDate), "dd MMM yyyy") : "Ongoing (Present)"}
                                  </span>
                                </div>
                              </div>
                              <div className="text-right">
                                <div className="text-lg font-bold text-emerald-600">
                                  +{formatCurrency(template.amount)}
                                </div>
                                <div className="text-xs text-muted-foreground">
                                  ~{formatCurrency(annualImpact)} / year
                                </div>
                              </div>
                            </div>

                            {/* Gap / Overlap audit alert */}
                            {gapMessage && (
                              <div
                                className={`p-2.5 rounded-lg text-xs flex items-start gap-2 ${
                                  gapMessage.startsWith("Gap:")
                                    ? "bg-amber-500/10 border border-amber-500/20 text-amber-800 dark:text-amber-300"
                                    : gapMessage.startsWith("Overlap:")
                                    ? "bg-rose-500/10 border border-rose-500/20 text-rose-800 dark:text-rose-300"
                                    : "bg-blue-500/10 border border-blue-500/20 text-blue-800 dark:text-blue-300"
                                }`}
                              >
                                {gapMessage.startsWith("Gap:") ? (
                                  <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0 mt-0.5" />
                                ) : gapMessage.startsWith("Overlap:") ? (
                                  <AlertTriangle className="w-4 h-4 text-rose-500 flex-shrink-0 mt-0.5" />
                                ) : (
                                  <Link2 className="w-4 h-4 text-blue-500 flex-shrink-0 mt-0.5" />
                                )}
                                <span>{gapMessage}</span>
                              </div>
                            )}

                            {template.notes && (
                              <p className="text-xs text-muted-foreground bg-muted/30 p-2 rounded-lg">
                                {template.notes}
                              </p>
                            )}

                            <div className="flex items-center justify-between border-t border-border/40 pt-3">
                              <span className="text-xs text-muted-foreground">
                                {template.endDate
                                  ? `Closed range: ${format(new Date(template.incomeDate), "MMM yyyy")} to ${format(new Date(template.endDate), "MMM yyyy")}`
                                  : "Ongoing active rule for future months"}
                              </span>
                              <div className="flex items-center gap-1">
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs"
                                  onClick={() => handleEdit(template)}
                                >
                                  <Pencil className="w-3 h-3 mr-1" /> Edit Rule
                                </Button>
                                {template.id !== null && (
                                  <Button
                                    variant="ghost"
                                    size="sm"
                                    className="h-7 text-xs text-rose-500"
                                    onClick={() => deleteMutation.mutate(template.id!)}
                                  >
                                    <Trash2 className="w-3 h-3 mr-1" /> Delete Rule
                                  </Button>
                                )}
                              </div>
                            </div>
                          </CardContent>
                        </Card>
                      );
                    })}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
