import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import { toast } from "sonner";
import { HandCoins, FileSignature, BadgeCheck, Copy, Download, ScrollText, AlertOctagon } from "lucide-react";

const fmt = (val: number) => `₹${val.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

export function CaseDetailDialog({
  caseId,
  open,
  onOpenChange,
}: {
  caseId: number | null;
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const queryClient = useQueryClient();
  const [offerPct, setOfferPct] = useState("30");
  const [contribution, setContribution] = useState("");
  const [otsOfferAmount, setOtsOfferAmount] = useState("");

  const { data: c } = useQuery({
    queryKey: ["debt-clearance", "case", caseId],
    queryFn: () => api.debtClearance.settlementCases.show(caseId!),
    enabled: open && caseId != null,
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["debt-clearance"] });
  };

  const addOffer = useMutation({
    mutationFn: () =>
      api.debtClearance.offers.create(caseId!, {
        claimAmount: c!.currentClaim,
        settlementPercentage: Number(offerPct),
      }),
    onSuccess: () => { toast.success("Offer recorded with fee/GST breakdown"); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  const acceptOffer = useMutation({
    mutationFn: (offerId: number) => api.debtClearance.offers.accept(caseId!, offerId),
    onSuccess: () => { toast.success("Offer accepted"); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  const addContribution = useMutation({
    mutationFn: () =>
      api.debtClearance.contributions.create(caseId!, { amount: Number(contribution.replace(/[^0-9.]/g, "")) }),
    onSuccess: () => { toast.success("Contribution saved to settlement fund"); setContribution(""); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  const recordPayment = useMutation({
    mutationFn: (offerId?: number) =>
      api.debtClearance.settlementCases.recordPayment(caseId!, { settlementOfferId: offerId }),
    onSuccess: () => { toast.success("Settlement payment recorded — account closed"); invalidate(); },
    onError: (e: Error) => toast.error(e.message),
  });

  if (!c) return null;

  const defaultProposedOts = Math.round(c.currentClaim * 0.40);
  const currentProposedOts = otsOfferAmount ? Number(otsOfferAmount.replace(/[^0-9.]/g, "")) : defaultProposedOts;
  const isSuitFiled = c.debtAccount.formalNotice || (c.debtAccount.bureauStatus?.includes("SUIT") ?? false);

  const generateLetterText = () => {
    return `FORMAL PROPOSAL FOR ONE-TIME SETTLEMENT (OTS)${isSuitFiled ? " & UNCONDITIONAL WITHDRAWAL OF LEGAL PROCEEDINGS" : ""}

