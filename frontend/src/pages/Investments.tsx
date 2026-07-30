import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router";
import { api } from "@/lib/api";
import type { Investment as InvestmentType, InvestmentAssetClass } from "@/types";
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
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import {
  Plus,
  Pencil,
  Trash2,
  TrendingUp,
  TrendingDown,
  BarChart3,
  DollarSign,
  PieChart,
  Zap,
  Briefcase,
  Layers,
  Sparkles,
  Coins,
  ShieldCheck,
  Building2,
  Landmark,
  ExternalLink,
  RefreshCw,
} from "lucide-react";
import { format, formatDistanceToNow } from "date-fns";
import { toast } from "sonner";

function brokerNum(val: unknown) {
  return typeof val === "string" ? parseFloat(val) : typeof val === "number" ? val : 0;
}

function brokerCurrency(val: unknown) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(brokerNum(val));
}

function brokerSymbol(row: Record<string, unknown>) {
  if (row.trading_symbol) return String(row.trading_symbol);
  const parts = [row.drv_strike_price, row.drv_option_type, row.drv_expiry_date].filter(Boolean).map(String);
  if (parts.length) return parts.join(" ");
  return row.security_id ? `#${row.security_id}` : "—";
}

// Read-only view of persisted broker holdings/positions (BrokerSnapshot, via
// /api/v1/broker_snapshots) — fast, no live broker call. Covers every
// connected broker (currently just Dhan); not merged into the totals above
// since this data hasn't been classified/imported into Investment records —
// only Dhan Settings > Import does that, and only for intraday/F&O.
function BrokerHoldingsPanel() {
  const snapshots = useQuery({
    queryKey: ["broker_snapshots"],
    queryFn: api.brokerSnapshots.list,
  });

  if (snapshots.isLoading) return <Skeleton className="h-32 rounded-2xl mb-6" />;

  const holdings = snapshots.data?.holdings ?? [];
  const positions = snapshots.data?.positions ?? [];
  if (holdings.length === 0 && positions.length === 0) return null;

  return (
    <Card className="border border-border/40 shadow-sm mb-6">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle className="flex items-center gap-2 text-base font-bold">
            <Landmark className="w-4 h-4 text-cyan-500" /> Connected Broker Data
          </CardTitle>
          <CardDescription>
            Live holdings & open positions from your connected brokers.
            {snapshots.data?.last_synced_at && (
              <> Synced {formatDistanceToNow(new Date(snapshots.data.last_synced_at), { addSuffix: true })}.</>
            )}{" "}
            Not counted in the totals below until imported.
          </CardDescription>
        </div>
        <Link to="/dhan" className="text-xs text-cyan-600 hover:underline flex items-center gap-1 whitespace-nowrap">
          Open Broker Dashboard <ExternalLink className="w-3 h-3" />
        </Link>
      </CardHeader>
      <CardContent className="space-y-4">
        {holdings.length > 0 && (
          <div>
            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2">Demat Holdings</p>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {holdings.map((h, i) => (
                <div key={i} className="p-2.5 rounded-lg bg-muted/30 border border-border/40 text-xs flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-medium text-foreground truncate">{brokerSymbol(h)}</p>
                    <p className="text-muted-foreground">Qty: {String(h.total_qty ?? "—")} · {String(h.broker ?? "dhan")}</p>
                  </div>
                  <span className="font-semibold text-foreground flex-shrink-0">{brokerCurrency(h.avg_cost_price)}</span>
                </div>
              ))}
            </div>
          </div>
        )}
        {positions.length > 0 && (
          <div>
            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2">Open Positions</p>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {positions.map((p, i) => {
                const pnl = brokerNum(p.unrealized_profit) + brokerNum(p.realized_profit);
                return (
                  <div key={i} className="p-2.5 rounded-lg bg-muted/30 border border-border/40 text-xs flex items-center justify-between gap-2">
                    <div className="min-w-0">
                      <p className="font-medium text-foreground truncate">{brokerSymbol(p)}</p>
                      <p className="text-muted-foreground">{String(p.position_type ?? "")} {String(p.net_qty ?? "—")} · {String(p.broker ?? "dhan")}</p>
                    </div>
                    <span className={`font-semibold flex-shrink-0 ${pnl >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                      {pnl >= 0 ? "+" : ""}{brokerCurrency(pnl)}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function currentFy() {
  const now = new Date();
  return now.getMonth() >= 3 ? now.getFullYear() + 1 : now.getFullYear();
}

export default function Investments() {
  const [activeAssetClass, setActiveAssetClass] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [financialYear, setFinancialYear] = useState(currentFy());
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);

  const [form, setForm] = useState({
    name: "",
    assetClass: "long_term_equity" as InvestmentAssetClass,
    symbol: "",
    quantity: "1",
    buyPrice: "",
    currentPrice: "",
    sellPrice: "",
    purchaseDate: format(new Date(), "yyyy-MM-dd"),
    sellDate: "",
    status: "active" as "active" | "realized",
    notes: "",
  });

  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["investments", { assetClass: activeAssetClass, status: statusFilter, financialYear }],
    queryFn: () => api.investments.list({ assetClass: activeAssetClass, status: statusFilter, financialYear }),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["investments"] });
    queryClient.invalidateQueries({ queryKey: ["tax"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const createMutation = useMutation({
    mutationFn: api.investments.create,
    onSuccess: () => {
      invalidate();
      resetForm();
    },
  });

  const updateMutation = useMutation({
    mutationFn: api.investments.update,
    onSuccess: () => {
      invalidate();
      resetForm();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: api.investments.delete,
    onSuccess: invalidate,
  });

  const syncMutation = useMutation({
    mutationFn: () => api.dhan.syncInvestments(),
    onSuccess: () => {
      toast.success("Sync started in background");
      const poll = () => {
        api.dhan.syncStatus().then((s) => {
          if (s.status === "completed") {
            invalidate();
            toast.success(`Synced ${s.trades_imported} trades from Dhan`);
          } else if (s.status === "truncated") {
            invalidate();
            toast.warning("Snapshots synced, trade history too large — import per month from Dhan page");
          } else {
            setTimeout(poll, 3000);
          }
        }).catch(() => setTimeout(poll, 3000));
      };
      setTimeout(poll, 3000);
    },
    onError: (error: Error) => {
      toast.error(error.message || "Sync failed");
    },
  });

  const resetForm = () => {
    setForm({
      name: "",
      assetClass: "long_term_equity",
      symbol: "",
      quantity: "1",
      buyPrice: "",
      currentPrice: "",
      sellPrice: "",
      purchaseDate: format(new Date(), "yyyy-MM-dd"),
      sellDate: "",
      status: "active",
      notes: "",
    });
    setEditingId(null);
    setDialogOpen(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.buyPrice) return;

    const payload = {
      name: form.name,
      assetClass: form.assetClass,
      symbol: form.symbol || undefined,
      quantity: form.quantity,
      buyPrice: form.buyPrice,
      currentPrice: form.currentPrice || undefined,
      sellPrice: form.sellPrice || undefined,
      purchaseDate: form.purchaseDate,
      sellDate: form.status === "realized" && form.sellDate ? form.sellDate : undefined,
      status: form.status,
      notes: form.notes || undefined,
    };

    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  const handleEdit = (inv: InvestmentType) => {
    setEditingId(inv.id);
    setForm({
      name: inv.name,
      assetClass: inv.assetClass,
      symbol: inv.symbol || "",
      quantity: String(inv.quantity),
      buyPrice: String(inv.buyPrice),
      currentPrice: inv.currentPrice ? String(inv.currentPrice) : "",
      sellPrice: inv.sellPrice ? String(inv.sellPrice) : "",
      purchaseDate: inv.purchaseDate
        ? format(new Date(inv.purchaseDate), "yyyy-MM-dd")
        : format(new Date(), "yyyy-MM-dd"),
      sellDate: inv.sellDate ? format(new Date(inv.sellDate), "yyyy-MM-dd") : "",
      status: inv.status,
      notes: inv.notes || "",
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

  const assetClassLabels: Record<InvestmentAssetClass, { label: string; badgeClass: string }> = {
    speculative_intraday: { label: "Speculative (Intraday)", badgeClass: "bg-rose-500/15 text-rose-700 dark:text-rose-300 border-rose-500/30" },
    non_speculative_fo: { label: "F&O (Non-Speculative)", badgeClass: "bg-indigo-500/15 text-indigo-700 dark:text-indigo-300 border-indigo-500/30" },
    swing_trading: { label: "Swing Trading", badgeClass: "bg-blue-500/15 text-blue-700 dark:text-blue-300 border-blue-500/30" },
    long_term_equity: { label: "Long-Term Equity", badgeClass: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30" },
    mutual_funds: { label: "Mutual Funds", badgeClass: "bg-teal-500/15 text-teal-700 dark:text-teal-300 border-teal-500/30" },
    fixed_income: { label: "Fixed Income / Bonds", badgeClass: "bg-purple-500/15 text-purple-700 dark:text-purple-300 border-purple-500/30" },
    crypto: { label: "Crypto Assets", badgeClass: "bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30" },
    elss_80c: { label: "ELSS 80C Tax Saver", badgeClass: "bg-cyan-500/15 text-cyan-700 dark:text-cyan-300 border-cyan-500/30" },
    gold: { label: "Gold / Sovereign Bonds", badgeClass: "bg-yellow-500/15 text-yellow-700 dark:text-yellow-300 border-yellow-500/30" },
  };

  const summary = data?.summary;
  const investmentsList = data?.investments || [];

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1 space-y-6 pb-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-card/40 p-4 lg:p-6 rounded-2xl border border-border/40 backdrop-blur-md shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-500 to-violet-500 flex items-center justify-center shadow-lg shadow-indigo-500/20 text-white">
            <TrendingUp className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-2xl font-bold tracking-tight text-foreground">
              Investments & Trading Portfolio
            </h2>
            <p className="text-sm text-muted-foreground">
              Manage F&O, Speculative Intraday, Swing Trading, STCG/LTCG Equity, Mutual Funds & Crypto
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1 bg-card/60 p-1 rounded-xl border border-border/40">
            <button
              type="button"
              className="px-2 h-7 rounded-lg text-[11px] font-medium bg-cyan-600 text-white"
            >
              FY
            </button>
          </div>
          <div className="flex items-center gap-1 text-xs">
            <button
              type="button"
              className="h-7 w-7 rounded-lg hover:bg-muted/60 flex items-center justify-center text-muted-foreground hover:text-foreground"
              onClick={() => setFinancialYear((y) => y - 1)}
            >
              &larr;
            </button>
            <span className="font-semibold px-2 min-w-[90px] text-center text-sm">
              FY {financialYear - 1}-{String(financialYear).slice(2)}
            </span>
            <button
              type="button"
              className="h-7 w-7 rounded-lg hover:bg-muted/60 flex items-center justify-center text-muted-foreground hover:text-foreground"
              onClick={() => setFinancialYear((y) => y + 1)}
            >
              &rarr;
            </button>
          </div>

          <Button
            size="sm"
            variant="outline"
            className="rounded-xl gap-1.5 border-emerald-500/30 text-emerald-700 hover:bg-emerald-50 dark:text-emerald-400 dark:hover:bg-emerald-950/30"
            onClick={() => syncMutation.mutate()}
            disabled={syncMutation.isPending}
          >
            <RefreshCw className={`w-3.5 h-3.5 ${syncMutation.isPending ? "animate-spin" : ""}`} />
            {syncMutation.isPending ? "Syncing..." : "Sync from Dhan"}
          </Button>
        </div>

        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger asChild>
            <Button
              className="rounded-xl bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 shadow-md shadow-indigo-600/20 text-white font-medium"
              onClick={() => {
                resetForm();
                setDialogOpen(true);
              }}
            >
              <Plus className="w-4 h-4 mr-2" /> Add Position / Trade
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[500px]">
            <DialogHeader>
              <DialogTitle className="text-xl font-bold">
                {editingId ? "Edit Investment Position" : "Record New Investment / Trade"}
              </DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSubmit} className="space-y-4 pt-2">
              <div>
                <Label className="text-sm font-medium">Asset Name / Title</Label>
                <Input
                  className="mt-1"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g. Nifty 50 Index Fund, Tata Motors Swing, Nifty 24500 CE"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label className="text-sm font-medium">Asset Classification</Label>
                  <Select
                    value={form.assetClass}
                    onValueChange={(v) => setForm({ ...form, assetClass: v as InvestmentAssetClass })}
                  >
                    <SelectTrigger className="mt-1">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="speculative_intraday">Speculative (Intraday)</SelectItem>
                      <SelectItem value="non_speculative_fo">F&O (Non-Speculative)</SelectItem>
                      <SelectItem value="swing_trading">Swing Trading</SelectItem>
                      <SelectItem value="long_term_equity">Long-Term Equity</SelectItem>
                      <SelectItem value="mutual_funds">Mutual Funds</SelectItem>
                      <SelectItem value="elss_80c">ELSS 80C Tax Saver</SelectItem>
                      <SelectItem value="fixed_income">Fixed Income / Bonds</SelectItem>
                      <SelectItem value="crypto">Crypto Assets</SelectItem>
                      <SelectItem value="gold">Gold / SGB</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label className="text-sm font-medium">Ticker Symbol (Optional)</Label>
                  <Input
                    className="mt-1"
                    value={form.symbol}
                    onChange={(e) => setForm({ ...form, symbol: e.target.value })}
                    placeholder="e.g., TATAMOTORS"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label className="text-sm font-medium">Quantity / Units</Label>
                  <Input
                    type="number"
                    step="any"
                    className="mt-1"
                    value={form.quantity}
                    onChange={(e) => setForm({ ...form, quantity: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label className="text-sm font-medium">Buy Price (₹)</Label>
                  <Input
                    type="number"
                    step="0.01"
                    className="mt-1"
                    value={form.buyPrice}
                    onChange={(e) => setForm({ ...form, buyPrice: e.target.value })}
                    placeholder="0.00"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label className="text-sm font-medium">Status</Label>
                  <Select
                    value={form.status}
                    onValueChange={(v) => setForm({ ...form, status: v as "active" | "realized" })}
                  >
                    <SelectTrigger className="mt-1">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="active">Active Holding</SelectItem>
                      <SelectItem value="realized">Realized / Closed Trade</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <Label className="text-sm font-medium">Purchase Date</Label>
                  <Input
                    type="date"
                    className="mt-1"
                    value={form.purchaseDate}
                    onChange={(e) => setForm({ ...form, purchaseDate: e.target.value })}
                    required
                  />
                </div>
              </div>

              {form.status === "active" ? (
                <div>
                  <Label className="text-sm font-medium">Current Price (₹ - Optional)</Label>
                  <Input
                    type="number"
                    step="0.01"
                    className="mt-1"
                    value={form.currentPrice}
                    onChange={(e) => setForm({ ...form, currentPrice: e.target.value })}
                    placeholder="Leave blank if unknown"
                  />
                </div>
              ) : (
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-sm font-medium">Sell Price (₹)</Label>
                    <Input
                      type="number"
                      step="0.01"
                      className="mt-1"
                      value={form.sellPrice}
                      onChange={(e) => setForm({ ...form, sellPrice: e.target.value })}
                      placeholder="0.00"
                      required
                    />
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Sell Date</Label>
                    <Input
                      type="date"
                      className="mt-1"
                      value={form.sellDate}
                      onChange={(e) => setForm({ ...form, sellDate: e.target.value })}
                    />
                  </div>
                </div>
              )}

              <div>
                <Label className="text-sm font-medium">Notes / Strategy Tags</Label>
                <Input
                  className="mt-1"
                  value={form.notes}
                  onChange={(e) => setForm({ ...form, notes: e.target.value })}
                  placeholder="e.g., Breakout trade, Core 80C investment, Hedging position"
                />
              </div>

              <DialogFooter className="pt-2">
                <Button type="button" variant="outline" onClick={resetForm} className="rounded-xl">
                  Cancel
                </Button>
                <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending} className="rounded-xl bg-indigo-600 text-white hover:bg-indigo-500">
                  {editingId ? "Update Position" : "Save Position"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <BrokerHoldingsPanel />

      {/* Portfolio Summary Cards */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card className="border border-border/40 bg-gradient-to-br from-indigo-500/10 via-card to-card">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Invested Amount</CardTitle>
            <Briefcase className="w-4 h-4 text-indigo-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {formatCurrency(summary?.total_invested ?? "0")}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Across {summary?.count ?? 0} active & closed positions</p>
          </CardContent>
        </Card>

        <Card className="border border-border/40 bg-card/50">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Current Portfolio Value</CardTitle>
            <PieChart className="w-4 h-4 text-teal-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {formatCurrency(summary?.current_value ?? "0")}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Real-time total position valuation</p>
          </CardContent>
        </Card>

        <Card className="border border-border/40 bg-card/50">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Net P&L (Realized + Unrealized)</CardTitle>
            {parseFloat(summary?.total_pnl ?? "0") >= 0 ? (
              <TrendingUp className="w-4 h-4 text-emerald-500" />
            ) : (
              <TrendingDown className="w-4 h-4 text-rose-500" />
            )}
          </CardHeader>
          <CardContent>
            <div
              className={`text-2xl font-bold ${
                parseFloat(summary?.total_pnl ?? "0") >= 0
                  ? "text-emerald-600 dark:text-emerald-400"
                  : "text-rose-600 dark:text-rose-400"
              }`}
            >
              {parseFloat(summary?.total_pnl ?? "0") >= 0 ? "+" : ""}
              {formatCurrency(summary?.total_pnl ?? "0")}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Net profit/loss generated</p>
          </CardContent>
        </Card>
      </div>

      {/* Asset Classification Filter Tabs */}
      <Tabs
        value={activeAssetClass}
        onValueChange={setActiveAssetClass}
        className="w-full space-y-6"
      >
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-border/40 pb-3">
          <TabsList className="bg-card/60 backdrop-blur-md p-1 rounded-xl border border-border/40 flex-wrap h-auto">
            <TabsTrigger value="all" className="rounded-lg text-xs">All Holdings</TabsTrigger>
            <TabsTrigger value="long_term_equity" className="rounded-lg text-xs">Long-Term Equity</TabsTrigger>
            <TabsTrigger value="swing_trading" className="rounded-lg text-xs">Swing Trading</TabsTrigger>
            <TabsTrigger value="non_speculative_fo" className="rounded-lg text-xs">F&O Trading</TabsTrigger>
            <TabsTrigger value="speculative_intraday" className="rounded-lg text-xs">Speculative Intraday</TabsTrigger>
            <TabsTrigger value="mutual_funds" className="rounded-lg text-xs">Mutual Funds / 80C</TabsTrigger>
            <TabsTrigger value="crypto" className="rounded-lg text-xs">Crypto</TabsTrigger>
          </TabsList>

          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-[140px] h-9 text-xs rounded-xl">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Statuses</SelectItem>
              <SelectItem value="active">Active Only</SelectItem>
              <SelectItem value="realized">Closed / Realized</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <TabsContent value={activeAssetClass} className="space-y-4 m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg font-bold">Investment Positions & Trades</CardTitle>
              <CardDescription>
                Categorized holdings with capital gains tax classification (STCG vs LTCG / Business Income)
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="space-y-3">
                  {[...Array(4)].map((_, i) => (
                    <Skeleton key={i} className="h-16 rounded-xl" />
                  ))}
                </div>
              ) : investmentsList.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-border/60 rounded-2xl bg-muted/20">
                  <TrendingUp className="w-10 h-10 mx-auto text-muted-foreground mb-3 opacity-60" />
                  <h3 className="font-semibold text-lg">No positions found</h3>
                  <p className="text-sm text-muted-foreground mt-1 mb-4">
                    Add your stock investments, F&O trades, mutual funds, or crypto holdings to track P&L and tax liability
                  </p>
                  <Button
                    size="sm"
                    onClick={() => {
                      resetForm();
                      setDialogOpen(true);
                    }}
                    className="rounded-xl bg-indigo-600 text-white hover:bg-indigo-500"
                  >
                    <Plus className="w-4 h-4 mr-1" /> Add Position
                  </Button>
                </div>
              ) : (
                <div className="space-y-3">
                  {investmentsList.map((inv) => {
                    const pnl = parseFloat(String(inv.totalPnl || inv.realizedPnl || inv.unrealizedPnl || 0));
                    const badgeInfo = assetClassLabels[inv.assetClass] || { label: inv.assetClass, badgeClass: "bg-muted text-foreground" };

                    return (
                      <div
                        key={inv.id}
                        className="flex flex-col sm:flex-row sm:items-center justify-between p-4 rounded-xl border border-border/50 bg-card/60 hover:bg-muted/40 transition-all gap-4"
                      >
                        <div className="flex items-center gap-3.5">
                          <div
                            className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
                              pnl >= 0 ? "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20" : "bg-rose-500/10 text-rose-600 border border-rose-500/20"
                            }`}
                          >
                            {pnl >= 0 ? <TrendingUp className="w-5 h-5" /> : <TrendingDown className="w-5 h-5" />}
                          </div>
                          <div>
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="font-semibold text-foreground text-base">{inv.name}</span>
                              {inv.symbol && <span className="text-xs text-muted-foreground font-mono">({inv.symbol})</span>}
                              <Badge className={`text-[10px] h-5 ${badgeInfo.badgeClass}`}>
                                {badgeInfo.label}
                              </Badge>
                              {inv.isStcg && (
                                <Badge variant="outline" className="text-[10px] h-5 border-amber-300 text-amber-600 bg-amber-50/40">
                                  STCG (Sec 111A)
                                </Badge>
                              )}
                              {inv.isLtcg && (
                                <Badge variant="outline" className="text-[10px] h-5 border-emerald-300 text-emerald-600 bg-emerald-50/40">
                                  LTCG (Sec 112A)
                                </Badge>
                              )}
                              {inv.status === "realized" ? (
                                <Badge variant="secondary" className="text-[10px] h-5 bg-purple-500/10 text-purple-600">
                                  Realized Trade
                                </Badge>
                              ) : (
                                <Badge variant="secondary" className="text-[10px] h-5">
                                  Active Position
                                </Badge>
                              )}
                            </div>

                            <div className="flex items-center gap-3 text-xs text-muted-foreground mt-1 flex-wrap">
                              <span>Qty: {inv.quantity}</span>
                              <span>• Buy Price: {formatCurrency(inv.buyPrice)}</span>
                              <span>• Total Invested: {formatCurrency(inv.investedAmount)}</span>
                              <span>• Bought: {inv.purchaseDate ? format(new Date(inv.purchaseDate), "dd MMM yyyy") : ""}</span>
                              {inv.notes && <span>• {inv.notes}</span>}
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center justify-between sm:justify-end gap-4 border-t sm:border-t-0 pt-2 sm:pt-0 border-border/40">
                          <div className="text-right">
                            <div className={`text-base font-bold ${pnl >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                              {pnl >= 0 ? "+" : ""}{formatCurrency(pnl)} ({inv.pnlPercentage ?? 0}%)
                            </div>
                            <div className="text-xs text-muted-foreground">
                              Valuation: {formatCurrency(inv.currentValue || inv.investedAmount)}
                            </div>
                          </div>

                          <div className="flex items-center gap-1">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 text-muted-foreground hover:text-foreground rounded-lg"
                              onClick={() => handleEdit(inv)}
                            >
                              <Pencil className="w-3.5 h-3.5" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 text-rose-500 hover:bg-rose-500/10 rounded-lg"
                              onClick={() => deleteMutation.mutate(inv.id!)}
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </Button>
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
      </Tabs>
    </div>
  );
}
