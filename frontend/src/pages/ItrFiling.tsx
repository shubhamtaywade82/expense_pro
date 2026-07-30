import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { AlertTriangle, ShieldCheck, FileJson } from 'lucide-react';

export default function ItrFiling() {
  const [fy, setFy] = useState(2025);
  const [step, setStep] = useState(0);

  const { data: readiness } = useQuery({
    queryKey: ['itr-readiness', fy],
    queryFn: () => api.get(`/itr_filing/readiness?financial_year=${fy}`).then(res => res.data),
  });

  const { data: prefill } = useQuery({
    queryKey: ['itr-prefill', fy],
    queryFn: () => api.get(`/itr_filing/prefill?financial_year=${fy}`).then(res => res.data),
    enabled: !!readiness?.can_file_self,
  });

  const steps = ['Documents', 'Reconciliation', 'Review ITR', 'Download & File', 'E-Verify'];

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">File Your ITR</h1>

      {/* Progress steps */}
      <div className="flex gap-2">
        {steps.map((s, i) => (
          <div key={s} className={`flex-1 text-center py-2 rounded text-sm font-medium
            ${i <= step ? 'bg-primary text-primary-foreground' : 'bg-muted'}`}>
            {i + 1}. {s}
          </div>
        ))}
      </div>

      {/* CA-required warning — shown prominently if applicable */}
      {readiness?.ca_required && (
        <Card className="border-red-300 bg-red-50/50">
          <CardContent className="pt-4">
            <p className="font-semibold text-red-800 flex items-center gap-2">
              <AlertTriangle className="h-5 w-5" /> A CA is legally required for part of this filing
            </p>
            {readiness.ca_required_reasons.map((r: any) => (
              <div key={r.reason} className="mt-2 text-sm text-red-700">
                <strong>{r.reason}:</strong> {r.detail}
                <p className="text-xs mt-1">✓ App has prepared: {r.what_app_prepared}</p>
              </div>
            ))}
          </CardContent>
        </Card>
      )}

      {/* Blockers that must be resolved */}
      {readiness?.blockers?.length > 0 && (
        <Card>
          <CardHeader><CardTitle>Resolve Before Filing ({readiness.blockers.length})</CardTitle></CardHeader>
          <CardContent className="space-y-2">
            {readiness.blockers.map((b: any, i: number) => (
              <div key={i} className="text-sm border-l-4 border-amber-400 pl-3 py-1">
                <strong>{b.item}:</strong> {b.resolution}
              </div>
            ))}
          </CardContent>
        </Card>
      )}

      {/* Ready state: download + portal walkthrough */}
      {readiness?.can_file_self && (
        <Card className="border-green-300 bg-green-50/30">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-green-800">
              <ShieldCheck className="h-6 w-6" /> Ready to File — {readiness.recommended_form}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button size="lg" onClick={() => window.open(`/api/v1/itr_filing/download?financial_year=${fy}`)}>
              <FileJson className="h-5 w-5 mr-2" /> Download Pre-filled ITR JSON
            </Button>
            <ol className="text-sm space-y-2 list-decimal list-inside text-muted-foreground">
              <li>Go to <strong>incometax.gov.in</strong> → Login with PAN</li>
              <li>e-File → Income Tax Returns → Assessment Year {fy + 1}</li>
              <li>Choose "Offline" → Upload the JSON you just downloaded</li>
              <li>Verify every pre-filled number against the summary below</li>
              <li>Submit → then <strong>e-verify within 30 days</strong> via Aadhaar OTP</li>
            </ol>
            <p className="text-xs text-muted-foreground">
              Due date: {readiness.due_date} · Estimated tax: ₹{readiness.estimated_tax?.toLocaleString('en-IN')}
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
