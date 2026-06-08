import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";

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

  const trendData = data?.monthlyTrend.map((t) => ({
    month: format(new Date(t.month + "-01"), "MMM yy"),
    expenses: parseFloat(t.expenses),
    income: parseFloat(t.income),
  })) ?? [];

  const pieData = data?.categoryBreakdown.map((c) => ({
    name: c.categoryName,
    value: parseFloat(c.total),
    color: c.categoryColor || "#818cf8",
  })) ?? [];

  const totalExpense = parseFloat(data?.expenses.total ?? "0");
  const totalIncome = parseFloat(data?.income.total ?? "0");
  const totalBills = parseFloat(data?.bills.total ?? "0");
  const totalEMI = parseFloat(data?.emis.total ?? "0");
  const netSavings = totalIncome - totalExpense - totalBills - totalEMI;

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
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        {/* Overall Summary Bar */}
        {!isLoading && data?.overall && (
        <div className="glass-card glowing-border rounded-2xl overflow-hidden p-0.5 animate-stagger-fade" style={{ animationDelay: "0ms" }}>
          <div className="bg-card/50 backdrop-blur-lg rounded-[14px] p-5 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-primary/20 to-primary/5 flex items-center justify-center border border-primary/20">
                <Sparkles className="w-5 h-5 text-primary filter drop-shadow-[0_0_6px_rgba(99,102,241,0.4)]" />
              </div>
              <div>
                <span className="text-xs uppercase tracking-wider text-muted-foreground font-semibold font-display">Life-to-Date Net Worth</span>
                <p className={`text-xl font-bold font-sans ${parseFloat(data.overall.netBalance) >= 0 ? "text-gradient-emerald" : "text-red-500"}`}>
                  {formatCurrency(data.overall.netBalance)}
                </p>
              </div>
            </div>
            <div className="flex flex-wrap gap-x-8 gap-y-2 text-xs font-medium text-muted-foreground">
              <div>Total Income: <span className="text-foreground font-semibold ml-1">{formatCurrency(data.overall.totalIncome)}</span></div>
              <div>Total Outflow: <span className="text-foreground font-semibold ml-1">{formatCurrency(parseFloat(data.overall.totalExpense) + parseFloat(data.overall.totalEmiPaid))}</span></div>
              <div>EMI Paid: <span className="text-foreground font-semibold ml-1">{formatCurrency(data.overall.totalEmiPaid)}</span></div>
            </div>
          </div>
        </div>
      )}

      {/* Month Selector */}
      <div className="flex items-center justify-between animate-stagger-fade" style={{ animationDelay: "50ms" }}>
        <div>
          <h2 className="text-2xl font-bold font-display tracking-tight text-foreground">Financial Dashboard</h2>
          <p className="text-sm text-muted-foreground">Overview and metrics of your cashflow</p>
        </div>
        <div className="flex items-center gap-2 bg-card/40 backdrop-blur-md border border-border/40 p-1 rounded-xl">
          <Button variant="ghost" size="icon" onClick={prevMonth} className="rounded-lg h-8 w-8 hover:bg-muted/80">
            <ChevronLeft className="w-4 h-4" />
          </Button>
          <span className="text-xs font-semibold px-2 min-w-[120px] text-center flex items-center justify-center gap-1.5 text-foreground font-display">
            <Calendar className="w-3.5 h-3.5 text-primary" />
            {monthNames[month - 1]} {year}
          </span>
          <Button variant="ghost" size="icon" onClick={nextMonth} className="rounded-lg h-8 w-8 hover:bg-muted/80">
            <ChevronRight className="w-4 h-4" />
          </Button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4 animate-stagger-fade" style={{ animationDelay: "100ms" }}>
        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs uppercase tracking-wider text-muted-foreground font-bold font-display">Total Expenses</span>
            <div className="w-7 h-7 rounded-lg bg-red-500/10 flex items-center justify-center border border-red-500/10">
              <Receipt className="w-4 h-4 text-red-500" />
            </div>
          </div>
          <div>
            {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50" /> : (
              <h3 className="text-2xl font-bold tracking-tight text-red-500">{formatCurrency(totalExpense)}</h3>
            )}
            <p className="text-[11px] font-medium text-muted-foreground mt-1">{data?.expenses.count ?? 0} transactions logged</p>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs uppercase tracking-wider text-muted-foreground font-bold font-display">Total Income</span>
            <div className="w-7 h-7 rounded-lg bg-emerald-500/10 flex items-center justify-center border border-emerald-500/10">
              <Wallet className="w-4 h-4 text-emerald-500" />
            </div>
          </div>
          <div>
            {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50" /> : (
              <h3 className="text-2xl font-bold tracking-tight text-gradient-emerald">{formatCurrency(totalIncome)}</h3>
            )}
            <p className="text-[11px] font-medium text-muted-foreground mt-1">{data?.income.count ?? 0} income sources</p>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs uppercase tracking-wider text-muted-foreground font-bold font-display">Monthly Bills</span>
            <div className="w-7 h-7 rounded-lg bg-indigo-500/10 flex items-center justify-center border border-indigo-500/10">
              <FileText className="w-4 h-4 text-indigo-500" />
            </div>
          </div>
          <div>
            {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50" /> : (
              <h3 className="text-2xl font-bold tracking-tight text-foreground">{formatCurrency(totalBills)}</h3>
            )}
            <div className="flex items-center gap-2 mt-1.5">
              <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-600 border border-emerald-500/10">
                {data?.bills.paid ?? 0} Paid
              </span>
              {data?.bills.unpaid && data.bills.unpaid > 0 ? (
                <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-amber-500/10 text-amber-600 border border-amber-500/10 flex items-center gap-0.5">
                  <AlertCircle className="w-2.5 h-2.5" />
                  {data.bills.unpaid} Pending
                </span>
              ) : null}
            </div>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs uppercase tracking-wider text-muted-foreground font-bold font-display">Net Savings</span>
            <div className="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center border border-primary/10">
              <TrendingUp className="w-4 h-4 text-primary" />
            </div>
          </div>
          <div>
            {isLoading ? <Skeleton className="h-8 w-28 bg-muted/50" /> : (
              <h3 className={`text-2xl font-bold tracking-tight ${netSavings >= 0 ? "text-gradient-emerald" : "text-red-500"}`}>
                {formatCurrency(netSavings)}
              </h3>
            )}
            <p className="text-[11px] font-medium text-muted-foreground mt-1">
              {totalIncome > 0 ? `${((netSavings / totalIncome) * 100).toFixed(1)}% of income saved` : "No monthly income input"}
            </p>
          </div>
        </div>
      </div>

      {/* EMI & Loans summary row */}
      <div className="grid gap-4 md:grid-cols-3 animate-stagger-fade" style={{ animationDelay: "150ms" }}>
        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift-emerald">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs font-bold text-muted-foreground font-display">EMI This Month</span>
            <Landmark className="w-4 h-4 text-muted-foreground" />
          </div>
          <div>
            {isLoading ? <Skeleton className="h-7 w-24 bg-muted/50" /> : (
              <h4 className="text-xl font-bold tracking-tight text-foreground">{formatCurrency(totalEMI)}</h4>
            )}
            <p className="text-xs text-muted-foreground mt-1">
              {data?.emis.paid ?? 0} / {data?.emis.totalCount ?? 0} EMIs cleared
            </p>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift-emerald">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs font-bold text-muted-foreground font-display">Active Loans</span>
            <IndianRupee className="w-4 h-4 text-muted-foreground" />
          </div>
          <div>
            {isLoading ? <Skeleton className="h-7 w-24 bg-muted/50" /> : (
              <h4 className="text-xl font-bold tracking-tight text-foreground">{data?.loans.activeCount ?? 0} active loans</h4>
            )}
            <p className="text-xs text-muted-foreground mt-1">
              Total Outstanding: <span className="font-semibold text-red-500">{formatCurrency(data?.loans.outstandingTotal ?? "0")}</span>
            </p>
          </div>
        </div>

        <div className="glass-card glowing-border rounded-2xl p-5 hover-lift-emerald">
          <div className="flex items-center justify-between pb-3">
            <span className="text-xs font-bold text-muted-foreground font-display">Monthly EMI Commitment</span>
            <ArrowDownRight className="w-4 h-4 text-muted-foreground" />
          </div>
          <div>
            {isLoading ? <Skeleton className="h-7 w-24 bg-muted/50" /> : (
              <h4 className="text-xl font-bold tracking-tight text-foreground">{formatCurrency(data?.loans.totalEMI ?? "0")}</h4>
            )}
            <p className="text-xs text-muted-foreground mt-1">Total recurring EMI commitments</p>
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid gap-4 lg:grid-cols-2 animate-stagger-fade" style={{ animationDelay: "200ms" }}>
        <div className="glass-card glowing-border rounded-2xl p-5">
          <h4 className="text-sm font-semibold font-display text-muted-foreground mb-4">Cashflow Trend (Income vs Expenses)</h4>
          {isLoading ? <Skeleton className="h-[250px] bg-muted/50" /> : (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={trendData} barGap={6}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="rgba(255,255,255,0.05)" />
                <XAxis dataKey="month" fontSize={11} stroke="rgba(255,255,255,0.4)" tickLine={false} />
                <YAxis fontSize={11} stroke="rgba(255,255,255,0.4)" tickLine={false} tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`} />
                <Tooltip content={<CustomTooltip />} cursor={{ fill: "rgba(255,255,255,0.02)" }} />
                <Bar dataKey="income" fill="url(#incomeGradient)" radius={[4, 4, 0, 0]} name="Income" />
                <Bar dataKey="expenses" fill="url(#expenseGradient)" radius={[4, 4, 0, 0]} name="Expenses" />
                
                {/* SVG Gradient declarations */}
                <defs>
                  <linearGradient id="incomeGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#10b981" stopOpacity={0.95} />
                    <stop offset="100%" stopColor="#059669" stopOpacity={0.7} />
                  </linearGradient>
                  <linearGradient id="expenseGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#ef4444" stopOpacity={0.95} />
                    <stop offset="100%" stopColor="#dc2626" stopOpacity={0.7} />
                  </linearGradient>
                </defs>
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        <div className="glass-card glowing-border rounded-2xl p-5">
          <h4 className="text-sm font-semibold font-display text-muted-foreground mb-4">Expense Categories Breakdown</h4>
          {isLoading ? <Skeleton className="h-[250px] bg-muted/50" /> : pieData.length > 0 ? (
            <div className="flex items-center justify-between flex-wrap gap-4">
              <div className="flex-1 min-w-[200px]">
                <ResponsiveContainer width="100%" height={250}>
                  <PieChart>
                    <Pie
                      data={pieData}
                      cx="50%"
                      cy="50%"
                      innerRadius={65}
                      outerRadius={95}
                      paddingAngle={3}
                      dataKey="value"
                    >
                      {pieData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} stroke="transparent" />
                      ))}
                    </Pie>
                    <Tooltip content={<CustomTooltip />} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="space-y-2 max-h-[250px] overflow-y-auto pr-2">
                {pieData.map((entry, index) => (
                  <div key={index} className="flex items-center gap-2 text-xs">
                    <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: entry.color }} />
                    <span className="text-muted-foreground font-medium truncate max-w-[120px]">{entry.name}</span>
                    <span className="font-semibold text-foreground ml-auto">{formatCurrency(entry.value)}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="h-[250px] flex flex-col items-center justify-center text-muted-foreground text-sm">
              <AlertCircle className="w-8 h-8 text-muted-foreground/50 mb-2" />
              No expense data recorded for this month
            </div>
          )}
        </div>
      </div>

      {/* Recent Expenses */}
      <div className="glass-card glowing-border rounded-2xl p-5 animate-stagger-fade" style={{ animationDelay: "250ms" }}>
        <div className="flex items-center justify-between mb-4">
          <h4 className="text-sm font-semibold font-display text-muted-foreground">Recent Transactions</h4>
          <Link to="/expenses">
            <Button variant="ghost" size="sm" className="rounded-lg text-primary hover:text-primary/80 hover:bg-primary/5">
              View All Ledger &rarr;
            </Button>
          </Link>
        </div>
        <div>
          {isLoading ? (
            <div className="space-y-3">
              {[...Array(3)].map((_, i) => <Skeleton key={i} className="h-12 bg-muted/50 rounded-xl" />)}
            </div>
          ) : data?.recentExpenses.length === 0 ? (
            <p className="text-center text-muted-foreground py-6 text-sm">No expenses recorded yet</p>
          ) : (
            <div className="divide-y divide-border/30">
              {data?.recentExpenses.map((exp) => (
                <div key={exp.id} className="flex items-center justify-between py-3.5 first:pt-0 last:pb-0 group">
                  <div className="flex items-center gap-3">
                    <div
                      className="w-9 h-9 rounded-xl flex items-center justify-center text-white text-xs font-bold shadow-md transition-transform group-hover:scale-105"
                      style={{ 
                        backgroundColor: exp.categoryColor || "#818cf8",
                        backgroundImage: `linear-gradient(135deg, ${exp.categoryColor}dd, ${exp.categoryColor}ff)`
                      }}
                    >
                      {exp.categoryName?.[0]?.toUpperCase() || "?"}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-foreground">{exp.description}</p>
                      <p className="text-xs text-muted-foreground mt-0.5">
                        <span className="font-medium text-foreground/70">{exp.categoryName}</span> · {exp.expenseDate ? format(new Date(exp.expenseDate), "dd MMM yyyy") : ""}
                      </p>
                    </div>
                  </div>
                  <span className="text-sm font-bold text-red-500 font-sans">
                    -{formatCurrency(exp.amount)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
        </div>
        </div>
        </div>
        );
}
