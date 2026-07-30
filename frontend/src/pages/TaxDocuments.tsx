import { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Progress } from '../components/ui/progress';
import {
  Upload, FileText, Camera, CheckCircle2, AlertTriangle,
  Loader2, Eye, X, ShieldCheck, FileJson, Lock
} from 'lucide-react';

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  uploaded:    { label: 'Uploaded',        color: 'bg-slate-100 text-slate-700' },
  decrypting:  { label: 'Decrypting…',     color: 'bg-blue-100 text-blue-700' },
  processing:  { label: 'Reading (OCR)…',  color: 'bg-blue-100 text-blue-700' },
  extracted:   { label: 'Review needed',   color: 'bg-amber-100 text-amber-700' },
  verified:    { label: '✓ Verified',      color: 'bg-green-100 text-green-700' },
  mismatch:    { label: '⚠ Mismatch',      color: 'bg-red-100 text-red-700' },
  failed:      { label: '✗ Failed',        color: 'bg-red-100 text-red-700' },
};

export default function TaxDocuments() {
  const [fy, setFy] = useState(2025);
  const [dragOver, setDragOver] = useState<string | null>(null);
  const fileInputs = useRef<Record<string, HTMLInputElement | null>>({});
  const queryClient = useQueryClient();

  const { data } = useQuery({
    queryKey: ['tax-documents', fy],
    queryFn: () => api.get(`/tax_documents?financial_year=${fy}`).then(res => res.data),
  });

  const uploadMutation = useMutation({
    mutationFn: ({ docType, files }: { docType: string; files: File[] }) => {
      const formData = new FormData();
      formData.append('document_type', docType);
      formData.append('financial_year', String(fy));
      files.forEach(f => formData.append('files[]', f));
      // Using axios post for multipart/form-data
      return api.post('/tax_documents', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['tax-documents'] }),
  });

  // Mocking checklist since we don't have the checklist service yet
  const checklist = data?.checklist || {
    completion_pct: 0,
    checklist: [
      { document_type: 'pan_card', label: 'PAN Card', status: 'missing', mandatory: true },
      { document_type: 'form_26as', label: 'Form 26AS', status: 'missing', mandatory: true, tip: 'Download from TRACES.' }
    ]
  };

  return (
    <div className="space-y-6">
      {/* Header with completion ring */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Tax Document Vault</h1>
          <p className="text-muted-foreground">
            FY {fy}-{String(fy + 1).slice(2)} · Everything encrypted at rest
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
          <Lock className="h-5 w-5 text-blue-600 mt-0.5" />
          <p className="text-sm text-blue-800">
            <strong>Form 26AS & AIS are password-protected PDFs — don't worry.</strong>{' '}
            We decrypt them automatically using your PAN + date of birth. Just upload as-is.
          </p>
        </CardContent>
      </Card>

      {/* Upload zones grouped by checklist */}
      <div className="grid gap-4 md:grid-cols-2">
        {checklist?.checklist.map((item: any) => (
          <div
            key={item.document_type}
            onDragOver={e => { e.preventDefault(); setDragOver(item.document_type); }}
            onDragLeave={() => setDragOver(null)}
            onDrop={e => {
              e.preventDefault();
              setDragOver(null);
              uploadMutation.mutate({
                docType: item.document_type,
                files: Array.from(e.dataTransfer.files),
              });
            }}
            className={`border-2 border-dashed rounded-lg p-4 transition-all cursor-pointer
              ${dragOver === item.document_type ? 'border-primary bg-primary/5 scale-[1.01]' : 'border-muted-foreground/20'}
              ${item.status === 'verified' ? 'border-green-300 bg-green-50/30' : ''}
              ${item.status === 'missing' && item.mandatory ? 'border-red-200' : ''}`}
            onClick={() => fileInputs.current[item.document_type]?.click()}
          >
            <input
              ref={el => { fileInputs.current[item.document_type] = el; }}
              type="file"
              multiple
              accept=".pdf,.jpg,.jpeg,.png"
              className="hidden"
              onChange={e => {
                if (e.target.files?.length) {
                  uploadMutation.mutate({
                    docType: item.document_type,
                    files: Array.from(e.target.files),
                  });
                }
              }}
            />
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-3">
                <FileText className="h-8 w-8 text-muted-foreground" />
                <div>
                  <p className="font-medium flex items-center gap-2">
                    {item.label}
                    {item.mandatory && <Badge variant="destructive" className="text-[10px]">Required</Badge>}
                  </p>
                  <Badge className={`mt-1 ${STATUS_CONFIG[item.status]?.color}`}>
                    {STATUS_CONFIG[item.status]?.label || 'Pending'}
                  </Badge>
                </div>
              </div>
              <div className="flex gap-1">
                <Upload className="h-4 w-4 text-muted-foreground" />
                <Camera className="h-4 w-4 text-muted-foreground" />
              </div>
            </div>
            {item.tip && <p className="text-xs text-muted-foreground mt-2">{item.tip}</p>}
          </div>
        ))}
      </div>

      <ExtractedDataReview fy={fy} />
    </div>
  );
}

function ExtractedDataReview({ fy }: { fy: number }) {
  const queryClient = useQueryClient();
  const { data } = useQuery({
    queryKey: ['tax-documents', fy],
    queryFn: () => api.get(`/tax_documents?financial_year=${fy}`).then(res => res.data),
  });

  const actionable = (data?.documents || []).filter(
    (d: any) => ['extracted', 'mismatch'].includes(d.status)
  );

  const verifyMutation = useMutation({
    mutationFn: ({ id, extracted }: { id: number; extracted?: any }) =>
      api.patch(`/tax_documents/${id}/verify`, { extracted_data: extracted }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['tax-documents'] }),
  });

  if (!actionable.length) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <AlertTriangle className="h-5 w-5 text-amber-500" />
          Confirm Extracted Data ({actionable.length})
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {actionable.map((doc: any) => (
          <div key={doc.id} className="border rounded-lg p-4">
            <div className="flex justify-between items-start mb-3">
              <p className="font-medium">{doc.document_type.replace(/_/g, ' ')}</p>
              <Badge className={STATUS_CONFIG[doc.status].color}>{STATUS_CONFIG[doc.status].label}</Badge>
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm mb-3">
              {Object.entries(doc.extracted_data || {})
                .filter(([k, v]) => typeof v === 'number' || typeof v === 'string')
                .slice(0, 8)
                .map(([key, value]) => (
                  <div key={key} className="flex justify-between border-b pb-1">
                    <span className="text-muted-foreground">{key.replace(/_/g, ' ')}</span>
                    <span className="font-mono">{String(value)}</span>
                  </div>
                ))}
            </div>
            <div className="flex gap-2">
              <Button size="sm" onClick={() => verifyMutation.mutate({ id: doc.id })}>
                <CheckCircle2 className="h-4 w-4 mr-1" /> Looks Correct
              </Button>
              <Button size="sm" variant="outline">
                <Eye className="h-4 w-4 mr-1" /> View Original
              </Button>
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
