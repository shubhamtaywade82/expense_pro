import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
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
import { format, parseISO } from "date-fns";

export default function Reports() {
  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  // Apr-Nov → prev FY. Dec-Mar → current FY.
  const defaultFyYear = (now.getMonth() >= 3 && now.getMonth() <= 10) ? now.getFullYear() : (now.getMonth() >= 11 ? now.getFullYear() + 1 : now.getFullYear());
  const [fyYear, setFyYear] = useState(defaultFyYear);

  const { data: monthlyReport, isLoading: monthlyLoading } = useQuery({
    queryKey: ["reports", "monthly", { month, year }],
    queryFn: () => api.reports.monthly({ month, year }),
  });
  const { data: fyReport, isLoading: fyLoading } = useQuery({
    queryKey: ["reports", "financialYear", fyYear],
    queryFn: () => api.reports.financialYear({ year: fyYear }),
  });

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(num);
  };

  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

  const categoryPieData = monthlyReport?.categoryExpenses.map((c) => ({
    name: c.categoryName,
    value: parseFloat(c.total),
    color: c.categoryColor || "#6366f1",
  })) ?? [];

  const dailyData = monthlyReport?.dailyExpenses.map((d) => ({
    date: d.date ? format(new Date(d.date), "dd") : "",
    amount: parseFloat(d.total),
  })) ?? [];

  const fyBarData = fyReport?.monthlyData.map((m) => ({
    month: format(parseISO(m.month + "-01"), "MMM yy"),
    expenses: parseFloat(m.expenses),
    income: parseFloat(m.income),
    bills: parseFloat(m.bills),
    emis: parseFloat(m.emis),
  })) ?? [];

  const fyCategoryData = fyReport?.categoryYearly.map((c) => ({
    name: c.categoryName,
    value: parseFloat(c.total),
    color: c.categoryColor || "#6366f1",
  })) ?? [];

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Reports</h2>
          <p className="text-muted-foreground">Detailed financial reports and analysis</p>
        </div>

        <Tabs defaultValue="monthly" className="space-y-6">
          <TabsList>
            <TabsTrigger value="monthly">Monthly Report</TabsTrigger>
            <TabsTrigger value="financial-year">Financial Year</TabsTrigger>
          </TabsList>

          <TabsContent value="monthly" className="space-y-6">
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={() => { if (month === 1) { setMonth(12); setYear(year - 1); } else setMonth(month - 1); }}>&larr;</Button>
              <span className="text-sm font-medium px-3 py-1 bg-muted rounded-md">{monthNames[month - 1]} {year}</span>
              <Button variant="outline" size="sm" onClick={() => { if (month === 12) { setMonth(1); setYear(year + 1); } else setMonth(month + 1); }}>&rarr;</Button>
            </div>

            {/* Monthly Summary Cards */}
              <div className="grid gap-4 md:grid-cols-4">
                <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Total Expense</CardTitle></CardHeader><CardContent><div className="text-xl font-bold text-red-600">{formatCurrency(monthlyReport?.summary.totalExpense ?? "0")}</div></CardContent></Card>
                <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Total Income</CardTitle></CardHeader><CardContent><div className="text-xl font-bold text-green-600">{formatCurrency(monthlyReport?.summary.totalIncome ?? "0")}</div></CardContent></Card>
                <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Bills + EMIs</CardTitle></CardHeader><CardContent><div className="text-xl font-bold">{formatCurrency((parseFloat(monthlyReport?.summary.totalBills ?? "0") + parseFloat(monthlyReport?.summary.totalEMI ?? "0")))}</div></CardContent></Card>
                <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Net Savings</CardTitle></CardHeader><CardContent><div className={`text-xl font-bold ${parseFloat(monthlyReport?.summary.netSavings ?? "0") >= 0 ? "text-green-600" : "text-red-600"}`}>{formatCurrency(monthlyReport?.summary.netSavings ?? "0")}</div></CardContent></Card>
              </div>

              {/* Income by Type */}
              {monthlyReport?.incomeByType && Object.keys(monthlyReport.incomeByType).length > 0 && (
                <Card>
                  <CardHeader><CardTitle className="text-sm">Income by Source</CardTitle></CardHeader>
                  <CardContent>
                    <div className="flex flex-wrap gap-3">
                      {Object.entries(monthlyReport.incomeByType).map(([type, amount]) => (
                        <div key={type} className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-muted/30 border border-border/50">
                          <span className="text-xs font-medium capitalize text-muted-foreground">{type.replace(/_/g, " ")}</span>
                          <span className="text-sm font-semibold text-green-600">{formatCurrency(amount)}</span>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}

            <div className="grid gap-4 lg:grid-cols-2">
              {/* Daily Expenses Chart */}
              <Card>
                <CardHeader><CardTitle className="text-sm">Daily Expenses</CardTitle></CardHeader>
                <CardContent>
                  {monthlyLoading ? <Skeleton className="h-[250px]" /> : dailyData.length > 0 ? (
                    <ResponsiveContainer width="100%" height={250}>
                      <BarChart data={dailyData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="date" fontSize={10} /><YAxis fontSize={10} tickFormatter={(v) => `₹${v}`} />
                        <Tooltip formatter={(v: number) => formatCurrency(v)} />
                        <Bar dataKey="amount" fill="#6366f1" radius={[4, 4, 0, 0]} />
                      </BarChart>
                    </ResponsiveContainer>
                  ) : <div className="h-[250px] flex items-center justify-center text-muted-foreground">No data</div>}
                </CardContent>
              </Card>

              {/* Category Breakdown */}
              <Card>
                <CardHeader><CardTitle className="text-sm">Category Breakdown</CardTitle></CardHeader>
                <CardContent>
                  {monthlyLoading ? <Skeleton className="h-[250px]" /> : categoryPieData.length > 0 ? (
                    <ResponsiveContainer width="100%" height={250}>
                      <PieChart>
                        <Pie data={categoryPieData} cx="50%" cy="50%" innerRadius={60} outerRadius={90} paddingAngle={2} dataKey="value">
                          {categoryPieData.map((entry, i) => (<Cell key={i} fill={entry.color} />))}
                        </Pie>
                        <Tooltip formatter={(v: number) => formatCurrency(v)} />
                      </PieChart>
                    </ResponsiveContainer>
                  ) : <div className="h-[250px] flex items-center justify-center text-muted-foreground">No data</div>}
                </CardContent>
              </Card>
            </div>

            {/* Category Table */}
            <Card>
              <CardHeader><CardTitle className="text-sm">Category Details</CardTitle></CardHeader>
              <CardContent>
                {monthlyLoading ? <Skeleton className="h-40" /> : (
                  <div className="space-y-2">
                    {monthlyReport?.categoryExpenses.map((c) => (
                      <div key={c.categoryName} className="flex items-center justify-between p-2 rounded hover:bg-muted/50">
                        <div className="flex items-center gap-2"><div className="w-3 h-3 rounded-full" style={{ backgroundColor: c.categoryColor || "#6366f1" }} /><span className="text-sm">{c.categoryName}</span></div>
                        <div className="flex items-center gap-4"><span className="text-xs text-muted-foreground">{c.count} transactions</span><span className="text-sm font-medium">{formatCurrency(c.total)}</span></div>
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Bills & EMI Summary */}
            <div className="grid gap-4 lg:grid-cols-2">
              <Card>
                <CardHeader><CardTitle className="text-sm">Bills Summary</CardTitle></CardHeader>
                <CardContent>
                  {monthlyReport?.billsSummary.length === 0 ? <p className="text-muted-foreground text-sm">No active bills</p> : (
                    <div className="space-y-2">
                      {monthlyReport?.billsSummary.map((b) => (
                        <div key={b.name} className="flex items-center justify-between p-2 rounded hover:bg-muted/50">
                          <div className="flex items-center gap-2"><span className="text-sm">{b.name}</span>{b.isPaid && <span className="text-[10px] bg-green-100 text-green-700 px-1.5 rounded">Paid</span>}</div>
                          <span className="text-sm font-medium">{formatCurrency(b.amount)}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
              <Card>
                <CardHeader><CardTitle className="text-sm">EMI Summary</CardTitle></CardHeader>
                <CardContent>
                  {monthlyReport?.emiSummary.length === 0 ? <p className="text-muted-foreground text-sm">No EMIs this month</p> : (
                    <div className="space-y-2">
                      {monthlyReport?.emiSummary.map((e, i) => (
                        <div key={i} className="flex items-center justify-between p-2 rounded hover:bg-muted/50">
                          <div className="flex items-center gap-2"><span className="text-sm">{e.loanName}</span>{e.isPaid && <span className="text-[10px] bg-green-100 text-green-700 px-1.5 rounded">Paid</span>}</div>
                          <span className="text-sm font-medium">{formatCurrency(e.emiAmount)}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="financial-year" className="space-y-6">
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={() => setFyYear(fyYear - 1)}>&larr;</Button>
              <span className="text-sm font-medium px-3 py-1 bg-muted rounded-md">FY {fyYear}-{fyYear + 1} (Apr - Mar)</span>
              <Button variant="outline" size="sm" onClick={() => setFyYear(fyYear + 1)}>&rarr;</Button>
            </div>

            <div className="grid gap-4 md:grid-cols-4">
              <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Total Expense</CardTitle></CardHeader><CardContent><div className="text-xl font-bold text-red-600">{formatCurrency(fyReport?.summary.totalExpense ?? "0")}</div></CardContent></Card>
              <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Total Income</CardTitle></CardHeader><CardContent><div className="text-xl font-bold text-green-600">{formatCurrency(fyReport?.summary.totalIncome ?? "0")}</div></CardContent></Card>
              <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Bills + EMIs</CardTitle></CardHeader><CardContent><div className="text-xl font-bold">{formatCurrency(parseFloat(fyReport?.summary.totalBills ?? "0") + parseFloat(fyReport?.summary.totalEMI ?? "0"))}</div></CardContent></Card>
              <Card><CardHeader className="pb-2"><CardTitle className="text-xs">Net Savings</CardTitle></CardHeader><CardContent><div className={`text-xl font-bold ${parseFloat(fyReport?.summary.netSavings ?? "0") >= 0 ? "text-green-600" : "text-red-600"}`}>{formatCurrency(fyReport?.summary.netSavings ?? "0")}</div></CardContent></Card>
            </div>

            {/* FY Income by Type */}
            {fyReport?.incomeByType && Object.keys(fyReport.incomeByType).length > 0 && (
              <Card>
                <CardHeader><CardTitle className="text-sm">Income by Source</CardTitle></CardHeader>
                <CardContent>
                  <div className="flex flex-wrap gap-3">
                    {Object.entries(fyReport.incomeByType).map(([type, amount]) => (
                      <div key={type} className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-muted/30 border border-border/50">
                        <span className="text-xs font-medium capitalize text-muted-foreground">{type.replace(/_/g, " ")}</span>
                        <span className="text-sm font-semibold text-green-600">{formatCurrency(amount)}</span>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            )}

            <Card>
              <CardHeader><CardTitle className="text-sm">Monthly Breakdown - FY {fyYear}-{fyYear + 1}</CardTitle></CardHeader>
              <CardContent>
                {fyLoading ? <Skeleton className="h-[300px]" /> : (
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={fyBarData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" fontSize={10} angle={-45} textAnchor="end" height={60} />
                      <YAxis fontSize={10} tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`} />
                      <Tooltip formatter={(value: number, name: string) => [formatCurrency(value), name.charAt(0).toUpperCase() + name.slice(1)]} />
                      <Bar dataKey="income" fill="#22c55e" radius={[4, 4, 0, 0]} />
                      <Bar dataKey="expenses" fill="#ef4444" radius={[4, 4, 0, 0]} />
                      <Bar dataKey="bills" fill="#6366f1" radius={[4, 4, 0, 0]} />
                      <Bar dataKey="emis" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                )}
              </CardContent>
            </Card>

            <div className="grid gap-4 lg:grid-cols-2">
              <Card>
                <CardHeader><CardTitle className="text-sm">Category Breakdown (Full Year)</CardTitle></CardHeader>
                <CardContent>
                  {fyLoading ? <Skeleton className="h-[250px]" /> : fyCategoryData.length > 0 ? (
                    <ResponsiveContainer width="100%" height={250}>
                      <PieChart>
                        <Pie data={fyCategoryData} cx="50%" cy="50%" innerRadius={60} outerRadius={90} paddingAngle={2} dataKey="value">
                          {fyCategoryData.map((entry, i) => (<Cell key={i} fill={entry.color} />))}
                        </Pie>
                        <Tooltip formatter={(v: number) => formatCurrency(v)} />
                      </PieChart>
                    </ResponsiveContainer>
                  ) : <div className="h-[250px] flex items-center justify-center text-muted-foreground">No data</div>}
                </CardContent>
              </Card>

              <Card>
                <CardHeader><CardTitle className="text-sm">Loan Summary</CardTitle></CardHeader>
                <CardContent>
                  {fyReport?.loanSummary.length === 0 ? <p className="text-muted-foreground text-sm">No loans</p> : (
                    <div className="space-y-3">
                      {fyReport?.loanSummary.map((loan, i) => (
                        <div key={i} className="p-3 rounded-lg border">
                          <div className="flex items-center justify-between mb-1"><span className="text-sm font-medium">{loan.name}</span><span className={`text-xs ${loan.isActive ? "text-green-600" : "text-muted-foreground"}`}>{loan.isActive ? "Active" : "Closed"}</span></div>
                          <div className="grid grid-cols-2 gap-2 text-xs text-muted-foreground">
                            <div>Principal: {formatCurrency(loan.principalAmount)}</div>
                            <div>EMI: {formatCurrency(loan.emiAmount)}/mo</div>
                            <div>Outstanding: {formatCurrency(loan.outstandingPrincipal)}</div>
                            <div>EMIs: {loan.paidEmiCount}/{loan.paidEmiCount + loan.remainingEmiCount}</div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
