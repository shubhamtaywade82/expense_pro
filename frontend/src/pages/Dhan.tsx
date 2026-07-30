import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { DhanCredentialUpdate } from "@/types";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import {
  LineChart,
  RefreshCw,
  CheckCircle2,
  XCircle,
  Wallet,
  Briefcase,
  Landmark,
  ListOrdered,
  Repeat,
  History,
  Receipt,
  User as UserIcon,
  Settings,
  ShieldCheck,
} from "lucide-react";
import {
  format,
  subDays,
  startOfWeek,
  endOfWeek,
  startOfMonth,
  endOfMonth,
  startOfQuarter,
  endOfQuarter,
} from "date-fns";
import { toast } from "sonner";

function formatCurrency(val: unknown) {
  const num = typeof val === "string" ? parseFloat(val) : typeof val === "number" ? val : 0;
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(num || 0);
}

// Dhan's raw API leaves trading_symbol blank for most F&O legs (it only sends
// security_id + strike/option-type/expiry) — build a readable label from those
// instead of falling through to an empty cell.
function resolveSymbol(row: Record<string, unknown>) {
  const symbol = row.trading_symbol || row.custom_symbol;
  if (symbol) return String(symbol);

  const strike = row.drv_strike_price;
  const optionType = row.drv_option_type;
  const expiry = row.drv_expiry_date;
  if (strike || optionType || expiry) {
    const parts = [strike ? String(strike) : null, optionType ? String(optionType) : null, expiry ? String(expiry) : null].filter(Boolean);
    const label = parts.join(" ");
    return row.security_id ? `${label} (#${row.security_id})` : label;
  }

  return row.security_id ? `#${row.security_id}` : "—";
}

function EmptyState({ label }: { label: string }) {
  return (
    <div className="text-center py-10 border border-dashed border-border/60 rounded-2xl bg-muted/20 text-sm text-muted-foreground">
      {label}
    </div>
  );
}

