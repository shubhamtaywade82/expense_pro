import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../lib/api";
import type { DocumentChecklist, TaxDocumentRow } from "../types";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Badge } from "../components/ui/badge";
import { Progress } from "../components/ui/progress";
import {
  Upload,
  FileText,
  Camera,
  CheckCircle2,
  AlertTriangle,
  Eye,
  Trash2,
  Lock,
  FileCheck2,
  RefreshCw,
} from "lucide-react";

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  uploaded: { label: "Uploaded", color: "bg-slate-100 text-slate-700 border-slate-300" },
  decrypting: { label: "Decrypting…", color: "bg-blue-100 text-blue-700 border-blue-300" },
  processing: { label: "Reading (OCR)…", color: "bg-blue-100 text-blue-700 border-blue-300" },
  extracted: { label: "Review needed", color: "bg-amber-100 text-amber-700 border-amber-300" },
  verified: { label: "✓ Verified", color: "bg-green-100 text-green-700 border-green-300" },
  mismatch: { label: "⚠ Review / Mismatch", color: "bg-amber-100 text-amber-800 border-amber-300" },
  failed: { label: "⚠ Uploaded (Unverified)", color: "bg-orange-100 text-orange-800 border-orange-300" },
  pending_verification: { label: "Uploaded", color: "bg-blue-100 text-blue-800 border-blue-300" },
  missing: { label: "Missing", color: "bg-slate-100 text-slate-500 border-slate-200" },
};

const getPreviewUrl = (url?: string) => {
  if (!url) return "#";
  const token = localStorage.getItem("jwt");
  if (!token) return url;
  const separator = url.includes("?") ? "&" : "?";
  return `${url}${separator}token=${encodeURIComponent(token)}`;
};

