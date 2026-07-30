import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '../components/ui/dialog';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import {
  Link2, Unlink, RefreshCw, Download, TrendingUp,
  Bitcoin, LineChart, Landmark, CheckCircle2, AlertCircle, Loader2
} from 'lucide-react';

interface BrokerInfo {
  type: string;
  name: string;
  asset_classes: string[];
  auth_type: string;
  required_credentials: string[];
  tax_category: string;
  tds_applicable: boolean;
  documentation_url: string | null;
}

interface ConnectedBroker {
  id: number;
  broker_type: string;
  display_name: string;
  status: string;
  has_api_key: boolean;
  has_access_token: boolean;
  token_expires_at: string | null;
  last_sync_at: string | null;
}

const BROKER_ICONS: Record<string, typeof Bitcoin> = {
  dhanhq: LineChart,
  coindcx: Bitcoin,
  delta_exchange: Bitcoin,
  wazirx: Bitcoin,
  coinswitch: Bitcoin,
  zerodha: Landmark,
  groww: TrendingUp,
  upstox: TrendingUp,
  angel_one: Landmark,
};

const BROKER_CATEGORIES = {
  crypto: { label: 'Crypto Exchanges', icon: Bitcoin, color: 'text-orange-500' },
  equity: { label: 'Stock Brokers', icon: Landmark, color: 'text-blue-500' },
};

