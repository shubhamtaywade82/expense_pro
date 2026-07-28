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
  const [form, setForm] = useState({
    source: "",
    amount: "",
    incomeDate: format(now, "yyyy-MM-dd"),
    isRecurring: false,
    frequency: "monthly" as string,
    notes: "",
    parentId: null as number | null,
    isReceived: true,
    endDate: "",
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
      endDate: "",
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
      endDate: form.isRecurring && form.endDate ? form.endDate : null,
    };
    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  const handleEdit = (inc: IncomeType) => {
    setEditingId(inc.id);
    setForm({
      source: inc.source,
      amount: String(inc.amount),
      incomeDate: inc.incomeDate
        ? format(new Date(inc.incomeDate), "yyyy-MM-dd")
        : format(new Date(), "yyyy-MM-dd"),
      isRecurring: inc.isRecurring,
      frequency: inc.frequency,
      notes: inc.notes || "",
      parentId: inc.parentId || null,
      isReceived: inc.isReceived,
      endDate: inc.endDate ? format(new Date(inc.endDate), "yyyy-MM-dd") : "",
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
      (inc.notes && inc.notes.toLowerCase().includes(searchQuery.toLowerCase()));
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
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-500 to-teal-400 flex items-center justify-center shadow-lg shadow-emerald-500/20 text-white">
                <Wallet className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-2xl font-bold tracking-tight text-foreground">Income Dashboard</h2>
                <p className="text-sm text-muted-foreground">
                  Track monthly earnings, annual projections, and recurring income streams
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
              <DialogContent className="sm:max-w-[480px]">
                <DialogHeader>
                  <DialogTitle className="text-xl font-bold">
                    {editingId ? "Edit Income Entry" : "Record New Income"}
                  </DialogTitle>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4 pt-2">
                  <div>
                    <Label className="text-sm font-medium">Income Source</Label>
                    <Input
                      className="mt-1"
                      value={form.source}
                      onChange={(e) => setForm({ ...form, source: e.target.value })}
                      placeholder="e.g., Monthly Salary, Freelance Client, Investment Return"
                      required
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label className="text-sm font-medium">Amount (₹)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        className="mt-1"
                        value={form.amount}
                        onChange={(e) => setForm({ ...form, amount: e.target.value })}
                        placeholder="0.00"
                        required
                      />
                    </div>
                    <div>
                      <Label className="text-sm font-medium">Date</Label>
                      <Input
                        type="date"
                        className="mt-1"
                        value={form.incomeDate}
                        onChange={(e) => setForm({ ...form, incomeDate: e.target.value })}
                        required
                      />
                    </div>
                  </div>
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
                      <Label className="text-sm font-medium">Recurring Source</Label>
                      <p className="text-xs text-muted-foreground">
                        Automatically projects future earnings
                      </p>
                    </div>
                    <Switch
                      checked={form.isRecurring}
                      onCheckedChange={(v) => setForm({ ...form, isRecurring: v })}
                    />
                  </div>
                  {form.isRecurring && (
                    <div>
                      <Label className="text-sm font-medium">End Date (Optional)</Label>
                      <Input
                        type="date"
                        className="mt-1"
                        value={form.endDate}
                        onChange={(e) => setForm({ ...form, endDate: e.target.value })}
                      />
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
                      {editingId ? "Update Income" : "Save Income"}
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
                <Calendar className="w-4 h-4" /> Monthly View
              </TabsTrigger>
              <TabsTrigger value="yearly" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Layers className="w-4 h-4" /> Yearly Breakdown
              </TabsTrigger>
              <TabsTrigger value="all" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Wallet className="w-4 h-4" /> All Incomes
              </TabsTrigger>
              <TabsTrigger value="recurring" className="rounded-lg gap-2 text-xs sm:text-sm">
                <Repeat className="w-4 h-4" /> Recurring Rules
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
                    {monthlySummary?.count ?? 0} expected & received entries
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
                  <p className="text-xs text-muted-foreground mt-1">Pending receipt this month</p>
                </CardContent>
              </Card>
            </div>

            {/* Income Entries Table / List */}
            <Card className="border border-border/40 shadow-sm">
              <CardHeader className="flex flex-row items-center justify-between">
                <div>
                  <CardTitle className="text-lg font-bold">
                    Income List for {monthNames[month - 1]} {year}
                  </CardTitle>
                  <CardDescription>
                    All active income records and projected recurring items for this month
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
                      No income records or projections found for {monthNames[month - 1]} {year}
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
                  <div className="space-y-2">
                    {monthlyIncomes.map((inc, index) => (
                      <div
                        key={inc.id ?? `proj-${index}`}
                        className="flex flex-col sm:flex-row sm:items-center justify-between p-4 rounded-xl border border-border/50 bg-card/60 hover:bg-muted/40 transition-all gap-4"
                      >
                        <div className="flex items-center gap-3.5">
                          <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center flex-shrink-0 text-emerald-600">
                            <TrendingUp className="w-5 h-5" />
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
                                  Auto Projected
                                </Badge>
                              )}
                            </div>

                            <div className="flex items-center gap-3 text-xs text-muted-foreground mt-1 flex-wrap">
                              <span>
                                Date: {inc.incomeDate ? format(new Date(inc.incomeDate), "dd MMM yyyy") : ""}
                              </span>
                              {inc.notes && <span>• {inc.notes}</span>}
                              {inc.endDate && (
                                <span className="text-rose-500 font-medium">
                                  • Ends: {format(new Date(inc.endDate), "dd MMM yyyy")}
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
                            {inc.id !== null && (
                              <>
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 text-muted-foreground hover:text-foreground rounded-lg"
                                  onClick={() => handleEdit(inc)}
                                >
                                  <Pencil className="w-3.5 h-3.5" />
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 text-rose-500 hover:bg-rose-500/10 rounded-lg"
                                  onClick={() => deleteMutation.mutate(inc.id!)}
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </Button>
                              </>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
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
                  <p className="text-xs text-muted-foreground mt-1">Full 12-month projected total</p>
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
                  Month-by-month summary of total earnings, received status, and items list
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
                                <h4 className="font-semibold text-foreground text-sm">
                                  {m.full_month_name} {year}
                                </h4>
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
                                    className="flex items-center justify-between p-2.5 rounded-lg bg-card border border-border/30 text-xs"
                                  >
                                    <div className="flex items-center gap-2">
                                      <span className="font-medium text-foreground">{inc.source}</span>
                                      <Badge variant="outline" className="text-[10px] h-4">
                                        {inc.frequency}
                                      </Badge>
                                      {inc.isReceived ? (
                                        <Badge className="text-[9px] h-4 bg-emerald-500/15 text-emerald-600 border-0">
                                          Received
                                        </Badge>
                                      ) : (
                                        <Badge className="text-[9px] h-4 bg-amber-500/15 text-amber-600 border-0">
                                          Expected
                                        </Badge>
                                      )}
                                    </div>
                                    <div className="font-semibold text-emerald-600">
                                      +{formatCurrency(inc.amount)}
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
                    Complete list of all recorded income transactions across all dates
                  </CardDescription>
                </div>

                {/* Filter Controls */}
                <div className="flex flex-wrap items-center gap-3">
                  <div className="relative w-full sm:w-60">
                    <Search className="w-4 h-4 absolute left-3 top-2.5 text-muted-foreground" />
                    <Input
                      placeholder="Search income source..."
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
                            </div>
                            <div className="text-xs text-muted-foreground mt-0.5">
                              Date: {inc.incomeDate ? format(new Date(inc.incomeDate), "dd MMM yyyy") : ""}
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
              </CardContent>
            </Card>
          </TabsContent>

          {/* TAB 4: RECURRING RULES / TEMPLATES */}
          <TabsContent value="recurring" className="space-y-6 m-0">
            <Card className="border border-border/40 shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg font-bold">Recurring Income Rules</CardTitle>
                <CardDescription>
                  Master recurring income templates that auto-project into future months
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
                    No recurring income rules set up yet. When adding an income, toggle "Recurring Source" to auto-project it.
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

                      return (
                        <Card
                          key={template.id}
                          className="border border-emerald-500/20 bg-card/60 hover:bg-card transition-all"
                        >
                          <CardContent className="p-4 space-y-3">
                            <div className="flex items-start justify-between">
                              <div>
                                <h4 className="font-bold text-base text-foreground">
                                  {template.source}
                                </h4>
                                <div className="flex items-center gap-2 mt-1">
                                  <Badge className="bg-emerald-500/10 text-emerald-600 border-emerald-500/20 capitalize">
                                    {template.frequency}
                                  </Badge>
                                  <span className="text-xs text-muted-foreground">
                                    Started: {format(new Date(template.incomeDate), "dd MMM yyyy")}
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

                            {template.notes && (
                              <p className="text-xs text-muted-foreground bg-muted/30 p-2 rounded-lg">
                                {template.notes}
                              </p>
                            )}

                            <div className="flex items-center justify-between border-t border-border/40 pt-3">
                              <span className="text-xs text-muted-foreground">
                                {template.endDate
                                  ? `Active until ${format(new Date(template.endDate), "dd MMM yyyy")}`
                                  : "Ongoing active rule"}
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
                                    <Trash2 className="w-3 h-3 mr-1" /> Delete
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
