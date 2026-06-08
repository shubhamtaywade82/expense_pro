import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Plus, Trash2, CheckCircle2, Circle, ChevronDown, ChevronUp, Landmark, Calculator } from "lucide-react";

export default function Loans() {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [expandedLoan, setExpandedLoan] = useState<number | null>(null);
  const [form, setForm] = useState({
    categoryId: "",
    name: "",
    lender: "",
    principalAmount: "",
    interestRate: "",
    tenureMonths: "",
    startDate: new Date().toISOString().split("T")[0],
    loanType: "personal" as string,
    notes: "",
  });

  const queryClient = useQueryClient();
  const { data: categories } = useQuery({ queryKey: ["categories"], queryFn: api.categories.list });
  const { data: loans, isLoading } = useQuery({ queryKey: ["loans"], queryFn: api.loans.list });
  const { data: loanDetail } = useQuery({
    queryKey: ["loans", expandedLoan],
    queryFn: () => api.loans.byId(expandedLoan as number),
    enabled: !!expandedLoan,
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["loans"] });
    queryClient.invalidateQueries({ queryKey: ["dashboard"] });
  };

  const createMutation = useMutation({ mutationFn: api.loans.create, onSuccess: () => { invalidate(); resetForm(); } });
  const deleteMutation = useMutation({ mutationFn: api.loans.delete, onSuccess: invalidate });
  const payEmiMutation = useMutation({ mutationFn: api.loans.payEmi, onSuccess: invalidate });

  const emiCategories = categories?.filter((c) => c.type === "emi") ?? [];

  const resetForm = () => {
    setForm({ categoryId: "", name: "", lender: "", principalAmount: "", interestRate: "", tenureMonths: "", startDate: new Date().toISOString().split("T")[0], loanType: "personal", notes: "" });
    setDialogOpen(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.categoryId || !form.name || !form.lender || !form.principalAmount || !form.interestRate || !form.tenureMonths) return;
    createMutation.mutate({
      categoryId: Number(form.categoryId),
      name: form.name,
      lender: form.lender,
      principalAmount: form.principalAmount,
      interestRate: form.interestRate,
      tenureMonths: Number(form.tenureMonths),
      startDate: form.startDate,
      loanType: form.loanType as "home" | "car" | "personal" | "education" | "business" | "gold" | "other",
      notes: form.notes || undefined,
    });
  };

  const formatCurrency = (val: string | number) => {
    const num = typeof val === "string" ? parseFloat(val) : val;
    return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(num);
  };

  const totalOutstanding = loans?.reduce((sum, l) => sum + (l.isActive ? parseFloat(String(l.outstandingPrincipal)) : 0), 0) ?? 0;
  const totalEMI = loans?.reduce((sum, l) => sum + (l.isActive ? parseFloat(String(l.emiAmount)) : 0), 0) ?? 0;
  const activeLoans = loans?.filter((l) => l.isActive).length ?? 0;

  const loanTypeLabels: Record<string, string> = { home: "Home", car: "Car", personal: "Personal", education: "Education", business: "Business", gold: "Gold", other: "Other" };

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Loans & EMIs</h2>
            <p className="text-muted-foreground">Track your loans and EMI payments</p>
          </div>
          <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }}><Plus className="w-4 h-4 mr-1" /> Add Loan</Button>
            </DialogTrigger>
            <DialogContent className="max-w-lg">
              <DialogHeader><DialogTitle>Add New Loan</DialogTitle></DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  <div><Label>Category</Label>
                    <Select value={form.categoryId} onValueChange={(v) => setForm({ ...form, categoryId: v })}>
                      <SelectTrigger><SelectValue placeholder="Select" /></SelectTrigger>
                      <SelectContent>{emiCategories.map((c) => (<SelectItem key={c.id} value={String(c.id)}>{c.name}</SelectItem>))}</SelectContent>
                    </Select>
                  </div>
                  <div><Label>Loan Type</Label>
                    <Select value={form.loanType} onValueChange={(v) => setForm({ ...form, loanType: v })}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>{Object.entries(loanTypeLabels).map(([k, v]) => (<SelectItem key={k} value={k}>{v}</SelectItem>))}</SelectContent>
                    </Select>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div><Label>Loan Name</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g., Home Loan" /></div>
                  <div><Label>Lender</Label><Input value={form.lender} onChange={(e) => setForm({ ...form, lender: e.target.value })} placeholder="e.g., SBI" /></div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div><Label>Principal (₹)</Label><Input type="number" value={form.principalAmount} onChange={(e) => setForm({ ...form, principalAmount: e.target.value })} placeholder="5000000" /></div>
                  <div><Label>Interest Rate (% p.a.)</Label><Input type="number" step="0.01" value={form.interestRate} onChange={(e) => setForm({ ...form, interestRate: e.target.value })} placeholder="8.5" /></div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div><Label>Tenure (Months)</Label><Input type="number" value={form.tenureMonths} onChange={(e) => setForm({ ...form, tenureMonths: e.target.value })} placeholder="240" /></div>
                  <div><Label>Start Date</Label><Input type="date" value={form.startDate} onChange={(e) => setForm({ ...form, startDate: e.target.value })} /></div>
                </div>
                <div><Label>Notes</Label><Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Optional" /></div>
                <DialogFooter>
                  <Button type="button" variant="outline" onClick={resetForm}>Cancel</Button>
                  <Button type="submit" disabled={createMutation.isPending}><Calculator className="w-4 h-4 mr-1" />Calculate & Add</Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <Card><CardHeader className="pb-2"><CardTitle className="text-sm">Active Loans</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold flex items-center gap-2"><Landmark className="w-5 h-5" />{activeLoans}</div></CardContent></Card>
          <Card><CardHeader className="pb-2"><CardTitle className="text-sm">Total Outstanding</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold text-orange-600">{formatCurrency(totalOutstanding)}</div></CardContent></Card>
          <Card><CardHeader className="pb-2"><CardTitle className="text-sm">Monthly EMI Outgo</CardTitle></CardHeader><CardContent><div className="text-2xl font-bold text-red-600">{formatCurrency(totalEMI)}</div></CardContent></Card>
        </div>

        <div className="space-y-4">
          {isLoading ? <div className="space-y-3">{[...Array(3)].map((_, i) => <Skeleton key={i} className="h-24" />)}</div> : loans?.length === 0 ? (
            <p className="text-center text-muted-foreground py-8">No loans added yet</p>
          ) : (
            loans?.map((loan) => {
              const progress = loan.tenureMonths > 0 ? (loan.paidEmiCount / loan.tenureMonths) * 100 : 0;
              const isExpanded = expandedLoan === loan.id;
              return (
                <Card key={loan.id} className={`${!loan.isActive ? "opacity-60" : ""}`}>
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white font-bold text-sm" style={{ backgroundColor: loan.categoryColor || "#6366f1" }}>
                          {loanTypeLabels[loan.loanType]?.[0] || "L"}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="font-medium">{loan.name}</p>
                            <Badge variant="outline" className="text-[10px] h-4">{loanTypeLabels[loan.loanType]}</Badge>
                            {!loan.isActive && <Badge variant="secondary" className="text-[10px] h-4">Closed</Badge>}
                          </div>
                          <p className="text-xs text-muted-foreground">{loan.lender} · {formatCurrency(loan.principalAmount)} @ {loan.interestRate}%</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="text-right">
                          <p className="text-sm font-semibold">{formatCurrency(loan.emiAmount)}/mo</p>
                          <p className="text-xs text-muted-foreground">{loan.paidEmiCount}/{loan.tenureMonths} EMIs</p>
                        </div>
                        <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setExpandedLoan(isExpanded ? null : loan.id)}>
                          {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                        </Button>
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-red-500" onClick={() => deleteMutation.mutate(loan.id)}><Trash2 className="w-4 h-4" /></Button>
                      </div>
                    </div>
                    <div className="mt-3">
                      <div className="flex justify-between text-xs mb-1"><span>Progress</span><span>{progress.toFixed(1)}%</span></div>
                      <Progress value={progress} className="h-2" />
                    </div>

                    {isExpanded && loanDetail && (
                      <div className="mt-4 border-t pt-4">
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
                          <div className="bg-muted p-2 rounded-lg"><p className="text-xs text-muted-foreground">Principal</p><p className="font-semibold text-sm">{formatCurrency(loan.principalAmount)}</p></div>
                          <div className="bg-muted p-2 rounded-lg"><p className="text-xs text-muted-foreground">Total Interest</p><p className="font-semibold text-sm">{formatCurrency(loan.totalInterest)}</p></div>
                          <div className="bg-muted p-2 rounded-lg"><p className="text-xs text-muted-foreground">Total Payable</p><p className="font-semibold text-sm">{formatCurrency(loan.totalAmount)}</p></div>
                          <div className="bg-muted p-2 rounded-lg"><p className="text-xs text-muted-foreground">Outstanding</p><p className="font-semibold text-sm text-orange-600">{formatCurrency(loan.outstandingPrincipal)}</p></div>
                        </div>
                        <h4 className="text-sm font-medium mb-2">EMI Schedule</h4>
                        <div className="max-h-64 overflow-y-auto space-y-1">
                          {loanDetail.emis?.map((emi) => (
                            <div key={emi.id} className="flex items-center justify-between p-2 rounded hover:bg-muted/50 text-sm">
                              <div className="flex items-center gap-2">
                                <button onClick={() => !emi.isPaid && payEmiMutation.mutate({ emiId: emi.id, paidDate: new Date().toISOString().split("T")[0] })}>
                                  {emi.isPaid ? <CheckCircle2 className="w-4 h-4 text-green-600" /> : <Circle className="w-4 h-4 text-muted-foreground" />}
                                </button>
                                <span>EMI #{emi.emiNumber}</span>
                              </div>
                              <div className="flex items-center gap-3 text-xs">
                                <span className="text-muted-foreground">{emi.dueDate ? new Date(emi.dueDate).toLocaleDateString("en-IN", { month: "short", year: "numeric" }) : ""}</span>
                                <span className="font-medium">{formatCurrency(emi.amount)}</span>
                                <span className="text-green-600 hidden md:inline">P: {formatCurrency(emi.principalAmount)}</span>
                                <span className="text-orange-600 hidden md:inline">I: {formatCurrency(emi.interestAmount)}</span>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