Date: ${new Date().toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric" })}
Mode: Registered Post with A/D & Email

To:
The Authorized Officer / Legal & Recovery Department,
${c.debtAccount.lender || "Lender / Institution"},
[Branch / Operations Office Address]

Subject: Proposal for Full and Final One-Time Settlement (OTS) regarding Account: ${c.debtAccount.name}

Borrower Name: Shubham Taywade
Email: shubhamtaywade82@gmail.com
Account Reference: ${c.debtAccount.name}
Total Claim / Outstanding: ₹${c.currentClaim.toLocaleString("en-IN")}
Proposed One-Time Settlement (OTS): ₹${currentProposedOts.toLocaleString("en-IN")}

Dear Sir / Madam,

I write regarding the referenced account. Due to unforeseen financial distress and compounding cash-flow challenges, regular debt servicing was unintentionally interrupted. I am eager to resolve all liabilities amicably without litigation delay.

I hereby submit a formal offer of ₹${currentProposedOts.toLocaleString("en-IN")} (~${Math.round((currentProposedOts / c.currentClaim) * 100)}% of the claim) as Full and Final Settlement of this account, strictly subject to the following non-negotiable conditions:

1. Official OTS Sanction Letter: An approval letter issued on official corporate letterhead confirming ₹${currentProposedOts.toLocaleString("en-IN")} as full and final discharge with waiver of all interest and penalties.
${isSuitFiled ? "2. Unconditional Court Suit Withdrawal: Akara Capital / Lender counsel shall unconditionally withdraw/compound the suit/proceedings pending before the Court within 15 working days of payment receipt and furnish a certified copy of the withdrawal order to the borrower.\n" : ""}3. No Dues Certificate (NDC): Delivery of an unconditional No Dues Certificate within 15 working days of payment receipt.
4. Credit Bureau Reporting: Status update with CRIF High Mark, CIBIL, Equifax, and Experian reflecting "Settled" with ₹0 current balance within 30 days.

Upon receipt of the signed OTS Approval Letter, I am prepared to remit payment within 48 to 72 hours.

Yours faithfully,
Shubham Taywade
shubhamtaywade82@gmail.com`;
  };

  const copyLetter = () => {
    navigator.clipboard.writeText(generateLetterText());
    toast.success("OTS Settlement letter copied to clipboard!");
  };

  const downloadLetter = () => {
    const text = generateLetterText();
    const blob = new Blob([text], { type: "text/markdown;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `OTS_Settlement_Letter_${c.debtAccount.name.replace(/[^a-zA-Z0-9]/g, "_")}.md`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[88vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {c.debtAccount.name}
            <Badge variant="outline">{c.status.replace(/_/g, " ")}</Badge>
            {isSuitFiled && (
              <Badge className="bg-red-600 text-white font-bold flex items-center gap-1">
                <AlertOctagon className="w-3.5 h-3.5" /> SUIT FILED
              </Badge>
            )}
          </DialogTitle>
          <DialogDescription>
            {c.debtAccount.lender} · claim {fmt(c.currentClaim)} · target range {c.targetMinPercentage}–{c.targetMaxPercentage}%
            {c.serviceFeePercentage > 0 ? ` · fee ${c.serviceFeePercentage}% · GST ${c.gstPercentage}%` : " · Direct OTS (No Agency Fees)"}
          </DialogDescription>
        </DialogHeader>

        <Tabs defaultValue="negotiation" className="space-y-4">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="negotiation">Negotiation & Funding</TabsTrigger>
            <TabsTrigger value="letter" className="flex items-center gap-1.5">
              <ScrollText className="w-4 h-4" /> OTS Settlement Letter
            </TabsTrigger>
          </TabsList>

          {/* Tab 1: Negotiation & Funding */}
          <TabsContent value="negotiation" className="space-y-4">
            {/* Fund state */}
            <div className="space-y-2 p-3 bg-muted/40 rounded-lg">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Settlement fund: <strong className="text-foreground">{fmt(c.settlementFund)}</strong> of est. {fmt(c.estimatedTotal)}</span>
                <span className="font-mono">{c.fundingProgress}% {c.eligible && "· eligible"}</span>
              </div>
              <Progress value={c.fundingProgress} className="h-2.5" />
              <div className="flex gap-2 pt-1">
                <Input
                  value={contribution}
                  onChange={(e) => setContribution(e.target.value)}
                  placeholder="Add to settlement fund (₹)"
                  inputMode="numeric"
                  className="flex-1"
                />
                <Button variant="outline" disabled={!contribution || addContribution.isPending} onClick={() => addContribution.mutate()}>
                  <HandCoins className="w-4 h-4 mr-1" /> Save
                </Button>
              </div>
            </div>

            {/* Scenario ladder */}
            <div>
              <h4 className="text-sm font-semibold mb-2 flex items-center gap-2">
                <FileSignature className="w-4 h-4 text-primary" /> Scenario ladder (what each level really costs)
              </h4>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Settlement</TableHead>
                    <TableHead className="text-right">Amount</TableHead>
                    <TableHead className="text-right">Fee</TableHead>
                    <TableHead className="text-right">GST</TableHead>
                    <TableHead className="text-right">Total</TableHead>
                    <TableHead></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {(c.scenarioTable ?? []).map((row) => (
                    <TableRow key={row.settlementPercentage}>
                      <TableCell className="font-medium">{row.settlementPercentage}%</TableCell>
                      <TableCell className="text-right font-mono">{fmt(row.settlementAmount)}</TableCell>
                      <TableCell className="text-right font-mono">{fmt(row.serviceFee)}</TableCell>
                      <TableCell className="text-right font-mono">{fmt(row.gst)}</TableCell>
                      <TableCell className="text-right font-mono font-semibold">{fmt(row.total)}</TableCell>
                      <TableCell className="text-right">
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => { setOfferPct(String(row.settlementPercentage)); addOffer.mutate(); }}
                        >
                          Record offer
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {/* Offers */}
            {(c.offers ?? []).length > 0 && (
              <div>
                <h4 className="text-sm font-semibold mb-2">Offers on the table</h4>
                <div className="space-y-2">
                  {c.offers!.map((o) => (
                    <div key={o.id} className="flex items-center gap-3 rounded-lg border p-3 text-sm">
                      <BadgeCheck className={`w-5 h-5 ${o.status === "accepted" ? "text-emerald-600" : "text-muted-foreground"}`} />
                      <div className="flex-1">
                        <span className="font-medium">{o.settlementPercentage}%</span> · {fmt(o.settlementAmount)} + fee {fmt(o.serviceFee)} + GST {fmt(o.gst)} = <strong>{fmt(o.totalAmount)}</strong>
                        <div className="text-xs text-muted-foreground">
                          {o.status} · {o.offeredOn}{o.validUntil ? ` · valid until ${o.validUntil}` : ""}
                        </div>
                      </div>
                      {o.status !== "accepted" && (
                        <div className="flex gap-2">
                          <Button size="sm" variant="outline" onClick={() => acceptOffer.mutate(o.id)}>Accept</Button>
                          <Button
                            size="sm"
                            variant="default"
                            disabled={recordPayment.isPending}
                            onClick={() => recordPayment.mutate(o.id)}
                          >
                            Pay &amp; close
                          </Button>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="flex justify-end gap-2 border-t pt-3">
              <Button
                variant="destructive"
                size="sm"
                disabled={recordPayment.isPending}
                onClick={() => recordPayment.mutate(undefined)}
              >
                Record settlement payment (worst case {fmt(c.estimatedTotal)})
              </Button>
            </div>
          </TabsContent>

          {/* Tab 2: OTS Legal Letter */}
          <TabsContent value="letter" className="space-y-4">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 bg-muted/40 p-3 rounded-lg">
              <div className="space-y-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Proposed OTS Offer</span>
                <div className="flex items-center gap-2">
                  <Input
                    className="w-36 h-8 font-mono font-bold"
                    value={otsOfferAmount || String(defaultProposedOts)}
                    onChange={(e) => setOtsOfferAmount(e.target.value)}
                    placeholder="Offer ₹"
                  />
                  <span className="text-xs text-muted-foreground">
                    ({Math.round((currentProposedOts / c.currentClaim) * 100)}% of claim)
                  </span>
                </div>
              </div>
              <div className="flex gap-2">
                <Button size="sm" variant="outline" onClick={copyLetter} className="gap-1">
                  <Copy className="w-3.5 h-3.5" /> Copy Letter
                </Button>
                <Button size="sm" variant="secondary" onClick={downloadLetter} className="gap-1">
                  <Download className="w-3.5 h-3.5" /> Download .md
                </Button>
              </div>
            </div>

            <div className="p-4 bg-muted/20 border rounded-lg font-mono text-xs whitespace-pre-wrap max-h-[350px] overflow-y-auto leading-relaxed">
              {generateLetterText()}
            </div>
          </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
