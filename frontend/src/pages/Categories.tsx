import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Category } from "@/types";
import { Card, CardContent } from "@/components/ui/card";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus, Pencil, Trash2, ShoppingCart, Plane, Utensils, Film, HeartPulse, GraduationCap, ShoppingBag, Fuel, Wrench, Sparkles, Home, Zap, Droplets, Wifi, Smartphone, CreditCard, Shield, Building2, Car, User, BookOpen, Banknote, Laptop, TrendingUp, Wallet } from "lucide-react";

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  "shopping-cart": ShoppingCart, plane: Plane, utensils: Utensils, film: Film, "heart-pulse": HeartPulse,
  "graduation-cap": GraduationCap, "shopping-bag": ShoppingBag, fuel: Fuel, wrench: Wrench, sparkles: Sparkles,
  home: Home, zap: Zap, droplets: Droplets, wifi: Wifi, smartphone: Smartphone, "credit-card": CreditCard,
  shield: Shield, "building-2": Building2, car: Car, user: User, "book-open": BookOpen, banknote: Banknote,
  laptop: Laptop, "trending-up": TrendingUp, wallet: Wallet,
};

const typeColors: Record<string, string> = { expense: "bg-red-100 text-red-700", income: "bg-green-100 text-green-700", bill: "bg-blue-100 text-blue-700", emi: "bg-purple-100 text-purple-700", loan: "bg-orange-100 text-orange-700" };

export default function Categories() {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState({ name: "", icon: "wallet", color: "#6366f1", type: "expense" });

  const queryClient = useQueryClient();
  const { data: categories, isLoading } = useQuery({ queryKey: ["categories"], queryFn: api.categories.list });
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["categories"] });

  const createMutation = useMutation({ mutationFn: api.categories.create, onSuccess: () => { invalidate(); resetForm(); } });
  const updateMutation = useMutation({ mutationFn: api.categories.update, onSuccess: () => { invalidate(); resetForm(); } });
  const deleteMutation = useMutation({ mutationFn: api.categories.delete, onSuccess: invalidate });

  const resetForm = () => { setForm({ name: "", icon: "wallet", color: "#6366f1", type: "expense" }); setEditingId(null); setDialogOpen(false); };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name) return;
    if (editingId) updateMutation.mutate({ id: editingId, name: form.name, icon: form.icon, color: form.color });
    else createMutation.mutate({ name: form.name, icon: form.icon, color: form.color, type: form.type as "expense" | "income" | "bill" | "emi" | "loan" });
  };

  const handleEdit = (cat: Category) => {
    setEditingId(cat.id);
    setForm({ name: cat.name, icon: cat.icon, color: cat.color, type: cat.type });
    setDialogOpen(true);
  };

  const renderCategoryCard = (cat: Category) => {
    const IconComponent = iconMap[cat.icon] || Wallet;
    return (
      <Card key={cat.id} className={`${cat.isDefault ? "border-dashed" : ""}`}>
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white" style={{ backgroundColor: cat.color }}>
                <IconComponent className="w-5 h-5" />
              </div>
              <div>
                <p className="font-medium text-sm">{cat.name}</p>
                <span className={`text-[10px] px-1.5 py-0.5 rounded ${typeColors[cat.type] || "bg-gray-100"}`}>{cat.type}</span>
                {cat.isDefault && <span className="text-[10px] text-muted-foreground ml-1">default</span>}
              </div>
            </div>
            {!cat.isDefault && (
              <div className="flex gap-1">
                <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleEdit(cat)}><Pencil className="w-3.5 h-3.5" /></Button>
                <Button variant="ghost" size="icon" className="h-7 w-7 text-red-500" onClick={() => deleteMutation.mutate(cat.id)}><Trash2 className="w-3.5 h-3.5" /></Button>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    );
  };

  const expenseCats = categories?.filter((c) => c.type === "expense") ?? [];
  const billCats = categories?.filter((c) => c.type === "bill") ?? [];
  const emiCats = categories?.filter((c) => c.type === "emi") ?? [];
  const incomeCats = categories?.filter((c) => c.type === "income") ?? [];

  return (
    <div className="flex-1 overflow-y-auto pr-1 -mr-1">
      <div className="space-y-6 pb-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Categories</h2>
            <p className="text-muted-foreground">Manage expense, bill, and income categories</p>
          </div>
          <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" onClick={() => { resetForm(); setDialogOpen(true); }}><Plus className="w-4 h-4 mr-1" /> Add Category</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>{editingId ? "Edit Category" : "Add Category"}</DialogTitle></DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div><Label>Name</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Category name" /></div>
                {!editingId && (
                  <div><Label>Type</Label>
                    <Select value={form.type} onValueChange={(v) => setForm({ ...form, type: v })}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="expense">Expense</SelectItem>
                        <SelectItem value="bill">Bill</SelectItem>
                        <SelectItem value="emi">EMI</SelectItem>
                        <SelectItem value="income">Income</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                )}
                <div><Label>Icon Name</Label><Input value={form.icon} onChange={(e) => setForm({ ...form, icon: e.target.value })} placeholder="e.g., shopping-cart" /></div>
                <div><Label>Color</Label><div className="flex items-center gap-2"><Input type="color" value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} className="w-16 h-10" /><span className="text-sm text-muted-foreground">{form.color}</span></div></div>
                <DialogFooter>
                  <Button type="button" variant="outline" onClick={resetForm}>Cancel</Button>
                  <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending}>{editingId ? "Update" : "Add"}</Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        {isLoading ? <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{[...Array(6)].map((_, i) => <Skeleton key={i} className="h-20" />)}</div> : (
          <Tabs defaultValue="expense">
            <TabsList className="mb-4">
              <TabsTrigger value="expense">Expenses ({expenseCats.length})</TabsTrigger>
              <TabsTrigger value="bill">Bills ({billCats.length})</TabsTrigger>
              <TabsTrigger value="emi">EMIs ({emiCats.length})</TabsTrigger>
              <TabsTrigger value="income">Income ({incomeCats.length})</TabsTrigger>
            </TabsList>
            <TabsContent value="expense"><div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{expenseCats.map(renderCategoryCard)}</div></TabsContent>
            <TabsContent value="bill"><div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{billCats.map(renderCategoryCard)}</div></TabsContent>
            <TabsContent value="emi"><div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{emiCats.map(renderCategoryCard)}</div></TabsContent>
            <TabsContent value="income"><div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{incomeCats.map(renderCategoryCard)}</div></TabsContent>
          </Tabs>
        )}
      </div>
    </div>
  );
}
