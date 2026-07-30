import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Slider } from '../components/ui/slider';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { 
  PiggyBank, TrendingDown, Target, Zap, 
  Snowflake, Calculator, IndianRupee, AlertCircle, CheckCircle2
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend, CartesianGrid, ReferenceLine } from 'recharts';

export default function DebtPlanner() {
  const [extraMonthly, setExtraMonthly] = useState(0);
  const [strategy, setStrategy] = useState<'avalanche' | 'snowball'>('avalanche');

  const { data: summary, isLoading: loadingSummary } = useQuery({
    queryKey: ['debt-summary'],
    queryFn: () => api.get('/debt_planner/summary').then(res => res.data),
  });

  const { data: simulation, isLoading: loadingSimulation } = useQuery({
    queryKey: ['debt-simulation', strategy, extraMonthly],
    queryFn: () => api.get(`/debt_planner/simulate?strategy=${strategy}&extra_monthly=${extraMonthly}`).then(res => res.data),
    enabled: !!summary?.loans?.length,
  });

  const formatCurrency = (val: number) => `₹${val.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;

  if (loadingSummary) return <div className="p-8 text-center text-muted-foreground">Loading debt profiles...</div>;

  const hasDebt = summary?.total_outstanding > 0;

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-4">
        <div>
          <h1 className="text-3xl font-bold font-display tracking-tight flex items-center gap-2">
            <Target className="w-8 h-8 text-primary" />
            Debt Planner
          </h1>
          <p className="text-muted-foreground mt-1">Accelerate your journey to becoming debt-free.</p>
        </div>
        
        {hasDebt && (
          <div className="flex items-center gap-4 bg-card px-4 py-2 rounded-xl border shadow-sm">
            <div>
              <p className="text-xs text-muted-foreground uppercase tracking-wider font-semibold">Total Debt</p>
              <p className="text-xl font-bold text-destructive">{formatCurrency(summary.total_outstanding)}</p>
            </div>
            <div className="h-10 w-px bg-border mx-2"></div>
            <div>
              <p className="text-xs text-muted-foreground uppercase tracking-wider font-semibold">DTI Ratio</p>
              <p className={`text-xl font-bold ${summary.debt_to_income_ratio > 40 ? 'text-destructive' : 'text-amber-500'}`}>
                {summary.debt_to_income_ratio}%
              </p>
            </div>
          </div>
        )}
      </div>

      {!hasDebt ? (
        <Card className="bg-green-50/50 border-green-200 dark:bg-green-950/20 dark:border-green-900">
          <CardContent className="flex flex-col items-center justify-center py-12 text-center space-y-4">
            <div className="w-16 h-16 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center">
              <CheckCircle2 className="w-8 h-8 text-green-600 dark:text-green-400" />
            </div>
            <h2 className="text-2xl font-bold text-green-800 dark:text-green-300">You are Debt Free!</h2>
            <p className="text-green-600/80 dark:text-green-400/80 max-w-md">
              Congratulations! You don't have any active loan accounts. Start redirecting your cash flow to investments to build wealth.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-6 lg:grid-cols-3">
          
          {/* Controls Panel */}
          <Card className="lg:col-span-1 border-primary/20 shadow-md">
            <CardHeader className="bg-primary/5 pb-4 border-b">
              <CardTitle className="flex items-center gap-2">
                <Calculator className="w-5 h-5 text-primary" />
                Payoff Simulator
              </CardTitle>
              <CardDescription>Adjust your strategy to see how much faster you can become debt-free.</CardDescription>
            </CardHeader>
            
            <CardContent className="space-y-6 pt-6">
              <div className="space-y-3">
                <Label className="text-base font-semibold">Select Strategy</Label>
                <Tabs value={strategy} onValueChange={(v) => setStrategy(v as any)} className="w-full">
                  <TabsList className="grid w-full grid-cols-2">
                    <TabsTrigger value="avalanche" className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
                      <TrendingDown className="w-4 h-4 mr-2" /> Avalanche
                    </TabsTrigger>
                    <TabsTrigger value="snowball" className="data-[state=active]:bg-info data-[state=active]:text-info-foreground">
                      <Snowflake className="w-4 h-4 mr-2" /> Snowball
                    </TabsTrigger>
                  </TabsList>
                  <TabsContent value="avalanche" className="text-xs text-muted-foreground mt-2">
                    <strong>Highest Interest First.</strong> Saves the most money mathematically. Good for logical thinkers.
                  </TabsContent>
                  <TabsContent value="snowball" className="text-xs text-muted-foreground mt-2">
                    <strong>Smallest Balance First.</strong> Quick psychological wins. Good for staying motivated.
                  </TabsContent>
                </Tabs>
              </div>

              <div className="space-y-4 pt-4 border-t">
                <div className="flex justify-between items-center">
                  <Label className="text-base font-semibold flex items-center gap-2">
                    <Zap className="w-4 h-4 text-amber-500" />
                    Extra Monthly Payment
                  </Label>
                  <span className="font-mono font-bold text-primary">{formatCurrency(extraMonthly)}</span>
                </div>
                
                <Slider 
                  value={[extraMonthly]} 
                  max={100000} 
                  step={1000}
                  onValueChange={(vals) => setExtraMonthly(vals[0])}
                  className="py-2"
                />
                
                <div className="bg-muted/50 p-3 rounded-lg flex items-start gap-3 text-sm">
                  <PiggyBank className="w-5 h-5 text-muted-foreground shrink-0 mt-0.5" />
                  <p className="text-muted-foreground leading-relaxed">
                    By adding just <strong className="text-foreground">{formatCurrency(extraMonthly)}</strong> extra to your payments each month, you can drastically reduce your interest burden.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Results Panel */}
          <div className="lg:col-span-2 space-y-6">
            
            {/* KPI Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Card className="bg-card">
                <CardContent className="p-4 flex flex-col justify-center items-center text-center h-full">
                  <p className="text-xs text-muted-foreground uppercase font-bold tracking-wider mb-1">Total Interest</p>
                  <p className="text-2xl font-bold text-destructive">
                    {simulation ? formatCurrency(simulation.total_interest_paid) : '...'}
                  </p>
                </CardContent>
              </Card>
              
              <Card className="bg-card">
                <CardContent className="p-4 flex flex-col justify-center items-center text-center h-full">
                  <p className="text-xs text-muted-foreground uppercase font-bold tracking-wider mb-1">Time to Freedom</p>
                  <p className="text-2xl font-bold text-primary">
                    {simulation ? `${simulation.total_months} mo` : '...'}
                  </p>
                  <p className="text-xs text-muted-foreground mt-1">
                    {simulation ? `${(simulation.total_months / 12).toFixed(1)} years` : ''}
                  </p>
                </CardContent>
              </Card>

              <Card className="bg-primary/10 border-primary/20 md:col-span-2">
                <CardContent className="p-4 flex flex-col justify-center items-center text-center h-full relative overflow-hidden">
                  <div className="absolute -right-4 -bottom-4 opacity-10">
                    <TrendingDown className="w-24 h-24" />
                  </div>
                  <p className="text-xs text-primary/80 uppercase font-bold tracking-wider mb-1 z-10">Interest Saved</p>
                  <p className="text-3xl font-black text-primary z-10">
                    {simulation ? formatCurrency(simulation.interest_saved) : '...'}
                  </p>
                  <p className="text-xs text-primary/70 mt-1 z-10">vs standard minimum payments</p>
                </CardContent>
              </Card>
            </div>

            {/* Payoff Chart */}
            <Card className="shadow-sm">
              <CardHeader className="pb-2">
                <CardTitle className="text-lg">Balance Reduction Timeline</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="h-[300px] w-full mt-4">
                  {simulation?.timeline ? (
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={simulation.timeline} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                        <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--muted-foreground)/0.2)" />
                        <XAxis 
                          dataKey="month" 
                          tickFormatter={(val) => `Mo ${val}`} 
                          tick={{ fontSize: 12, fill: 'hsl(var(--muted-foreground))' }}
                          axisLine={false}
                          tickLine={false}
                        />
                        <YAxis 
                          tickFormatter={(val) => `₹${(val/1000).toFixed(0)}k`}
                          tick={{ fontSize: 12, fill: 'hsl(var(--muted-foreground))' }}
                          axisLine={false}
                          tickLine={false}
                          width={60}
                        />
                        <Tooltip 
                          formatter={(value: number) => formatCurrency(value)}
                          labelFormatter={(label) => `Month ${label}`}
                          contentStyle={{ borderRadius: '8px', border: '1px solid hsl(var(--border))', backgroundColor: 'hsl(var(--card))' }}
                        />
                        <ReferenceLine y={0} stroke="hsl(var(--foreground))" />
                        
                        {/* We dynamically generate a Bar for each loan ID in the timeline */}
                        {summary.loans.map((loan: any, index: number) => (
                          <Bar 
                            key={loan.id} 
                            dataKey={loan.id} 
                            name={loan.name} 
                            stackId="a" 
                            fill={`hsl(var(--chart-${(index % 5) + 1}))`} 
                            radius={index === summary.loans.length - 1 ? [4, 4, 0, 0] : [0, 0, 0, 0]}
                          />
                        ))}
                      </BarChart>
                    </ResponsiveContainer>
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-muted-foreground">
                      Running simulation...
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>

          </div>
        </div>
      )}
    </div>
  );
}
