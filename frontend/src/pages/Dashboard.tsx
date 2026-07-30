import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import {
  ArrowDownRight,
  Receipt,
  FileText,
  Landmark,
  Wallet,
  TrendingUp,
  AlertCircle,
  IndianRupee,
  Sparkles,
  ChevronLeft,
  ChevronRight,
  Calendar,
  ArrowUpRight,
  Info,
} from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { format } from "date-fns";
import { Link } from "react-router";

export default function Dashboard() {
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());

  const { data, isLoading } = useQuery({
    queryKey: ["dashboard", "overview", month, year],
    queryFn: () => api.dashboard.overview({ month, year }),
  });

  const monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0,
    }).format(num);
  };

  const prevMonth = () => {
    if (month === 1) {
      setMonth(12);
      setYear(year - 1);
    } else {
      setMonth(month - 1);
    }
  };

  const nextMonth = () => {
    if (month === 12) {
      setMonth(1);
      setYear(year + 1);
    } else {
      setMonth(month + 1);
    }
  };

  const trendData = data?.monthlyTrend?.map((t) => ({
    month: format(new Date(t.month + "-01"), "MMM yy"),
    expenses: parseFloat(t.expenses),
    income: parseFloat(t.income),
  })) ?? [];

  const pieData = data?.categoryBreakdown?.map((c) => ({
    name: c.categoryName,
    value: parseFloat(c.total),
    color: c.categoryColor || "#818cf8",
  })) ?? [];

  const totalExpense = parseFloat(data?.expenses.total ?? "0");
  const totalIncome = parseFloat(data?.income.total ?? "0");
  const totalBills = parseFloat(data?.bills.total ?? "0");
  const totalEMI = parseFloat(data?.emis.total ?? "0");
  const netSavings = totalIncome - totalExpense - totalBills - totalEMI;
  const savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;
  const nw = data?.netWorth;

  // Custom tooltips for graphs with glassmorphic style
  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-card/90 backdrop-blur-xl border border-border/50 p-3.5 rounded-xl shadow-glass text-xs space-y-1.5">
          <p className="font-bold text-muted-foreground font-display mb-1">{label}</p>
          {payload.map((entry: any, index: number) => (
            <div key={index} className="flex items-center gap-2 font-sans">
              <span className="w-2 h-2 rounded-full" style={{ backgroundColor: entry.color }} />
              <span className="capitalize text-foreground font-medium">{entry.name}:</span>
              <span className="font-semibold text-foreground">{formatCurrency(entry.value)}</span>
            </div>
          ))}
        </div>
      );
    }
    return null;
  };

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1 scroll-smooth">
      <div className="space-y-6 pb-8">
        {/* Overall Summary Section */}
        {!isLoading && data?.overall && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 animate-stagger-fade" style={{ animationDelay: "0ms" }}>
            <div className="lg:col-span-2 glass-card glowing-border rounded-2xl overflow-hidden p-0.5">
              <div className="bg-gradient-to-br from-card/80 to-card/40 backdrop-blur-xl rounded-[14px] p-6">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
                  <div className="space-y-4 flex-1">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center border border-primary/20 shadow-inner">
                        <Sparkles className="w-6 h-6 text-primary animate-pulse" />
                      </div>
                      <div>
                        <h3 className="text-sm font-bold text-muted-foreground uppercase tracking-wider font-display">Net Worth Overview</h3>
                        <div className="flex items-baseline gap-2">
                          <span className={`text-3xl font-black font-sans tracking-tight ${(nw?.netWorth ?? 0) >= 0 ? "text-gradient-emerald" : "text-red-500"}`}>
                            {formatCurrency(nw?.netWorth ?? data.overall.netBalance)}
                          </span>
                          <span className="text-xs font-medium text-muted-foreground bg-muted/50 px-2 py-0.5 rounded-full border border-border/40">Net Worth</span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex gap-4 text-[10px] font-bold">
                      <span className="text-muted-foreground">Emergency Fund: <span className="text-foreground">{nw?.emergencyFundMonths ?? 0} months</span></span>
                      <span className="text-muted-foreground">Debt/Asset: <span className={nw && nw.debtToAssetRatio > 50 ? "text-red-500" : "text-emerald-500"}>{nw?.debtToAssetRatio ?? 0}%</span></span>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 md:flex md:flex-col gap-x-8 gap-y-3 pt-4 md:pt-0 border-t md:border-t-0 md:border-l border-border/40 md:pl-8">
                    <div className="space-y-1">
                      <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest block">Total Income</span>
                      <p className="text-sm font-bold text-emerald-500 flex items-center gap-1">
                        <ArrowUpRight className="w-3.5 h-3.5" />
                        {formatCurrency(data.overall.totalIncome)}
                      </p>
                    </div>
                    <div className="space-y-1">
                      <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest block">Total Outflow</span>
                      <p className="text-sm font-bold text-red-500 flex items-center gap-1">
                        <ArrowDownRight className="w-3.5 h-3.5" />
                        {formatCurrency(parseFloat(data.overall.totalExpense) + parseFloat(data.overall.totalEmiPaid))}
                      </p>
                    </div>
                    <div className="space-y-1">
                      <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest block">EMI Paid</span>
                      <p className="text-sm font-bold text-indigo-500 flex items-center gap-1">
                        <Landmark className="w-3.5 h-3.5" />
                        {formatCurrency(data.overall.totalEmiPaid)}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="glass-card glowing-border rounded-2xl p-6 bg-gradient-to-br from-emerald-500/5 to-teal-500/5 border-emerald-500/20 flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-xs font-bold text-emerald-600 uppercase tracking-wider font-display">Monthly Savings Rate</h4>
                  <div className="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-600 border border-emerald-500/10">
                    <TrendingUp className="w-3.5 h-3.5" />
                  </div>
                </div>
                <div className="flex items-baseline gap-2">
                  <span className="text-4xl font-black text-gradient-emerald">{savingsRate.toFixed(1)}%</span>
                  <span className="text-xs font-medium text-muted-foreground">of income</span>
                </div>
                <p className="text-[11px] text-muted-foreground mt-3 leading-relaxed">
                  {savingsRate > 20 
                    ? "Excellent! You are above the recommended 20% savings rule." 
                    : savingsRate > 0 
                      ? "Good start. Try to reach the 20% savings mark by optimizing expenses."
                      : "Warning: Your outflows exceed your income this month."}
                </p>
              </div>
              <div className="mt-4 pt-4 border-t border-emerald-500/10 flex items-center justify-between text-[11px] font-bold text-emerald-600">
                <span>Net Savings: {formatCurrency(netSavings)}</span>
                <Link to="/reports" className="flex items-center gap-1 hover:underline">View Analysis <ChevronRight className="w-3 h-3" /></Link>
              </div>
            </div>
          </div>
        )}

        {/* Month Selector & Page Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 animate-stagger-fade" style={{ animationDelay: "50ms" }}>
          <div>
            <h2 className="text-2xl font-bold font-display tracking-tight text-foreground flex items-center gap-2">
              Financial Pulse
              <span className="text-[10px] bg-primary/10 text-primary px-2 py-0.5 rounded-full border border-primary/10 font-bold uppercase tracking-widest">Real-time</span>
            </h2>
            <p className="text-sm text-muted-foreground">Overview and metrics of your cashflow</p>
          </div>
          <div className="flex items-center gap-2 bg-card/60 backdrop-blur-xl border border-border/40 p-1 rounded-2xl shadow-sm self-start">
            <Button variant="ghost" size="icon" onClick={prevMonth} className="rounded-xl h-9 w-9 hover:bg-muted/80 transition-all active:scale-95">
              <ChevronLeft className="w-4.5 h-4.5" />
            </Button>
            <div className="text-xs font-bold px-4 min-w-[140px] text-center flex items-center justify-center gap-2 text-foreground font-display cursor-default">
              <Calendar className="w-4 h-4 text-primary" />
              {monthNames[month - 1]} {year}
            </div>
            <Button variant="ghost" size="icon" onClick={nextMonth} className="rounded-xl h-9 w-9 hover:bg-muted/80 transition-all active:scale-95">
              <ChevronRight className="w-4.5 h-4.5" />
            </Button>
          </div>
        </div>

        {/* Stat Cards */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4 animate-stagger-fade" style={{ animationDelay: "100ms" }}>
          <div className="glass-card glowing-border rounded-2xl p-5 hover-lift group">
            <div className="flex items-center justify-between pb-4">
              <span className="text-[11px] uppercase tracking-widest text-muted-foreground font-bold font-display">Expenses</span>
              <div className="w-9 h-9 rounded-xl bg-red-500/10 flex items-center justify-center border border-red-500/10 group-hover:bg-red-500/20 transition-colors">
                <Receipt className="w-4.5 h-4.5 text-red-500" />
              </div>
            </div>
            <div className="space-y-1">
              {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50 rounded-lg" /> : (
                <h3 className="text-2xl font-black tracking-tight text-red-500">{formatCurrency(totalExpense)}</h3>
              )}
              <div className="flex items-center justify-between text-[11px] font-bold text-muted-foreground">
                <span>{data?.expenses.count ?? 0} Transactions</span>
                {totalIncome > 0 && <span className="text-red-500/80">{((totalExpense/totalIncome)*100).toFixed(0)}% Outflow</span>}
              </div>
            </div>
          </div>

          <div className="glass-card glowing-border rounded-2xl p-5 hover-lift group">
            <div className="flex items-center justify-between pb-4">
              <span className="text-[11px] uppercase tracking-widest text-muted-foreground font-bold font-display">Income</span>
              <div className="w-9 h-9 rounded-xl bg-emerald-500/10 flex items-center justify-center border border-emerald-500/10 group-hover:bg-emerald-500/20 transition-colors">
                <Wallet className="w-4.5 h-4.5 text-emerald-500" />
              </div>
            </div>
            <div className="space-y-1">
              {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50 rounded-lg" /> : (
                <h3 className="text-2xl font-black tracking-tight text-gradient-emerald">{formatCurrency(totalIncome)}</h3>
              )}
              <div className="flex items-center justify-between text-[11px] font-bold text-muted-foreground">
                <span>{data?.income.count ?? 0} Sources</span>
                <span className="text-emerald-500/80">+{((data?.income.received || 0)/totalIncome*100).toFixed(0)}% Received</span>
              </div>
            </div>
          </div>

          <div className="glass-card glowing-border rounded-2xl p-5 hover-lift group">
            <div className="flex items-center justify-between pb-4">
              <span className="text-[11px] uppercase tracking-widest text-muted-foreground font-bold font-display">Bills</span>
              <div className="w-9 h-9 rounded-xl bg-indigo-500/10 flex items-center justify-center border border-indigo-500/10 group-hover:bg-indigo-500/20 transition-colors">
                <FileText className="w-4.5 h-4.5 text-indigo-500" />
              </div>
            </div>
            <div className="space-y-1">
              {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50 rounded-lg" /> : (
                <h3 className="text-2xl font-black tracking-tight text-foreground">{formatCurrency(totalBills)}</h3>
              )}
              <div className="flex items-center gap-2 pt-1">
                <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-600 border border-emerald-500/10">
                  {data?.bills.paid ?? 0} Paid
                </span>
                {data?.bills.unpaid && data.bills.unpaid > 0 ? (
                  <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-600 border border-amber-500/10 flex items-center gap-1">
                    <AlertCircle className="w-2.5 h-2.5" />
                    {data.bills.unpaid} Unpaid
                  </span>
                ) : <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-600 border border-blue-500/10">Cleared</span>}
              </div>
            </div>
          </div>

          <div className="glass-card glowing-border rounded-2xl p-5 hover-lift group">
            <div className="flex items-center justify-between pb-4">
              <span className="text-[11px] uppercase tracking-widest text-muted-foreground font-bold font-display">Savings Rate</span>
              <div className="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center border border-primary/10 group-hover:bg-primary/20 transition-colors">
                <TrendingUp className="w-4.5 h-4.5 text-primary" />
              </div>
            </div>
            <div className="space-y-1">
              {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50 rounded-lg" /> : (
                <h3 className={`text-2xl font-black tracking-tight ${netSavings >= 0 ? "text-gradient-emerald" : "text-red-500"}`}>
                  {formatCurrency(netSavings)}
                </h3>
              )}
              <div className="flex items-center justify-between text-[11px] font-bold text-muted-foreground pt-1">
                <Progress value={Math.max(0, savingsRate)} className="h-1.5 flex-1 mr-3" />
                <span>{savingsRate.toFixed(0)}%</span>
              </div>
            </div>
          </div>
        </div>

        {/* Charts and Lists */}
        <div className="grid gap-6 lg:grid-cols-2 animate-stagger-fade" style={{ animationDelay: "150ms" }}>
          <div className="glass-card glowing-border rounded-2xl p-6 shadow-sm overflow-hidden flex flex-col">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h4 className="text-sm font-bold font-display text-foreground flex items-center gap-2">
                  Cashflow Momentum
                  <Info className="w-3.5 h-3.5 text-muted-foreground cursor-help" />
                </h4>
                <p className="text-[11px] text-muted-foreground">Historical trend of income vs expenses</p>
              </div>
              <div className="flex items-center gap-4 text-[10px] font-bold uppercase tracking-widest">
                <div className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-emerald-500" /> Income</div>
                <div className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-red-500" /> Expenses</div>
              </div>
            </div>
            {isLoading ? <Skeleton className="h-[280px] w-full bg-muted/40 rounded-xl" /> : (
              <div className="flex-1 min-h-[280px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={trendData} barGap={8}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="rgba(255,255,255,0.03)" />
                    <XAxis dataKey="month" fontSize={10} stroke="rgba(255,255,255,0.3)" tickLine={false} axisLine={false} dy={10} fontWeight={600} />
                    <YAxis fontSize={10} stroke="rgba(255,255,255,0.3)" tickLine={false} axisLine={false} tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`} fontWeight={600} />
                    <Tooltip content={<CustomTooltip />} cursor={{ fill: "rgba(255,255,255,0.03)" }} />
                    <Bar dataKey="income" fill="url(#incomeGradient)" radius={[6, 6, 0, 0]} name="Income" />
                    <Bar dataKey="expenses" fill="url(#expenseGradient)" radius={[6, 6, 0, 0]} name="Expenses" />
                    
                    <defs>
                      <linearGradient id="incomeGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#10b981" stopOpacity={1} />
                        <stop offset="100%" stopColor="#059669" stopOpacity={0.8} />
                      </linearGradient>
                      <linearGradient id="expenseGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#ef4444" stopOpacity={1} />
                        <stop offset="100%" stopColor="#dc2626" stopOpacity={0.8} />
                      </linearGradient>
                    </defs>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>

          <div className="glass-card glowing-border rounded-2xl p-6 shadow-sm flex flex-col">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h4 className="text-sm font-bold font-display text-foreground">Allocation Breakdown</h4>
                <p className="text-[11px] text-muted-foreground">Top expense categories this month</p>
              </div>
              <Link to="/reports">
                <Button variant="ghost" size="sm" className="h-8 rounded-lg text-xs font-bold text-primary hover:bg-primary/5">Details</Button>
              </Link>
            </div>
            {isLoading ? <Skeleton className="h-[280px] w-full bg-muted/40 rounded-xl" /> : pieData.length > 0 ? (
              <div className="flex-1 flex flex-col md:flex-row items-center gap-6">
                <div className="flex-1 min-h-[240px] w-full relative group">
                  <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none z-0">
                    <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest">Total</span>
                    <span className="text-lg font-black text-foreground">{formatCurrency(totalExpense)}</span>
                  </div>
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={pieData}
                        cx="50%"
                        cy="50%"
                        innerRadius={70}
                        outerRadius={100}
                        paddingAngle={4}
                        dataKey="value"
                        stroke="none"
                      >
                        {pieData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} className="hover:opacity-80 transition-opacity cursor-pointer focus:outline-none" />
                        ))}
                      </Pie>
                      <Tooltip content={<CustomTooltip />} />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
                <div className="w-full md:w-auto space-y-2.5 min-w-[160px] max-h-[240px] overflow-y-auto pr-2 custom-scrollbar">
                  {pieData.map((entry, index) => (
                    <div key={index} className="flex items-center gap-3 text-xs group/item cursor-default hover:translate-x-1 transition-transform">
                      <div className="w-2.5 h-2.5 rounded-full shadow-sm" style={{ backgroundColor: entry.color }} />
                      <div className="flex-1 flex flex-col min-w-0">
                        <span className="text-muted-foreground font-bold truncate group-hover/item:text-foreground transition-colors">{entry.name}</span>
                        <div className="flex items-center justify-between mt-0.5">
                          <span className="font-black text-foreground">{formatCurrency(entry.value)}</span>
                          <span className="text-[9px] text-muted-foreground font-bold">({((entry.value/totalExpense)*100).toFixed(0)}%)</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-muted-foreground text-sm space-y-3 py-12">
                <div className="w-16 h-16 rounded-3xl bg-muted/30 flex items-center justify-center">
                  <AlertCircle className="w-8 h-8 text-muted-foreground/40" />
                </div>
                <p className="font-bold font-display opacity-60">No expense data recorded</p>
              </div>
            )}
          </div>
        </div>

        {/* Investment & Tax Estimate Cards */}
        {data?.investments && (
          <div className="grid gap-4 md:grid-cols-2 animate-stagger-fade" style={{ animationDelay: "150ms" }}>
            <Card className="glass-card hover-lift border-emerald-500/10 bg-gradient-to-br from-emerald-500/5 to-transparent">
              <CardHeader className="pb-2 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Investment Portfolio</CardTitle>
                <TrendingUp className="w-4 h-4 text-emerald-500" />
              </CardHeader>
              <CardContent>
                <div className="flex items-baseline gap-2">
                  <span className={`text-2xl font-black ${parseFloat(data.investments.totalPnl) >= 0 ? "text-emerald-500" : "text-red-500"}`}>
                    {formatCurrency(data.investments.totalPnl)}
                  </span>
                  <span className="text-[10px] text-muted-foreground">P&L</span>
                </div>
                <div className="flex gap-4 mt-2 text-[10px] font-medium text-muted-foreground">
                  <span>Invested: {formatCurrency(data.investments.totalInvested)}</span>
                  <span>Value: {formatCurrency(data.investments.currentValue)}</span>
                  <span>{data.investments.count} positions</span>
                </div>
              </CardContent>
            </Card>

            {data?.taxEstimate && (
              <Card className="glass-card hover-lift border-amber-500/10 bg-gradient-to-br from-amber-500/5 to-transparent">
                <CardHeader className="pb-2 flex flex-row items-center justify-between">
                  <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Tax Estimate (FY)</CardTitle>
                  <IndianRupee className="w-4 h-4 text-amber-500" />
                </CardHeader>
                <CardContent>
                  <div className="flex items-baseline gap-2">
                    <span className={`text-2xl font-black ${data.taxEstimate.taxPayable > 0 ? "text-red-500" : "text-emerald-500"}`}>
                      {data.taxEstimate.taxPayable > 0 ? formatCurrency(data.taxEstimate.taxPayable) : "No tax due"}
                    </span>
                    <span className="text-[10px] text-muted-foreground">Payable</span>
                  </div>
                  <div className="flex gap-4 mt-2 text-[10px] font-medium text-muted-foreground">
                    <span>Gross income: {formatCurrency(data.taxEstimate.grossIncome)}</span>
                    <span>TDS paid: {formatCurrency(data.taxEstimate.tdsPaid)}</span>
                    <span>Eff. rate: {data.taxEstimate.effectiveRate}%</span>
                  </div>
                </CardContent>
              </Card>
            )}
          </div>
        )}

        {/* EMI and Recent Transactions row */}
        <div className="grid gap-6 lg:grid-cols-3 animate-stagger-fade" style={{ animationDelay: "200ms" }}>
          {/* Quick Stats Panel */}
          <div className="space-y-4">
            <div className="glass-card glowing-border rounded-2xl p-5 hover-lift-emerald border-indigo-500/10 bg-gradient-to-br from-indigo-500/5 to-transparent">
              <div className="flex items-center justify-between pb-3">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-widest font-display">Active Liabilities</span>
                <Landmark className="w-4 h-4 text-indigo-500" />
              </div>
              <div className="space-y-3">
                <div className="flex items-baseline gap-2">
                  <h4 className="text-2xl font-black tracking-tight text-foreground">{data?.loans.activeCount ?? 0}</h4>
                  <span className="text-[10px] font-bold text-muted-foreground">Active Loans</span>
                </div>
                <div className="space-y-1.5">
                  <div className="flex justify-between text-[10px] font-bold">
                    <span className="text-muted-foreground">Outstanding Total</span>
                    <span className="text-red-500">{formatCurrency(data?.loans.outstandingTotal ?? "0")}</span>
                  </div>
                  <Progress value={45} className="h-1 bg-red-500/10" />
                </div>
              </div>
            </div>

            <div className="glass-card glowing-border rounded-2xl p-5 hover-lift border-primary/10 bg-gradient-to-br from-primary/5 to-transparent">
              <div className="flex items-center justify-between pb-3">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-widest font-display">EMI Commitment</span>
                <ArrowDownRight className="w-4 h-4 text-primary" />
              </div>
              <div>
                <h4 className="text-2xl font-black tracking-tight text-foreground">{formatCurrency(data?.loans.totalEMI ?? "0")}</h4>
                <div className="flex items-center gap-2 mt-2">
                  <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/10">
                    {data?.emis.paid ?? 0} / {data?.emis.totalCount ?? 0} Paid
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Expenses Ledger */}
          <div className="lg:col-span-2 glass-card glowing-border rounded-2xl p-6 shadow-sm overflow-hidden flex flex-col">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h4 className="text-sm font-bold font-display text-foreground flex items-center gap-2">
                  Recent Ledger Entries
                  <Link to="/expenses" className="p-1 hover:bg-muted/50 rounded-md transition-colors"><ArrowUpRight className="w-3.5 h-3.5 text-primary" /></Link>
                </h4>
                <p className="text-[11px] text-muted-foreground">Your most recent outbound transactions</p>
              </div>
              <Link to="/expenses">
                <Button variant="outline" size="sm" className="h-8 rounded-xl text-[10px] font-black uppercase tracking-widest border-border/50 hover:bg-primary hover:text-white transition-all">
                  View Full Ledger
                </Button>
              </Link>
            </div>
            
            <div className="flex-1 min-h-[300px]">
              {isLoading ? (
                <div className="space-y-4">
                  {[...Array(5)].map((_, i) => <Skeleton key={i} className="h-14 w-full bg-muted/40 rounded-xl" />)}
                </div>
              ) : data?.recentExpenses.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-muted-foreground space-y-3 py-10 opacity-60">
                  <Receipt className="w-10 h-10" />
                  <p className="font-bold font-display">No transactions found</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {data?.recentExpenses?.map((exp, idx) => (
                    <div 
                      key={exp.id} 
                      className="flex items-center justify-between p-3.5 rounded-2xl bg-card/25 border border-border/30 hover:border-primary/30 hover:bg-card/60 transition-all duration-300 group hover:-translate-y-0.5 shadow-sm"
                      style={{ animationDelay: `${250 + (idx * 30)}ms` }}
                    >
                      <div className="flex items-center gap-4">
                        <div
                          className="w-11 h-11 rounded-2xl flex items-center justify-center text-white text-xs font-black shadow-lg shadow-black/10 transition-transform group-hover:scale-110"
                          style={{ 
                            backgroundColor: exp.categoryColor || "#818cf8",
                            backgroundImage: `linear-gradient(135deg, ${exp.categoryColor}ee, ${exp.categoryColor}ff)`
                          }}
                        >
                          {exp.categoryName?.[0]?.toUpperCase() || "?"}
                        </div>
                        <div>
                          <p className="text-sm font-bold text-foreground group-hover:text-primary transition-colors">{exp.description || exp.categoryName}</p>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className="text-[10px] font-black uppercase tracking-tighter text-muted-foreground bg-muted/60 px-1.5 py-0.5 rounded border border-border/20">{exp.categoryName}</span>
                            <span className="text-[10px] text-muted-foreground/60 font-medium">
                              {exp.expenseDate ? format(new Date(exp.expenseDate), "dd MMM, yyyy") : ""}
                            </span>
                          </div>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-sm font-black text-red-500 font-sans">
                          -{formatCurrency(exp.amount)}
                        </p>
                        <p className="text-[9px] font-bold text-muted-foreground mt-0.5 uppercase tracking-widest opacity-0 group-hover:opacity-100 transition-opacity">Debit</p>
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
