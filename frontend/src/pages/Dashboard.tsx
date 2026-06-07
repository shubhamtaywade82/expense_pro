import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
    color: c.categoryColor || "#6366f1",
  })) ?? [];

  const totalExpense = parseFloat(data?.expenses.total ?? "0");
  const totalIncome = parseFloat(data?.income.total ?? "0");
  const totalBills = parseFloat(data?.bills.total ?? "0");
  const totalEMI = parseFloat(data?.emis.total ?? "0");
  const netSavings = totalIncome - totalExpense - totalBills - totalEMI;

  return (
    <div className="space-y-6">
      {/* Month Selector */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Dashboard</h2>
          <p className="text-muted-foreground">Overview of your finances</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={prevMonth}>&larr;</Button>
          <span className="text-sm font-medium px-3 py-1 bg-muted rounded-md min-w-[140px] text-center">
            {monthNames[month - 1]} {year}
          </span>
          <Button variant="outline" size="sm" onClick={nextMonth}>&rarr;</Button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Total Expenses</CardTitle>
            <Receipt className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className="text-2xl font-bold text-red-600">{formatCurrency(totalExpense)}</div>
            )}
            <p className="text-xs text-muted-foreground">{data?.expenses.count ?? 0} transactions</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Total Income</CardTitle>
            <Wallet className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className="text-2xl font-bold text-green-600">{formatCurrency(totalIncome)}</div>
            )}
            <p className="text-xs text-muted-foreground">{data?.income.count ?? 0} sources</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Monthly Bills</CardTitle>
            <FileText className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className="text-2xl font-bold">{formatCurrency(totalBills)}</div>
            )}
            <div className="flex items-center gap-1 text-xs text-muted-foreground">
              <span>{data?.bills.paid ?? 0} paid</span>
              <span className="text-orange-500 flex items-center gap-0.5">
                <AlertCircle className="w-3 h-3" />
                {data?.bills.unpaid ?? 0} pending
              </span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Net Savings</CardTitle>
            <TrendingUp className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className={`text-2xl font-bold ${netSavings >= 0 ? "text-green-600" : "text-red-600"}`}>
                {formatCurrency(netSavings)}
              </div>
            )}
            <p className="text-xs text-muted-foreground">
              {totalIncome > 0 ? `${((netSavings / totalIncome) * 100).toFixed(1)}% of income` : "No income recorded"}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* EMI & Loans summary row */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">EMI This Month</CardTitle>
            <Landmark className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className="text-xl font-bold">{formatCurrency(totalEMI)}</div>
            )}
            <p className="text-xs text-muted-foreground">
              {data?.emis.paid ?? 0} / {data?.emis.totalCount ?? 0} EMIs paid
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Active Loans</CardTitle>
            <IndianRupee className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className="text-xl font-bold">{data?.loans.activeCount ?? 0} loans</div>
            )}
            <p className="text-xs text-muted-foreground">
              Outstanding: {formatCurrency(data?.loans.outstandingTotal ?? "0")}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Monthly EMI</CardTitle>
            <ArrowDownRight className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-8 w-28" /> : (
              <div className="text-xl font-bold">{formatCurrency(data?.loans.totalEMI ?? "0")}</div>
            )}
            <p className="text-xs text-muted-foreground">Total monthly commitment</p>
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">Income vs Expenses Trend</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-[250px]" /> : (
              <ResponsiveContainer width="100%" height={250}>
                <BarChart data={trendData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="month" fontSize={12} />
                  <YAxis fontSize={12} tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`} />
                  <Tooltip formatter={(value: number) => formatCurrency(value)} />
                  <Bar dataKey="income" fill="#22c55e" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="expenses" fill="#ef4444" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">Top Spending Categories</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? <Skeleton className="h-[250px]" /> : pieData.length > 0 ? (
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={90}
                    paddingAngle={2}
                    dataKey="value"
                  >
                    {pieData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(value: number) => formatCurrency(value)} />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[250px] flex items-center justify-center text-muted-foreground">
                No expense data for this month
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Recent Expenses */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-sm font-medium">Recent Expenses</CardTitle>
          <Link to="/expenses">
            <Button variant="ghost" size="sm">View All</Button>
          </Link>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => <Skeleton key={i} className="h-12" />)}
            </div>
          ) : data?.recentExpenses.length === 0 ? (
            <p className="text-center text-muted-foreground py-6">No expenses recorded yet</p>
          ) : (
            <div className="space-y-3">
              {data?.recentExpenses.map((exp) => (
                <div key={exp.id} className="flex items-center justify-between py-2 border-b last:border-0">
                  <div className="flex items-center gap-3">
                    <div
                      className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs"
                      style={{ backgroundColor: exp.categoryColor || "#6366f1" }}
                    >
                      {exp.categoryName?.[0]?.toUpperCase() || "?"}
                    </div>
                    <div>
                      <p className="text-sm font-medium">{exp.description}</p>
                      <p className="text-xs text-muted-foreground">
                        {exp.categoryName} · {exp.expenseDate ? format(new Date(exp.expenseDate), "dd MMM yyyy") : ""}
                      </p>
                    </div>
                  </div>
                  <span className="text-sm font-semibold text-red-600">
                    -{formatCurrency(exp.amount)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
