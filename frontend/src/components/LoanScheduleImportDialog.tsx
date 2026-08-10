import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { FileSpreadsheet, UploadCloud } from "lucide-react";

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onImport: (rows: any[]) => void;
  isPending: boolean;
};

export function LoanScheduleImportDialog({ open, onOpenChange, onImport, isPending }: Props) {
  const [rawText, setRawText] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleParseAndImport = () => {
    setError(null);
    if (!rawText.trim()) {
      setError("Please paste schedule data or CSV text.");
      return;
    }

    try {
      const lines = rawText.trim().split(/\r?\n/).filter((l) => l.trim().length > 0);
      const rows: any[] = [];

      lines.forEach((line, idx) => {
        // Skip header if line contains words like "Installment" or "EMI" or "Principal"
        if (idx === 0 && (line.toLowerCase().includes("installment") || line.toLowerCase().includes("emi") || line.toLowerCase().includes("date"))) {
          return;
        }

        const cols = line.split(/[,\t|]/).map((c) => c.trim().replace(/[₹,\s]/g, ""));
        if (cols.length >= 3) {
          // Flexible parser:
          // Format 1: [installment_no, due_date, emi_amount, principal, interest, closing_balance, status]
          // Format 2: [due_date, emi_amount, principal, interest]
          const isFirstColNum = !isNaN(Number(cols[0])) && Number(cols[0]) > 0 && Number(cols[0]) < 1000;
          const instNum = isFirstColNum ? Number(cols[0]) : idx + 1;
          const dateStr = isFirstColNum ? cols[1] : cols[0];
          const emi = isFirstColNum ? parseFloat(cols[2]) : parseFloat(cols[1]);
          const principal = isFirstColNum && cols[3] ? parseFloat(cols[3]) : 0;
          const interest = isFirstColNum && cols[4] ? parseFloat(cols[4]) : 0;
          const closing = isFirstColNum && cols[5] ? parseFloat(cols[5]) : 0;
          const status = cols.some((c) => c.toLowerCase() === "paid") ? "paid" : "pending";

          rows.push({
            installmentNumber: instNum,
            dueDate: dateStr,
            emiAmount: emi,
            principalComponent: principal,
            interestComponent: interest,
            closingBalance: closing,
            status,
          });
        }
      });

      if (rows.length === 0) {
        setError("Could not parse any valid rows. Please check format: Installment#, DueDate, EMI, Principal, Interest");
        return;
      }

      onImport(rows);
    } catch (e: any) {
      setError(e.message || "Failed to parse schedule data.");
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <FileSpreadsheet className="w-5 h-5 text-emerald-500" />
            Import Repayment Schedule (CSV / Paste)
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div>
            <Label className="text-xs font-semibold">Paste Table / CSV Rows from Bank Statement</Label>
            <p className="text-xs text-muted-foreground mb-2">
              Copy & paste the table columns directly from Tata Capital / Excel (Installment #, Due Date, EMI Amount, Principal, Interest, Balance).
            </p>
            <Textarea
              rows={8}
              value={rawText}
              onChange={(e) => setRawText(e.target.value)}
              placeholder={"1\t2023-03-28\t43500\t9500\t34000\t4590500\tPaid\n2\t2023-04-28\t43500\t9600\t33900\t4580900\tPaid"}
              className="font-mono text-xs"
            />
          </div>

          {error && <p className="text-xs text-red-600 bg-red-50 p-2 rounded">{error}</p>}
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button type="button" onClick={handleParseAndImport} disabled={isPending}>
            <UploadCloud className="w-4 h-4 mr-1.5" />
            {isPending ? "Importing..." : "Import Schedule"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