function RowList({
  rows,
  isLoading,
  emptyLabel,
  keys,
}: {
  rows: Record<string, unknown>[] | undefined;
  isLoading: boolean;
  emptyLabel: string;
  keys: string[];
}) {
  if (isLoading) {
    return (
      <div className="space-y-2">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-12 rounded-xl" />
        ))}
      </div>
    );
  }

  if (!rows || rows.length === 0) return <EmptyState label={emptyLabel} />;

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-xs">
        <thead>
          <tr className="text-left text-muted-foreground border-b border-border/40">
            {keys.map((k) => (
              <th key={k} className="py-2 pr-4 font-medium whitespace-nowrap">
                {k.replace(/_/g, " ")}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={i} className="border-b border-border/20 hover:bg-muted/30">
              {keys.map((k) => (
                <td key={k} className="py-2 pr-4 whitespace-nowrap text-foreground">
                  {k === "trading_symbol" ? resolveSymbol(row) : String(row[k] ?? "—")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DhanSettingsForm() {
  const queryClient = useQueryClient();
  const credential = useQuery({
    queryKey: ["dhan", "credential"],
    queryFn: api.dhan.getCredential,
  });

  const [form, setForm] = useState<DhanCredentialUpdate>({
    clientId: "",
    tokenServiceUrl: "",
    tokenServiceSecret: "",
    fallbackAccessToken: "",
    autoImportPnl: false,
  });

  useEffect(() => {
    if (!credential.data) return;
    setForm((f) => ({
      ...f,
      clientId: credential.data.client_id ?? "",
      tokenServiceUrl: credential.data.token_service_url ?? "",
      autoImportPnl: credential.data.auto_import_pnl,
    }));
  }, [credential.data]);

  const saveMutation = useMutation({
    mutationFn: api.dhan.updateCredential,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["dhan"] });
      setForm((f) => ({ ...f, tokenServiceSecret: "", fallbackAccessToken: "" }));
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const payload: DhanCredentialUpdate = {
      clientId: form.clientId,
      tokenServiceUrl: form.tokenServiceUrl,
    };
    if (form.tokenServiceSecret) payload.tokenServiceSecret = form.tokenServiceSecret;
    if (form.fallbackAccessToken) payload.fallbackAccessToken = form.fallbackAccessToken;
    payload.autoImportPnl = form.autoImportPnl;
    saveMutation.mutate(payload);
  };

  if (credential.isLoading) {
    return (
      <div className="space-y-3">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-12 rounded-xl" />
        ))}
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4 max-w-xl">
      <div>
        <Label className="text-sm font-medium">Dhan Client ID</Label>
        <Input
          className="mt-1"
          value={form.clientId}
          onChange={(e) => setForm({ ...form, clientId: e.target.value })}
          placeholder="e.g. 1104216308"
        />
      </div>

      <div>
        <Label className="text-sm font-medium">Token Service URL</Label>
        <Input
          className="mt-1"
          value={form.tokenServiceUrl}
          onChange={(e) => setForm({ ...form, tokenServiceUrl: e.target.value })}
          placeholder="https://algo-trading-api.onrender.com/auth/dhan/token"
        />
        <p className="text-[11px] text-muted-foreground mt-1">
          Leave blank to use the default render-deployed algo_trading_api endpoint.
        </p>
      </div>

      <div>
        <Label className="text-sm font-medium">
          Token Service Secret{" "}
          {credential.data?.has_token_service_secret && (
            <Badge variant="outline" className="ml-1 text-[10px] h-4">Set</Badge>
          )}
        </Label>
        <Input
          type="password"
          className="mt-1"
          value={form.tokenServiceSecret}
          onChange={(e) => setForm({ ...form, tokenServiceSecret: e.target.value })}
          placeholder={credential.data?.has_token_service_secret ? "•••••••••••• (leave blank to keep)" : "Bearer secret"}
        />
      </div>

      <div>
        <Label className="text-sm font-medium">
          Fallback Access Token (optional){" "}
          {credential.data?.has_fallback_access_token && (
            <Badge variant="outline" className="ml-1 text-[10px] h-4">Set</Badge>
          )}
        </Label>
        <Input
          type="password"
          className="mt-1"
          value={form.fallbackAccessToken}
          onChange={(e) => setForm({ ...form, fallbackAccessToken: e.target.value })}
          placeholder={credential.data?.has_fallback_access_token ? "•••••••••••• (leave blank to keep)" : "Used only if the token service is unreachable"}
        />
      </div>

      <label className="flex items-start gap-2.5 p-3 rounded-xl bg-muted/30 border border-border/40 cursor-pointer">
        <input
          type="checkbox"
          className="mt-0.5"
          checked={form.autoImportPnl ?? false}
          onChange={(e) => setForm({ ...form, autoImportPnl: e.target.checked })}
        />
        <span className="text-xs">
          <span className="font-medium text-foreground block">
            Auto-import Intraday &amp; F&amp;O P&amp;L to Investments
          </span>
          <span className="text-muted-foreground">
            Re-imports the trailing 7 days into Investments each time you refresh your Dhan
            connection (not a scheduled background job — only runs when you or a page load hits
            Refresh Token).
          </span>
        </span>
      </label>

      <div className="flex items-center gap-3">
        <Button type="submit" disabled={saveMutation.isPending} className="rounded-xl bg-cyan-600 text-white hover:bg-cyan-500">
          {saveMutation.isPending ? "Saving..." : "Save Broker Settings"}
        </Button>
        {saveMutation.isSuccess && (
          <span className="text-xs text-emerald-600 flex items-center gap-1">
            <CheckCircle2 className="w-3.5 h-3.5" /> Saved
          </span>
        )}
        {saveMutation.isError && (
          <span className="text-xs text-rose-600">Failed to save settings</span>
        )}
      </div>
    </form>
  );
}

type PeriodPreset = "week" | "month" | "quarter" | "fy" | "custom";

function currentFyYear() {
  const now = new Date();
  const month = now.getMonth();
  const year = now.getFullYear();
  // Apr-Nov: default to PREVIOUS completed FY (ITR filing season).
  // Dec-Mar: default to current FY (early filers for the new year).
  // e.g., Jul 2026 → FY 2025-26 (AY 2026-27), Jan 2027 → FY 2026-27 (AY 2027-28)
  if (month >= 3 && month <= 10) return year;      // Apr-Nov → prev FY
  if (month >= 11) return year + 1;                 // Dec → current FY
  return year;                                       // Jan-Mar → current FY
}

function fyDates(fyEndYear: number) {
  const from = new Date(fyEndYear - 1, 3, 1);  // Apr 1 of FY start year
  const to = new Date(fyEndYear, 2, 31);        // Mar 31 of FY end year
  return { fromDate: format(from, "yyyy-MM-dd"), toDate: format(to, "yyyy-MM-dd") };
}

function PeriodPicker({ onChange }: { onChange: (from: string, to: string) => void }) {
  const [preset, setPreset] = useState<PeriodPreset>("fy");
  const [fyYear, setFyYear] = useState(currentFyYear);
  const [customFrom, setCustomFrom] = useState(format(subDays(new Date(), 30), "yyyy-MM-dd"));
  const [customTo, setCustomTo] = useState(format(new Date(), "yyyy-MM-dd"));

  useEffect(() => {
    const now = new Date();
    let from: Date;
    let to: Date;
    switch (preset) {
      case "week":
        from = startOfWeek(now, { weekStartsOn: 1 });
        to = endOfWeek(now, { weekStartsOn: 1 });
        break;
      case "quarter":
        from = startOfQuarter(now);
        to = endOfQuarter(now);
        break;
      case "fy":
        from = new Date(fyYear - 1, 3, 1);
        to = new Date(fyYear, 2, 31);
        break;
      case "custom":
        onChange(customFrom, customTo);
        return;
      default:
        from = startOfMonth(now);
        to = endOfMonth(now);
    }
    onChange(format(from, "yyyy-MM-dd"), format(to, "yyyy-MM-dd"));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [preset, fyYear, customFrom, customTo]);

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="flex items-center gap-0.5 bg-muted/40 p-1 rounded-xl border border-border/40">
        {(["week", "month", "quarter", "fy", "custom"] as PeriodPreset[]).map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => setPreset(p)}
            className={`px-2.5 py-1 rounded-lg text-[11px] font-medium transition-colors ${
              preset === p ? "bg-cyan-600 text-white" : "text-muted-foreground hover:text-foreground"
            }`}
          >
            {p === "fy" ? "This FY" : p === "custom" ? "Custom" : `This ${p[0].toUpperCase()}${p.slice(1)}`}
          </button>
        ))}
      </div>

      {preset === "fy" && (
        <div className="flex items-center gap-1 text-xs">
          <Button type="button" variant="ghost" size="icon" className="h-7 w-7 rounded-lg" onClick={() => setFyYear((y) => y - 1)}>
            &larr;
          </Button>
          <span className="font-semibold px-1 min-w-[90px] text-center">
            FY {fyYear - 1}-{String(fyYear).slice(2)}
          </span>
          <Button type="button" variant="ghost" size="icon" className="h-7 w-7 rounded-lg" onClick={() => setFyYear((y) => y + 1)}>
            &rarr;
          </Button>
        </div>
      )}

      {preset === "custom" && (
        <div className="flex items-end gap-2">
          <div>
            <Label className="text-[10px] text-muted-foreground">From</Label>
            <Input type="date" className="h-8 text-xs" value={customFrom} onChange={(e) => setCustomFrom(e.target.value)} />
          </div>
          <div>
            <Label className="text-[10px] text-muted-foreground">To</Label>
            <Input type="date" className="h-8 text-xs" value={customTo} onChange={(e) => setCustomTo(e.target.value)} />
          </div>
        </div>
      )}
    </div>
  );
}

function num(val: unknown) {
  return typeof val === "string" ? parseFloat(val) : typeof val === "number" ? val : 0;
}

function TradeHistorySummary({ trades }: { trades: Record<string, unknown>[] | undefined }) {
  if (!trades || trades.length === 0) return null;

  const turnover = trades.reduce((sum, t) => sum + num(t.traded_quantity) * num(t.traded_price), 0);
  const charges = trades.reduce(
    (sum, t) =>
      sum +
      num(t.sebi_tax) +
      num(t.stt) +
      num(t.brokerage_charges) +
      num(t.service_tax) +
      num(t.exchange_transaction_charges) +
      num(t.stamp_duty),
    0
  );

  return (
    <div className="grid gap-3 sm:grid-cols-3 mb-4">
      <div className="p-3 rounded-xl bg-muted/30 border border-border/40">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wide">Trades</p>
        <p className="text-base font-bold text-foreground">{trades.length}</p>
      </div>
      <div className="p-3 rounded-xl bg-muted/30 border border-border/40">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wide">Turnover</p>
        <p className="text-base font-bold text-foreground">{formatCurrency(turnover)}</p>
      </div>
      <div className="p-3 rounded-xl bg-rose-500/5 border border-rose-500/20">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wide">Total Charges</p>
        <p className="text-base font-bold text-rose-600 dark:text-rose-400">{formatCurrency(charges)}</p>
      </div>
    </div>
  );
}

function LedgerSummary({ entries }: { entries: Record<string, unknown>[] | undefined }) {
  if (!entries || entries.length === 0) return null;

  const credit = entries.reduce((sum, e) => sum + num(e.credit), 0);
  const debit = entries.reduce((sum, e) => sum + num(e.debit), 0);

  return (
    <div className="grid gap-3 sm:grid-cols-3 mb-4">
      <div className="p-3 rounded-xl bg-emerald-500/5 border border-emerald-500/20">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wide">Total Credit</p>
        <p className="text-base font-bold text-emerald-600 dark:text-emerald-400">{formatCurrency(credit)}</p>
      </div>
      <div className="p-3 rounded-xl bg-rose-500/5 border border-rose-500/20">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wide">Total Debit</p>
        <p className="text-base font-bold text-rose-600 dark:text-rose-400">{formatCurrency(debit)}</p>
      </div>
      <div className="p-3 rounded-xl bg-muted/30 border border-border/40">
        <p className="text-[10px] text-muted-foreground uppercase tracking-wide">Net Change</p>
        <p className={`text-base font-bold ${credit - debit >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
          {credit - debit >= 0 ? "+" : ""}
          {formatCurrency(credit - debit)}
        </p>
      </div>
    </div>
  );
}

const PNL_SEGMENT_LABELS: Record<string, { label: string; importable: boolean; note: string }> = {
  speculative_intraday: { label: "Intraday (Speculative)", importable: true, note: "Sec 43(5) business income" },
  non_speculative_fo: { label: "F&O (Non-Speculative)", importable: true, note: "Business income" },
  equity_delivery: { label: "Equity Delivery (CNC)", importable: false, note: "Add manually — STCG/LTCG needs lot matching" },
  commodity: { label: "Commodity (MCX)", importable: false, note: "Not auto-classified" },
};

function PnlSummaryPanel({ fromDate, toDate }: { fromDate: string; toDate: string }) {
  const queryClient = useQueryClient();
  const summary = useQuery({
    queryKey: ["dhan", "pnl_summary", { fromDate, toDate }],
    queryFn: () => api.dhan.pnlSummary({ fromDate, toDate }),
  });

  const importMutation = useMutation({
    mutationFn: (manualAssetClass?: "swing_trading" | "long_term_equity") =>
      api.dhan.importToInvestments({ fromDate, toDate, manualAssetClass }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["investments"] });
      queryClient.invalidateQueries({ queryKey: ["tax"] });
    },
  });

  if (summary.isLoading) {
    return (
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 mb-4">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-20 rounded-xl" />
        ))}
      </div>
    );
  }

  if (!summary.data) return null;

  const segments = summary.data.segments;
  const truncated = summary.data.truncated;
  const hasImportableTrades = ["speculative_intraday", "non_speculative_fo"].some(
    (k) => segments[k as keyof typeof segments].trade_count > 0
  );

  return (
    <div className="mb-4 space-y-3">
      {truncated && (
        <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-700 dark:text-amber-300">
          Too many trades in this range to summarize accurately — figures below are a partial count, and import
          is disabled to avoid recording wrong P&amp;L. Switch to This Month or This Quarter instead: each import
          is its own dated record, and ITR sums them across the whole year regardless of how many times you import.
        </div>
      )}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {Object.entries(PNL_SEGMENT_LABELS).map(([key, meta]) => {
          const bucket = segments[key as keyof typeof segments];
          return (
            <div key={key} className="p-3 rounded-xl bg-muted/30 border border-border/40">
              <p className="text-[10px] text-muted-foreground uppercase tracking-wide">{meta.label}</p>
              <p className={`text-base font-bold ${bucket.net_pnl >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                {bucket.net_pnl >= 0 ? "+" : ""}
                {formatCurrency(bucket.net_pnl)}
              </p>
              <p className="text-[10px] text-muted-foreground mt-1">
                {bucket.trade_count} trades · {meta.note}
              </p>
            </div>
          );
        })}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          size="sm"
          variant="outline"
          className="rounded-xl"
          disabled={!hasImportableTrades || truncated || importMutation.isPending}
          onClick={() => importMutation.mutate(undefined)}
        >
          {importMutation.isPending ? "Importing..." : "Import Intraday + F&O to Investments"}
        </Button>
        {importMutation.isSuccess && (
          <span className="text-xs text-emerald-600 flex items-center gap-1">
            <CheckCircle2 className="w-3.5 h-3.5" /> Imported {importMutation.data.imported_count} position(s)
          </span>
        )}
        {importMutation.isError && <span className="text-xs text-rose-600">Import failed</span>}
      </div>

      {segments.equity_delivery.trade_count > 0 && (
        <div className="p-3 rounded-xl bg-muted/20 border border-dashed border-border/50">
          <p className="text-xs font-medium text-foreground mb-2">
            Manually classify & import Equity Delivery ({segments.equity_delivery.trade_count} trades) — you know
            whether these were short-term flips or long-term holds, the trade log can't tell:
          </p>
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              size="sm"
              variant="outline"
              className="rounded-xl"
              disabled={truncated || importMutation.isPending}
              onClick={() => importMutation.mutate("swing_trading")}
            >
              Import as Swing Trading (STCG)
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              className="rounded-xl"
              disabled={truncated || importMutation.isPending}
              onClick={() => importMutation.mutate("long_term_equity")}
            >
              Import as Long-Term Equity (LTCG)
            </Button>
          </div>
        </div>
      )}

      <p className="text-[11px] text-muted-foreground mt-1.5">
        Each import covers exactly the period selected above — importing overlapping periods (e.g. a month, then
        the quarter containing it) double-counts that overlap in ITR. Import non-overlapping periods only.
      </p>
    </div>
  );
}

