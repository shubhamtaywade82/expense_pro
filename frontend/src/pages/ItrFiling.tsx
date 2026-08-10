import { useState } from 'react';
import { Link } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { FilingReadiness } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { AlertTriangle, ShieldCheck, FileJson, Upload, ArrowRight, Vault } from 'lucide-react';

export default function ItrFiling() {
  const [fy, setFy] = useState(2025);
  const [step, setStep] = useState(0);

  const { data: readiness } = useQuery({
    queryKey: ['itr-readiness', fy],
    queryFn: () => api.get<FilingReadiness>(`/itr_filing/readiness?financial_year=${fy}`),
  });

  const { data: prefill } = useQuery({
    queryKey: ['itr-prefill', fy],
    queryFn: () => api.get<Record<string, unknown>>(`/itr_filing/prefill?financial_year=${fy}`),
    enabled: !!readiness?.can_file_self,
  });

  const steps = [
    { name: 'Documents', path: '/tax-documents' },
    { name: 'Reconciliation', path: null },
    { name: 'Review ITR', path: null },
    { name: 'Download & File', path: null },
    { name: 'E-Verify', path: null }
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">File Your ITR</h1>
          <p className="text-sm text-muted-foreground">
            Assessment Year {fy + 1}-{String(fy + 2).slice(2)} (FY {fy}-{String(fy + 1).slice(2)})
          </p>
        </div>
        <Link to="/tax-documents">
          <Button variant="outline" className="gap-2">
            <Vault className="h-4 w-4" /> Open Tax Document Vault
          </Button>
        </Link>
      </div>

      {/* Progress steps */}
      <div className="flex gap-2">
        {steps.map((s, i) => (
          s.path ? (
            <Link
              key={s.name}
              to={s.path}
              className={`flex-1 text-center py-2 rounded text-sm font-medium transition-colors
                ${i <= step ? 'bg-primary text-primary-foreground hover:bg-primary/90' : 'bg-muted hover:bg-muted/80'}`}
            >
              {i + 1}. {s.name}
            </Link>
          ) : (
            <div
              key={s.name}
              className={`flex-1 text-center py-2 rounded text-sm font-medium
                ${i <= step ? 'bg-primary text-primary-foreground' : 'bg-muted'}`}
            >
              {i + 1}. {s.name}
            </div>
          )
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
      {!!readiness?.blockers?.length && (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle>Resolve Before Filing ({readiness!.blockers.length})</CardTitle>
            <Link to="/tax-documents">
              <Button size="sm" className="gap-2">
                <Upload className="h-4 w-4" /> Upload Documents <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </Link>
          </CardHeader>
          <CardContent className="space-y-2">
            {readiness!.blockers.map((b, i) => (
              <div key={i} className="text-sm border-l-4 border-amber-400 pl-3 py-2 flex items-center justify-between bg-amber-50/30 rounded-r">
                <div>
                  <strong className="capitalize">{b.item.replace(/_/g, ' ')}:</strong> {b.resolution}
                </div>
                <Link to="/tax-documents">
                  <Button variant="ghost" size="sm" className="text-xs text-primary underline">
                    Upload
                  </Button>
                </Link>
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