export default function TaxDocuments() {
  const [fy, setFy] = useState(2025);
  const [dragOver, setDragOver] = useState<string | null>(null);
  const fileInputs = useRef<Record<string, HTMLInputElement | null>>({});
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["tax-documents", fy],
    queryFn: () =>
      api.get<{ documents: TaxDocumentRow[]; checklist: DocumentChecklist }>(
        `/tax_documents?financial_year=${fy}`
      ),
  });

  const uploadMutation = useMutation({
    mutationFn: ({ docType, files }: { docType: string; files: File[] }) => {
      const formData = new FormData();
      formData.append("document_type", docType);
      formData.append("financial_year", String(fy));
      files.forEach((f) => formData.append("files[]", f));
      return api.post("/tax_documents", formData);
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["tax-documents"] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => api.delete(`/tax_documents/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["tax-documents"] }),
  });

  const verifyMutation = useMutation({
    mutationFn: ({ id, extracted }: { id: number; extracted?: any }) =>
      api.patch(`/tax_documents/${id}/verify`, { extracted_data: extracted }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["tax-documents"] }),
  });

  const documents: TaxDocumentRow[] = data?.documents || [];
  const checklist = data?.checklist || {
    completion_pct: 0,
    checklist: [],
  };

  const getUploadedDoc = (docType: string) =>
    documents.find((d) => d.document_type === docType);

  return (
    <div className="space-y-6 pb-8">
      {/* Header with completion bar */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Tax Document Vault</h1>
          <p className="text-muted-foreground text-sm">
            FY {fy}-{String(fy + 1).slice(2)} · Encrypted and stored safely for ITR filing
          </p>
        </div>
        {checklist && (
          <div className="flex items-center gap-3">
            <Progress value={checklist.completion_pct} className="w-32" />
            <span className="text-sm font-medium">{checklist.completion_pct}% ready</span>
          </div>
        )}
      </div>

      {/* Auto-decrypt notice */}
      <Card className="border-blue-200 bg-blue-50/50">
        <CardContent className="pt-4 flex items-start gap-3">
          <Lock className="h-5 w-5 text-blue-600 mt-0.5 shrink-0" />
          <p className="text-xs md:text-sm text-blue-800">
            <strong>Form 26AS, AIS, and Bank Statements</strong> are password-protected PDFs. We auto-decrypt TRACES & IT portal files using your PAN + DOB.
          </p>
        </CardContent>
      </Card>

      {/* Upload zones grouped by checklist */}
      <div className="grid gap-4 md:grid-cols-2">
        {checklist?.checklist.map((item: any) => {
          const uploadedDoc = getUploadedDoc(item.document_type);
          const isUploaded = !!uploadedDoc;
          const statusKey = uploadedDoc ? uploadedDoc.status : item.status;
          const statusObj = STATUS_CONFIG[statusKey] || STATUS_CONFIG.uploaded;

          return (
            <div
              key={item.document_type}
              onDragOver={(e) => {
                e.preventDefault();
                setDragOver(item.document_type);
              }}
              onDragLeave={() => setDragOver(null)}
              onDrop={(e) => {
                e.preventDefault();
                setDragOver(null);
                uploadMutation.mutate({
                  docType: item.document_type,
                  files: Array.from(e.dataTransfer.files),
                });
              }}
              className={`border-2 border-dashed rounded-lg p-4 transition-all relative ${
                dragOver === item.document_type
                  ? "border-primary bg-primary/5 scale-[1.01]"
                  : isUploaded
                  ? "border-green-300 bg-green-50/20"
                  : item.status === "missing" && item.mandatory
                  ? "border-red-200 bg-red-50/10"
                  : "border-muted-foreground/20"
              }`}
            >
              <input
                ref={(el) => {
                  fileInputs.current[item.document_type] = el;
                }}
                type="file"
                multiple
                accept=".pdf,.jpg,.jpeg,.png"
                className="hidden"
                onChange={(e) => {
                  if (e.target.files?.length) {
                    uploadMutation.mutate({
                      docType: item.document_type,
                      files: Array.from(e.target.files),
                    });
                  }
                }}
              />

              <div className="flex items-start justify-between">
                <div className="flex items-start gap-3">
                  <div
                    className={`p-2.5 rounded-lg ${
                      isUploaded ? "bg-green-100 text-green-700" : "bg-muted text-muted-foreground"
                    }`}
                  >
                    {isUploaded ? <FileCheck2 className="h-6 w-6" /> : <FileText className="h-6 w-6" />}
                  </div>
                  <div>
                    <p className="font-semibold text-sm flex items-center gap-2">
                      {item.label}
                      {item.mandatory && <Badge variant="destructive" className="text-[10px] h-4">Required</Badge>}
                    </p>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge variant="outline" className={`text-[11px] ${statusObj.color}`}>
                        {statusObj.label}
                      </Badge>
                      {uploadedDoc && (
                        <span className="text-xs text-muted-foreground font-mono">
                          {uploadedDoc.display_name || "Uploaded"} ({uploadedDoc.size_kb} KB)
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-1.5">
                  {uploadedDoc ? (
                    <Button
                      size="sm"
                      variant="outline"
                      className="h-8 text-xs gap-1"
                      onClick={() => fileInputs.current[item.document_type]?.click()}
                    >
                      <RefreshCw className="h-3.5 w-3.5" /> Replace
                    </Button>
                  ) : (
                    <Button
                      size="sm"
                      variant="outline"
                      className="h-8 text-xs gap-1"
                      onClick={() => fileInputs.current[item.document_type]?.click()}
                    >
                      <Upload className="h-3.5 w-3.5" /> Upload
                    </Button>
                  )}
                </div>
              </div>

              {item.tip && <p className="text-xs text-muted-foreground mt-2.5 pl-11">{item.tip}</p>}
            </div>
          );
        })}
      </div>

      {/* Uploaded Documents List */}
      {documents.length > 0 && (
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <FileCheck2 className="h-5 w-5 text-emerald-600" />
              Uploaded Files in Vault ({documents.length})
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {documents.map((doc) => {
              const statusObj = STATUS_CONFIG[doc.status] || STATUS_CONFIG.uploaded;
              return (
                <div
                  key={doc.id}
                  className="flex items-center justify-between p-3 rounded-lg border bg-card text-sm"
                >
                  <div className="flex items-center gap-3">
                    <FileText className="h-5 w-5 text-indigo-500 shrink-0" />
                    <div>
                      <p className="font-medium text-xs md:text-sm">
                        {doc.display_name || doc.document_type.replace(/_/g, " ").toUpperCase()}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {doc.document_type.replace(/_/g, " ")} · {doc.size_kb} KB · FY {doc.financial_year}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <Badge variant="outline" className={`text-xs ${statusObj.color}`}>
                      {statusObj.label}
                    </Badge>
                    {doc.preview_url && (
                      <Button
                        size="sm"
                        variant="ghost"
                        className="h-8 w-8 p-0"
                        asChild
                      >
                        <a href={getPreviewUrl(doc.preview_url)} target="_blank" rel="noreferrer">
                          <Eye className="h-4 w-4" />
                        </a>
                      </Button>
                    )}
                    {doc.status !== "verified" && (
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-8 text-xs text-green-700 hover:text-green-800"
                        onClick={() => verifyMutation.mutate({ id: doc.id })}
                      >
                        <CheckCircle2 className="h-3.5 w-3.5 mr-1" /> Verify
                      </Button>
                    )}
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-8 w-8 p-0 text-red-500 hover:text-red-600"
                      onClick={() => deleteMutation.mutate(doc.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              );
            })}
          </CardContent>
        </Card>
      )}

      {/* Extracted Data Confirmation */}
      <ExtractedDataReview
        fy={fy}
        onVerify={(id, data) => verifyMutation.mutate({ id, extracted: data })}
      />
    </div>
  );
}

function ExtractedDataReview({
  fy,
  onVerify,
}: {
  fy: number;
  onVerify: (id: number, data?: any) => void;
}) {
  const { data } = useQuery({
    queryKey: ["tax-documents", fy],
    queryFn: () =>
      api.get<{ documents: TaxDocumentRow[]; checklist: DocumentChecklist }>(
        `/tax_documents?financial_year=${fy}`
      ),
  });

  const actionable = (data?.documents || []).filter((d: any) =>
    ["extracted", "mismatch"].includes(d.status)
  );

  if (!actionable.length) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <AlertTriangle className="h-5 w-5 text-amber-500" />
          Review Extracted Data ({actionable.length})
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {actionable.map((doc: any) => (
          <div key={doc.id} className="border rounded-lg p-4">
            <div className="flex justify-between items-start mb-3">
              <p className="font-medium text-sm">{doc.document_type.replace(/_/g, " ")}</p>
              <Badge className={STATUS_CONFIG[doc.status]?.color || ""}>
                {STATUS_CONFIG[doc.status]?.label || doc.status}
              </Badge>
            </div>
            <div className="grid grid-cols-2 gap-2 text-xs mb-3">
              {Object.entries(doc.extracted_data || {})
                .filter(([_, v]) => typeof v === "number" || typeof v === "string")
                .slice(0, 8)
                .map(([key, value]) => (
                  <div key={key} className="flex justify-between border-b pb-1">
                    <span className="text-muted-foreground">{key.replace(/_/g, " ")}</span>
                    <span className="font-mono">{String(value)}</span>
                  </div>
                ))}
            </div>
            <div className="flex gap-2">
              <Button size="sm" onClick={() => onVerify(doc.id)}>
                <CheckCircle2 className="h-4 w-4 mr-1" /> Looks Correct
              </Button>
              {doc.preview_url && (
                <Button size="sm" variant="outline" asChild>
                  <a href={getPreviewUrl(doc.preview_url)} target="_blank" rel="noreferrer">
                    <Eye className="h-4 w-4 mr-1" /> View Original
                  </a>
                </Button>
              )}
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