function PnlReportPanel({ fromDate, toDate }: { fromDate: string; toDate: string }) {
  const queryClient = useQueryClient();

  const report = useQuery({
    queryKey: ["dhan", "pnl_report", { fromDate, toDate }],
    queryFn: () => api.dhan.pnlReport({ fromDate, toDate }),
  });

  const importTradesMutation = useMutation({
    mutationFn: () => api.dhan.importTrades({ fromDate, toDate }),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ["dhan", "pnl_report"] });
      queryClient.invalidateQueries({ queryKey: ["investments"] });
      queryClient.invalidateQueries({ queryKey: ["dhan", "trade_history"] });
      toast.success(`Imported ${data.imported} trades`);
    },
    onError: (error: Error) => {
      toast.error(error.message || "Import failed");
    },
  });

  if (report.isLoading) {
    return <Skeleton className="h-64 rounded-xl" />;
  }

  const noTrades = !report.data || report.data.trades.length === 0;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          size="sm"
          variant="outline"
          className="rounded-xl"
          onClick={() => importTradesMutation.mutate()}
          disabled={importTradesMutation.isPending}
        >
          <RefreshCw className={`w-3.5 h-3.5 mr-1.5 ${importTradesMutation.isPending ? "animate-spin" : ""}`} />
          {importTradesMutation.isPending ? "Importing..." : "Import Trades from Dhan"}
        </Button>
        {report.data && report.data.trades.length > 0 && (
          <a
            href={api.dhan.pnlReportCsv({ fromDate, toDate })}
            className="inline-flex items-center gap-1.5 text-xs text-cyan-600 hover:text-cyan-700 dark:text-cyan-400 dark:hover:text-cyan-300 underline underline-offset-2"
          >
            Download CSV
          </a>
        )}
      </div>

      {report.data?.trades.length > 0 && (
        <>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {Object.entries(PNL_SEGMENT_LABELS).map(([key, meta]) => {
              const seg = report.data!.summary[key];
              if (!seg || seg.trade_count === 0) return null;
              return (
                <div key={key} className="p-3 rounded-xl bg-muted/30 border border-border/40">
                  <p className="text-[10px] text-muted-foreground uppercase tracking-wide">{meta.label}</p>
                  <p className={`text-base font-bold ${seg.net_pnl >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                    {seg.net_pnl >= 0 ? "+" : ""}{formatCurrency(seg.net_pnl)}
                  </p>
                  <p className="text-[10px] text-muted-foreground mt-1">
                    {seg.trade_count} trades · Buy: {formatCurrency(seg.buy_value)} · Sell: {formatCurrency(seg.sell_value)}
                  </p>
                </div>
              );
            })}
          </div>

          <div className="overflow-x-auto rounded-xl border border-border/40">
            <table className="w-full text-xs">
              <thead>
                <tr className="bg-muted/50">
                  <th className="text-left p-2 font-medium">Date</th>
                  <th className="text-left p-2 font-medium">Symbol</th>
                  <th className="text-left p-2 font-medium">Type</th>
                  <th className="text-right p-2 font-medium">Qty</th>
                  <th className="text-right p-2 font-medium">Price</th>
                  <th className="text-right p-2 font-medium">Value</th>
                  <th className="text-right p-2 font-medium">Brokerage</th>
                  <th className="text-right p-2 font-medium">STT</th>
                  <th className="text-right p-2 font-medium">GST</th>
                  <th className="text-right p-2 font-medium">Other Chrg</th>
                  <th className="text-right p-2 font-medium">Net Value</th>
                  <th className="text-left p-2 font-medium">Segment</th>
                </tr>
              </thead>
              <tbody>
                {report.data!.trades.map((t, i) => (
                  <tr key={i} className="border-t border-border/30 hover:bg-muted/20">
                    <td className="p-2 whitespace-nowrap">{t.trade_date || "—"}</td>
                    <td className="p-2 whitespace-nowrap font-medium">{t.symbol}</td>
                    <td className="p-2">{t.transaction_type}</td>
                    <td className="p-2 text-right">{t.quantity}</td>
                    <td className="p-2 text-right">{formatCurrency(t.price)}</td>
                    <td className="p-2 text-right">{formatCurrency(t.total_value)}</td>
                    <td className="p-2 text-right">{formatCurrency(t.brokerage)}</td>
                    <td className="p-2 text-right">{formatCurrency(t.stt)}</td>
                    <td className="p-2 text-right">{formatCurrency(t.gst)}</td>
                    <td className="p-2 text-right">{formatCurrency(t.sebi_tax + t.exchange_charges + t.stamp_duty)}</td>
                    <td className={`p-2 text-right font-medium ${t.net_value >= 0 ? "text-emerald-600" : "text-rose-600"}`}>
                      {formatCurrency(t.net_value)}
                    </td>
                    <td className="p-2 whitespace-nowrap">
                      <Badge variant="outline" className="text-[10px]">
                        {PNL_SEGMENT_LABELS[t.segment as keyof typeof PNL_SEGMENT_LABELS]?.label || t.segment}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {noTrades && !importTradesMutation.isPending && (
        <div className="p-6 rounded-xl bg-muted/20 border border-dashed border-border/50 text-center text-sm text-muted-foreground">
          No trades in this period. Click "Import Trades from Dhan" to pull trade-level data for ITR filing.
        </div>
      )}
    </div>
  );
}

export default function Dhan() {
  const queryClient = useQueryClient();
  const defaultFy = fyDates(currentFyYear());
  const [fromDate, setFromDate] = useState(defaultFy.fromDate);
  const [toDate, setToDate] = useState(defaultFy.toDate);

  const tokenStatus = useQuery({
    queryKey: ["dhan", "token_status"],
    queryFn: api.dhan.tokenStatus,
  });

  const connected = tokenStatus.data?.connected ?? false;

  const profile = useQuery({
    queryKey: ["dhan", "profile"],
    queryFn: api.dhan.profile,
    enabled: connected,
  });

  const fundLimits = useQuery({
    queryKey: ["dhan", "fund_limits"],
    queryFn: api.dhan.fundLimits,
    enabled: connected,
  });

  const positions = useQuery({
    queryKey: ["dhan", "positions"],
    queryFn: api.dhan.positions,
    enabled: connected,
  });

  const holdings = useQuery({
    queryKey: ["dhan", "holdings"],
    queryFn: api.dhan.holdings,
    enabled: connected,
  });

  const orders = useQuery({
    queryKey: ["dhan", "orders"],
    queryFn: api.dhan.orders,
    enabled: connected,
  });

  const tradeBook = useQuery({
    queryKey: ["dhan", "trade_book"],
    queryFn: api.dhan.tradeBook,
    enabled: connected,
  });

  const tradeHistory = useQuery({
    queryKey: ["dhan", "trade_history", { fromDate, toDate }],
    queryFn: () => api.dhan.tradeHistory({ fromDate, toDate }),
    enabled: connected,
  });

  const ledger = useQuery({
    queryKey: ["dhan", "ledger", { fromDate, toDate }],
    queryFn: () => api.dhan.ledger({ fromDate, toDate }),
    enabled: connected,
  });

  const handleRefreshToken = async () => {
    await api.dhan.refreshToken();
    queryClient.invalidateQueries({ queryKey: ["dhan"] });
  };

  const syncMutation = useMutation({
    mutationFn: () => api.dhan.syncInvestments(),
    onSuccess: () => {
      const poll = () => {
        api.dhan.syncStatus().then((s) => {
          if (s.status === "completed") {
            queryClient.invalidateQueries({ queryKey: ["dhan"] });
            queryClient.invalidateQueries({ queryKey: ["investments"] });
            queryClient.invalidateQueries({ queryKey: ["tax"] });
            toast.success(`Synced ${s.trades_imported} trades from Dhan`);
          } else if (s.status === "truncated") {
            toast.warning("Snapshots synced, trade history too large — import per month from PnL tab");
          } else {
            setTimeout(poll, 3000);
          }
        }).catch(() => setTimeout(poll, 3000));
      };
      toast.success("Sync started in background");
      setTimeout(poll, 3000);
    },
    onError: (error: Error) => {
      toast.error(error.message || "Sync failed");
    },
  });

  const profileData = profile.data;
  const funds = fundLimits.data;

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1 space-y-6 pb-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-card/40 p-4 lg:p-6 rounded-2xl border border-border/40 backdrop-blur-md shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-cyan-600 to-blue-500 flex items-center justify-center shadow-lg shadow-cyan-500/20 text-white">
            <LineChart className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-2xl font-bold tracking-tight text-foreground">DhanHQ Trading Account</h2>
            <p className="text-sm text-muted-foreground">
              Live positions, holdings, orders, trades & funds from your Dhan account
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {tokenStatus.isLoading ? (
            <Skeleton className="h-8 w-32 rounded-xl" />
          ) : connected ? (
            <Badge className="bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30 gap-1.5 py-1.5 px-3">
              <CheckCircle2 className="w-3.5 h-3.5" /> Connected
              {tokenStatus.data?.token_preview ? ` · ${tokenStatus.data.token_preview}` : ""}
            </Badge>
          ) : (
            <Badge variant="outline" className="border-rose-500/40 text-rose-600 gap-1.5 py-1.5 px-3">
              <XCircle className="w-3.5 h-3.5" /> Not Connected
            </Badge>
          )}
          <Button
            variant="outline"
            size="sm"
            className="rounded-xl"
            onClick={handleRefreshToken}
            disabled={tokenStatus.isFetching}
          >
            <RefreshCw className={`w-3.5 h-3.5 mr-1.5 ${tokenStatus.isFetching ? "animate-spin" : ""}`} />
            Refresh Token
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="rounded-xl border-emerald-500/30 text-emerald-700 hover:bg-emerald-50 dark:text-emerald-400 dark:hover:bg-emerald-950/30"
            onClick={() => {
              syncMutation.mutate();
            }}
            disabled={syncMutation.isPending}
          >
            <RefreshCw className={`w-3.5 h-3.5 mr-1.5 ${syncMutation.isPending ? "animate-spin" : ""}`} />
            {syncMutation.isPending ? "Syncing..." : "Sync to Investments"}
          </Button>
        </div>
      </div>

      {!connected && !tokenStatus.isLoading && (
        <Card className="border border-amber-500/30 bg-amber-500/5">
          <CardContent className="p-4 text-sm text-amber-700 dark:text-amber-300">
            {tokenStatus.data?.message || tokenStatus.data?.error ||
              "No valid Dhan token yet. Click Refresh Token to pull one from the configured token source."}
          </CardContent>
        </Card>
      )}

      {/* Summary cards */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card className="border border-border/40 bg-gradient-to-br from-cyan-500/10 via-card to-card">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Available Balance</CardTitle>
            <Wallet className="w-4 h-4 text-cyan-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {fundLimits.isLoading ? <Skeleton className="h-7 w-28" /> : formatCurrency(funds?.available_balance)}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Amount available to trade</p>
          </CardContent>
        </Card>

        <Card className="border border-border/40 bg-card/50">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Utilized Margin</CardTitle>
            <Landmark className="w-4 h-4 text-indigo-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {fundLimits.isLoading ? <Skeleton className="h-7 w-28" /> : formatCurrency(funds?.utilized_amount)}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Amount utilised today</p>
          </CardContent>
        </Card>

        <Card className="border border-border/40 bg-card/50">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Account</CardTitle>
            <UserIcon className="w-4 h-4 text-teal-500" />
          </CardHeader>
          <CardContent>
            <div className="text-lg font-bold text-foreground truncate">
              {profile.isLoading ? <Skeleton className="h-6 w-32" /> : String(profileData?.dhan_client_id ?? "—")}
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              {profileData ? `Data Plan: ${profileData.data_plan ?? "—"}` : "Client ID"}
            </p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue={connected ? "positions" : "settings"} className="w-full space-y-4">
        <TabsList className="bg-card/60 backdrop-blur-md p-1 rounded-xl border border-border/40 flex-wrap h-auto">
          <TabsTrigger value="positions" className="rounded-lg text-xs gap-1.5">
            <Briefcase className="w-3.5 h-3.5" /> Positions
          </TabsTrigger>
          <TabsTrigger value="holdings" className="rounded-lg text-xs gap-1.5">
            <Landmark className="w-3.5 h-3.5" /> Holdings
          </TabsTrigger>
          <TabsTrigger value="orders" className="rounded-lg text-xs gap-1.5">
            <ListOrdered className="w-3.5 h-3.5" /> Orders
          </TabsTrigger>
          <TabsTrigger value="trades" className="rounded-lg text-xs gap-1.5">
            <Repeat className="w-3.5 h-3.5" /> Trade Book
          </TabsTrigger>
          <TabsTrigger value="history" className="rounded-lg text-xs gap-1.5">
            <History className="w-3.5 h-3.5" /> Trade History
          </TabsTrigger>
          <TabsTrigger value="ledger" className="rounded-lg text-xs gap-1.5">
            <Receipt className="w-3.5 h-3.5" /> Ledger
          </TabsTrigger>
          <TabsTrigger value="pnl_report" className="rounded-lg text-xs gap-1.5">
            <LineChart className="w-3.5 h-3.5" /> PNL Report
          </TabsTrigger>
          <TabsTrigger value="settings" className="rounded-lg text-xs gap-1.5 ml-auto">
            <Settings className="w-3.5 h-3.5" /> Settings
          </TabsTrigger>
        </TabsList>

        <TabsContent value="positions" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg font-bold">Open Positions</CardTitle>
              <CardDescription>Intraday and carry-forward F&O / equity positions</CardDescription>
            </CardHeader>
            <CardContent>
              <RowList
                rows={positions.data}
                isLoading={positions.isLoading}
                emptyLabel="No open positions"
                keys={["trading_symbol", "position_type", "net_qty", "buy_avg", "sell_avg", "unrealized_profit", "realized_profit"]}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="holdings" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg font-bold">Demat Holdings</CardTitle>
              <CardDescription>Delivered and pending (T1) equity holdings</CardDescription>
            </CardHeader>
            <CardContent>
              <RowList
                rows={holdings.data}
                isLoading={holdings.isLoading}
                emptyLabel="No holdings"
                keys={["trading_symbol", "exchange", "total_qty", "avg_cost_price", "available_qty", "t1_qty"]}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="orders" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg font-bold">Order Book</CardTitle>
              <CardDescription>All orders placed today</CardDescription>
            </CardHeader>
            <CardContent>
              <RowList
                rows={orders.data}
                isLoading={orders.isLoading}
                emptyLabel="No orders today"
                keys={["trading_symbol", "transaction_type", "order_type", "quantity", "price", "order_status", "order_id"]}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="trades" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="text-lg font-bold">Trade Book (Today)</CardTitle>
              <CardDescription>All trades executed today</CardDescription>
            </CardHeader>
            <CardContent>
              <RowList
                rows={tradeBook.data}
                isLoading={tradeBook.isLoading}
                emptyLabel="No trades today"
                keys={["trading_symbol", "transaction_type", "traded_quantity", "traded_price", "exchange_time", "order_id"]}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="history" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div>
                <CardTitle className="text-lg font-bold">Trade History</CardTitle>
                <CardDescription>Historical executed trades with charge breakdown</CardDescription>
              </div>
              <PeriodPicker onChange={(f, t) => { setFromDate(f); setToDate(t); }} />
            </CardHeader>
            <CardContent>
              {tradeHistory.data?.truncated && (
                <div className="mb-4 p-3 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-700 dark:text-amber-300">
                  This range has too many trades to load in full — the table below only covers what was fetched.
                  Switch to This Month or This Quarter to see (and import) this period completely.
                </div>
              )}
              <PnlSummaryPanel fromDate={fromDate} toDate={toDate} />
              <TradeHistorySummary trades={tradeHistory.data?.trades} />
              <RowList
                rows={tradeHistory.data?.trades}
                isLoading={tradeHistory.isLoading}
                emptyLabel="No trades in this range"
                keys={["trading_symbol", "exchange_segment", "product_type", "transaction_type", "traded_quantity", "traded_price", "brokerage_charges", "stt", "sebi_tax", "exchange_transaction_charges", "service_tax", "stamp_duty", "create_time"]}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="ledger" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div>
                <CardTitle className="text-lg font-bold">Ledger Report</CardTitle>
                <CardDescription>Credit / debit transactions and running balance</CardDescription>
              </div>
              <PeriodPicker onChange={(f, t) => { setFromDate(f); setToDate(t); }} />
            </CardHeader>
            <CardContent>
              <LedgerSummary entries={ledger.data} />
              <RowList
                rows={ledger.data}
                isLoading={ledger.isLoading}
                emptyLabel="No ledger entries in this range"
                keys={["voucherdate", "narration", "voucherdesc", "debit", "credit", "runbal"]}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="pnl_report" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div>
                <CardTitle className="text-lg font-bold">PNL Report (ITR Ready)</CardTitle>
                <CardDescription>
                  Trade-level profit & loss matching Dhan XLS export structure. Import individual trades,
                  view summary by segment, and download CSV for ITR filing.
                </CardDescription>
              </div>
              <PeriodPicker onChange={(f, t) => { setFromDate(f); setToDate(t); }} />
            </CardHeader>
            <CardContent>
              <PnlReportPanel fromDate={fromDate} toDate={toDate} />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="settings" className="m-0">
          <Card className="border border-border/40 shadow-sm">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg font-bold">
                <ShieldCheck className="w-4 h-4 text-cyan-500" /> Broker Connection Settings
              </CardTitle>
              <CardDescription>
                Configure how this account fetches its DhanHQ access token. Secrets are encrypted at
                rest and never sent back to the browser after saving.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <DhanSettingsForm />
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
