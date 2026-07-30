import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Employment } from "@/types";
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
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Plus,
  Pencil,
  Trash2,
  Briefcase,
  Calendar,
  IndianRupee,
  Building2,
} from "lucide-react";

export default function EmploymentSection() {
  const queryClient = useQueryClient();

  const { data: employments, isLoading } = useQuery({
    queryKey: ["employments"],
    queryFn: () => api.employments.list(),
  });

  const createMutation = useMutation({
    mutationFn: (data: Record<string, unknown>) => api.employments.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["employments"] });
      setDialogOpen(false);
      resetForm();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, ...data }: Record<string, unknown>) =>
      api.employments.update(id as number, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["employments"] });
      setDialogOpen(false);
      resetForm();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => api.employments.delete(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["employments"] }),
  });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState({
    employerName: "",
    designation: "",
    startDate: "",
    endDate: "",
    isCurrent: true,
    monthlyCtc: "",
    panOfEmployer: "",
  });

  const resetForm = () => {
    setForm({
      employerName: "",
      designation: "",
      startDate: "",
      endDate: "",
      isCurrent: true,
      monthlyCtc: "",
      panOfEmployer: "",
    });
    setEditingId(null);
  };

  const handleEdit = (emp: Employment) => {
    setEditingId(emp.id);
    setForm({
      employerName: emp.employerName,
      designation: emp.designation || "",
      startDate: emp.startDate,
      endDate: emp.endDate || "",
      isCurrent: emp.isCurrent,
      monthlyCtc: emp.monthlyCtc || "",
      panOfEmployer: emp.panOfEmployer || "",
    });
    setDialogOpen(true);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.employerName || !form.startDate) return;

    const payload = {
      employer_name: form.employerName,
      designation: form.designation || undefined,
      start_date: form.startDate,
      end_date: form.isCurrent ? null : form.endDate || undefined,
      is_current: form.isCurrent,
      monthly_ctc: form.monthlyCtc || undefined,
      pan_of_employer: form.panOfEmployer || undefined,
    };

    if (editingId) updateMutation.mutate({ id: editingId, ...payload });
    else createMutation.mutate(payload);
  };

  return (
    <div className="mt-8 space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Briefcase className="w-5 h-5 text-purple-500" />
          <h2 className="text-lg font-semibold">Employment History</h2>
        </div>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger asChild>
            <Button size="sm" onClick={() => resetForm()}>
              <Plus className="w-4 h-4 mr-1" /> Add Employment
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>{editingId ? "Edit Employment" : "Add Employment"}</DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <Label>Employer Name</Label>
                <Input
                  className="mt-1"
                  value={form.employerName}
                  onChange={(e) => setForm({ ...form, employerName: e.target.value })}
                  required
                />
              </div>
              <div>
                <Label>Designation</Label>
                <Input
                  className="mt-1"
                  value={form.designation}
                  onChange={(e) => setForm({ ...form, designation: e.target.value })}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <Label>Start Date</Label>
                  <Input
                    type="date" className="mt-1"
                    value={form.startDate}
                    onChange={(e) => setForm({ ...form, startDate: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label>End Date</Label>
                  <Input
                    type="date" className="mt-1"
                    value={form.endDate}
                    onChange={(e) => setForm({ ...form, endDate: e.target.value })}
                    disabled={form.isCurrent}
                  />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Switch
                  checked={form.isCurrent}
                  onCheckedChange={(v) => {
                    setForm({ ...form, isCurrent: v, endDate: v ? "" : form.endDate });
                  }}
                />
                <Label className="text-sm">Currently employed here</Label>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <Label>Monthly CTC (₹)</Label>
                  <Input
                    type="number" step="0.01" className="mt-1"
                    value={form.monthlyCtc}
                    onChange={(e) => setForm({ ...form, monthlyCtc: e.target.value })}
                  />
                </div>
                <div>
                  <Label>PAN of Employer</Label>
                  <Input
                    className="mt-1 uppercase"
                    maxLength={10}
                    value={form.panOfEmployer}
                    onChange={(e) => setForm({ ...form, panOfEmployer: e.target.value })}
                    placeholder="Optional"
                  />
                </div>
              </div>
              <DialogFooter>
                <Button type="submit">{editingId ? "Update" : "Add"}</Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {isLoading ? (
        <div className="space-y-2">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : !employments?.length ? (
        <Card>
          <CardContent className="py-8 text-center text-muted-foreground">
            <Building2 className="w-8 h-8 mx-auto mb-2 opacity-40" />
            <p className="text-sm">No employments added yet</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-2">
          {employments.map((emp) => (
            <Card key={emp.id} className={emp.isCurrent ? "border-purple-500/30" : ""}>
              <CardContent className="py-4">
                <div className="flex items-start justify-between">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold">{emp.employerName}</span>
                      {emp.isCurrent && (
                        <Badge className="text-[10px] h-5 bg-emerald-500/10 text-emerald-600 border-emerald-500/20">
                          Current
                        </Badge>
                      )}
                    </div>
                    {emp.designation && (
                      <p className="text-sm text-muted-foreground">{emp.designation}</p>
                    )}
                    <div className="flex items-center gap-3 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        {emp.startDate} — {emp.endDate || "Present"}
                      </span>
                      {emp.monthlyCtc && (
                        <span className="flex items-center gap-1">
                          <IndianRupee className="w-3 h-3" />
                          CTC: ₹{Number(emp.monthlyCtc).toLocaleString("en-IN")}/mo
                        </span>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-1">
                    <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={() => handleEdit(emp)}>
                      <Pencil className="w-4 h-4" />
                    </Button>
                    <Button
                      variant="ghost" size="sm" className="h-8 w-8 p-0 text-rose-500"
                      onClick={() => deleteMutation.mutate(emp.id)}
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