export default function Brokers() {
  const [connectDialog, setConnectDialog] = useState<BrokerInfo | null>(null);
  const [credentials, setCredentials] = useState<Record<string, string>>({});
  const queryClient = useQueryClient();

  const { data: available } = useQuery({
    queryKey: ['brokers', 'available'],
    queryFn: () => api.get('/brokers/available').then(res => res.data),
  });

  const { data: connected } = useQuery({
    queryKey: ['brokers', 'connected'],
    queryFn: () => api.get('/brokers/connected').then(res => res.data),
  });

  const connectMutation = useMutation({
    mutationFn: (data: { broker_type: string; credentials: Record<string, string> }) =>
      api.post('/brokers/connect', {
        broker_type: data.broker_type,
        ...data.credentials,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['brokers'] });
      setConnectDialog(null);
      setCredentials({});
    },
  });

  const syncMutation = useMutation({
    mutationFn: (brokerType: string) =>
      api.post(`/brokers/${brokerType}/sync`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['brokers'] });
    },
  });

  const disconnectMutation = useMutation({
    mutationFn: (brokerType: string) =>
      api.delete(`/brokers/${brokerType}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['brokers'] });
    },
  });

  const connectedTypes = new Set(
    (connected?.brokers || []).map((b: ConnectedBroker) => b.broker_type)
  );

  const cryptoBrokers = (available?.brokers || []).filter(
    (b: BrokerInfo) => b.asset_classes.includes('crypto')
  );
  const equityBrokers = (available?.brokers || []).filter(
    (b: BrokerInfo) => b.asset_classes.some(a => ['equity', 'futures', 'options'].includes(a))
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Broker Connections</h1>
          <p className="text-muted-foreground">
            Connect your brokers to auto-import trades, holdings, and P&L
          </p>
        </div>
      </div>

      {/* Connected Brokers */}
      {(connected?.brokers || []).length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CheckCircle2 className="h-5 w-5 text-green-500" />
              Connected ({connected.brokers.length})
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {connected.brokers.map((broker: ConnectedBroker) => {
              const Icon = BROKER_ICONS[broker.broker_type] || Link2;
              return (
                <div key={broker.id} className="flex items-center justify-between p-3 rounded-lg border">
                  <div className="flex items-center gap-3">
                    <Icon className="h-8 w-8 text-primary" />
                    <div>
                      <p className="font-medium">{broker.display_name}</p>
                      <p className="text-sm text-muted-foreground">
                        {broker.last_sync_at
                          ? `Last synced: ${new Date(broker.last_sync_at).toLocaleString('en-IN')}`
                          : 'Never synced'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant={broker.status === 'active' ? 'default' : 'destructive'}>
                      {broker.status}
                    </Badge>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => syncMutation.mutate(broker.broker_type)}
                      disabled={syncMutation.isPending}
                    >
                      {syncMutation.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
                      Sync
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => disconnectMutation.mutate(broker.broker_type)}
                    >
                      <Unlink className="h-4 w-4 text-destructive" />
                    </Button>
                  </div>
                </div>
              );
            })}
          </CardContent>
        </Card>
      )}

      {/* Available Brokers by Category */}
      {Object.entries({ crypto: cryptoBrokers, equity: equityBrokers }).map(([category, brokers]) => {
        const cat = BROKER_CATEGORIES[category as keyof typeof BROKER_CATEGORIES];
        const CatIcon = cat.icon;
        return (
          <Card key={category}>
            <CardHeader>
              <CardTitle className={`flex items-center gap-2 ${cat.color}`}>
                <CatIcon className="h-5 w-5" />
                {cat.label}
              </CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {brokers.map((broker: BrokerInfo) => {
                const isConnected = connectedTypes.has(broker.type);
                const Icon = BROKER_ICONS[broker.type] || Link2;
                return (
                  <div key={broker.type} className="p-4 rounded-lg border hover:border-primary/50 transition-colors">
                    <div className="flex items-center gap-3 mb-3">
                      <Icon className="h-8 w-8 text-primary" />
                      <div>
                        <p className="font-medium">{broker.name}</p>
                        <div className="flex gap-1 mt-1">
                          {broker.asset_classes.map(ac => (
                            <Badge key={ac} variant="secondary" className="text-xs">{ac}</Badge>
                          ))}
                        </div>
                      </div>
                    </div>
                    {broker.tds_applicable && (
                      <p className="text-xs text-amber-600 mb-2">
                        ⚠️ 1% TDS under Section 194S on sell transactions
                      </p>
                    )}
                    <Button
                      className="w-full"
                      variant={isConnected ? 'outline' : 'default'}
                      disabled={isConnected}
                      onClick={() => {
                        setConnectDialog(broker);
                        setCredentials({});
                      }}
                    >
                      {isConnected ? '✓ Connected' : 'Connect'}
                    </Button>
                  </div>
                );
              })}
            </CardContent>
          </Card>
        );
      })}

      {/* Connect Dialog */}
      <Dialog open={!!connectDialog} onOpenChange={() => setConnectDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Connect {connectDialog?.name}</DialogTitle>
          </DialogHeader>
          {connectDialog && (
            <div className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Enter your {connectDialog.name} API credentials. These are encrypted
                at rest and never exposed after saving.
              </p>

              {connectDialog.required_credentials.map(field => (
                <div key={field} className="space-y-1">
                  <Label>{field.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}</Label>
                  <Input
                    type={field.includes('secret') || field.includes('token') ? 'password' : 'text'}
                    value={credentials[field] || ''}
                    onChange={e => setCredentials(prev => ({ ...prev, [field]: e.target.value }))}
                    placeholder={`Enter ${field.replace(/_/g, ' ')}`}
                  />
                </div>
              ))}

              {connectDialog.documentation_url && (
                <a
                  href={connectDialog.documentation_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-sm text-primary hover:underline"
                >
                  How to get API credentials →
                </a>
              )}

              {connectMutation.isError && (
                <div className="flex items-center gap-2 text-destructive text-sm">
                  <AlertCircle className="h-4 w-4" />
                  {connectMutation.error?.message || 'Connection failed'}
                </div>
              )}

              <Button
                className="w-full"
                onClick={() => connectMutation.mutate({
                  broker_type: connectDialog.type,
                  credentials,
                })}
                disabled={connectMutation.isPending}
              >
                {connectMutation.isPending ? (
                  <><Loader2 className="h-4 w-4 animate-spin mr-2" /> Connecting...</>
                ) : (
                  <><Link2 className="h-4 w-4 mr-2" /> Connect {connectDialog.name}</>
                )}
              </Button>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
