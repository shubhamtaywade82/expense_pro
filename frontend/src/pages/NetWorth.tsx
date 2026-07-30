import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Progress } from '../components/ui/progress';
import { 
  Building, Wallet, Landmark, TrendingUp, AlertTriangle, 
  ShieldCheck, PieChart as PieChartIcon, Activity
} from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip as RechartsTooltip, BarChart, Bar, XAxis, YAxis, CartesianGrid } from 'recharts';

export default function NetWorth() {
  const { data: netWorthData, isLoading } = useQuery({
    queryKey: ['net-worth'],
    queryFn: () => api.get('/net_worth').then(res => res.data),
  });

  const formatCurrency = (val: number) => `₹${(val || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;

  if (isLoading) return <div className="p-8 text-center text-muted-foreground animate-pulse">Computing your financial footprint...</div>;
  if (!netWorthData) return null;

  const { assets, liabilities, net_worth, emergency_fund_months, debt_to_asset_ratio } = netWorthData;

  const assetData = [
    { name: 'Liquid Cash & Bank', value: assets.liquid_cash || 0, color: '#10b981' },
    { name: 'Investments', value: assets.investments || 0, color: '#3b82f6' },
    { name: 'Retirement (EPF/NPS)', value: assets.retirement_accounts || 0, color: '#8b5cf6' },
    { name: 'Broker Ledger', value: assets.broker_ledger || 0, color: '#f59e0b' },
  ].filter(a => a.value > 0);

  const liabilityData = liabilities.loans?.map((l: any, i: number) => ({
    name: l.name,
    value: l.outstanding || 0,
    color: ['#ef4444', '#f97316', '#eab308', '#ec4899'][i % 4]
  })) || [];

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-4">
        <div>
          <h1 className="text-3xl font-bold font-display tracking-tight flex items-center gap-2">
            <Building className="w-8 h-8 text-primary" />
            Net Worth Command Center
          </h1>
          <p className="text-muted-foreground mt-1">Your complete financial footprint, tracking assets against liabilities.</p>
        </div>
      </div>

      {/* Hero Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="md:col-span-1 bg-gradient-to-br from-primary/10 to-primary/5 border-primary/20 shadow-lg">
          <CardContent className="p-6 flex flex-col justify-center h-full space-y-2">
            <p className="text-sm font-bold uppercase tracking-widest text-primary/80">True Net Worth</p>
            <h2 className={`text-5xl font-black tracking-tighter ${net_worth >= 0 ? 'text-primary' : 'text-destructive'}`}>
              {formatCurrency(net_worth)}
            </h2>
            <p className="text-sm text-muted-foreground mt-2 leading-relaxed">
              Calculated by taking your total verifiable assets and subtracting all outstanding loan principals.
            </p>
          </CardContent>
        </Card>

        <div className="md:col-span-2 grid grid-cols-2 gap-4">
          <Card className="bg-card">
            <CardContent className="p-5 space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 rounded-full bg-emerald-500/10 flex items-center justify-center">
                  <Wallet className="w-5 h-5 text-emerald-500" />
                </div>
                <span className="text-emerald-500 text-sm font-bold flex items-center gap-1">
                  Assets
                </span>
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{formatCurrency(assets.total)}</p>
                <p className="text-xs text-muted-foreground mt-1">Cash, Investments, EPF</p>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card">
            <CardContent className="p-5 space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 rounded-full bg-destructive/10 flex items-center justify-center">
                  <Landmark className="w-5 h-5 text-destructive" />
                </div>
                <span className="text-destructive text-sm font-bold flex items-center gap-1">
                  Liabilities
                </span>
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{formatCurrency(liabilities.total)}</p>
                <p className="text-xs text-muted-foreground mt-1">Active Loan Principals</p>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card">
            <CardContent className="p-5 space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 rounded-full bg-amber-500/10 flex items-center justify-center">
                  <ShieldCheck className="w-5 h-5 text-amber-500" />
                </div>
                <span className="text-amber-500 text-sm font-bold flex items-center gap-1">
                  Safety Net
                </span>
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{emergency_fund_months} Months</p>
                <p className="text-xs text-muted-foreground mt-1">Emergency Fund Coverage</p>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card">
            <CardContent className="p-5 space-y-4">
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 rounded-full bg-indigo-500/10 flex items-center justify-center">
                  <Activity className="w-5 h-5 text-indigo-500" />
                </div>
                <span className="text-indigo-500 text-sm font-bold flex items-center gap-1">
                  Leverage
                </span>
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{debt_to_asset_ratio}%</p>
                <p className="text-xs text-muted-foreground mt-1">Debt to Asset Ratio</p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Breakdowns */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Asset Breakdown */}
        <Card className="shadow-sm">
          <CardHeader className="border-b bg-muted/20 pb-4">
            <CardTitle className="flex items-center gap-2 text-lg">
              <PieChartIcon className="w-5 h-5 text-emerald-500" />
              Asset Distribution
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-6">
            {assetData.length > 0 ? (
              <div className="flex flex-col sm:flex-row items-center gap-8">
                <div className="w-48 h-48 relative">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={assetData}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {assetData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <RechartsTooltip formatter={(value: number) => formatCurrency(value)} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                    <span className="text-xs text-muted-foreground uppercase tracking-widest font-bold">Total</span>
                    <span className="text-sm font-bold">{formatCurrency(assets.total)}</span>
                  </div>
                </div>
                <div className="flex-1 space-y-3 w-full">
                  {assetData.map((item, i) => (
                    <div key={i} className="flex justify-between items-center text-sm">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-full shadow-sm" style={{ backgroundColor: item.color }} />
                        <span className="font-medium text-muted-foreground">{item.name}</span>
                      </div>
                      <span className="font-bold">{formatCurrency(item.value)}</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="py-12 text-center text-muted-foreground">
                <AlertTriangle className="w-8 h-8 mx-auto mb-3 opacity-50" />
                No assets recorded.
              </div>
            )}
          </CardContent>
        </Card>

        {/* Liability Breakdown */}
        <Card className="shadow-sm">
          <CardHeader className="border-b bg-muted/20 pb-4">
            <CardTitle className="flex items-center gap-2 text-lg">
              <TrendingUp className="w-5 h-5 text-destructive" />
              Liability Distribution
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-6">
            {liabilityData.length > 0 ? (
              <div className="flex flex-col sm:flex-row items-center gap-8">
                <div className="w-48 h-48 relative">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={liabilityData}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {liabilityData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <RechartsTooltip formatter={(value: number) => formatCurrency(value)} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                    <span className="text-xs text-muted-foreground uppercase tracking-widest font-bold">Total</span>
                    <span className="text-sm font-bold">{formatCurrency(liabilities.total)}</span>
                  </div>
                </div>
                <div className="flex-1 space-y-3 w-full">
                  {liabilityData.map((item: any, i: number) => (
                    <div key={i} className="flex justify-between items-center text-sm">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-full shadow-sm" style={{ backgroundColor: item.color }} />
                        <span className="font-medium text-muted-foreground">{item.name}</span>
                      </div>
                      <span className="font-bold text-destructive">{formatCurrency(item.value)}</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="py-12 flex flex-col items-center justify-center text-center text-emerald-600/80">
                <div className="w-12 h-12 rounded-full bg-emerald-100 flex items-center justify-center mb-3">
                  <ShieldCheck className="w-6 h-6 text-emerald-600" />
                </div>
                <p className="font-bold">Zero Liabilities!</p>
                <p className="text-sm text-emerald-600/60 mt-1">You are completely debt free.</p>
              </div>
            )}
          </CardContent>
        </Card>

      </div>
    </div>
  );
}
