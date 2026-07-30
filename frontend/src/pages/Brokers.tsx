import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Input } from '../components/ui/input';
import {
  LineChart, RefreshCw, AlertCircle, Settings, CheckCircle2, ChevronRight, Download
} from 'lucide-react';
import { toast } from 'sonner';

export default function Brokers() {
  const queryClient = useQueryClient();
  const [selectedBroker, setSelectedBroker] = useState<string | null>(null);

  const { data: brokersData, isLoading } = useQuery({
    queryKey: ['brokers-list'],
    queryFn: () => api.get('/brokers').then(res => res.data.brokers),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Connected Brokers</h1>
          <p className="text-muted-foreground">Manage your broker integrations and sync your trade history automatically.</p>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {isLoading ? (
          <p className="text-muted-foreground p-4">Loading brokers...</p>
        ) : (
          brokersData?.map((broker: any) => (
            <Card key={broker.broker} className={`transition-all ${selectedBroker === broker.broker ? 'border-primary ring-1 ring-primary' : ''}`}>
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-500 to-purple-500 flex items-center justify-center shadow-md">
                      <LineChart className="w-5 h-5 text-white" />
                    </div>
                    <div>
                      <CardTitle className="text-lg">{broker.name}</CardTitle>
                      <CardDescription className="text-xs uppercase font-semibold mt-1">
                        {broker.broker}
                      </CardDescription>
                    </div>
                  </div>
                  <Badge variant={broker.connected ? "default" : (broker.configured ? "secondary" : "outline")} 
                         className={broker.connected ? "bg-green-500 hover:bg-green-600" : ""}>
                    {broker.connected ? 'Connected' : (broker.configured ? 'Configured' : 'Not Setup')}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent>
                {broker.configured && (
                  <div className="text-sm text-muted-foreground mb-4">
                    Client ID: <span className="font-mono text-foreground">{broker.client_id}</span>
                  </div>
                )}
                
                <Button 
                  variant={selectedBroker === broker.broker ? "secondary" : "outline"}
                  className="w-full justify-between"
                  onClick={() => setSelectedBroker(broker.broker)}
                >
                  Manage Connection
                  <ChevronRight className="w-4 h-4 ml-2" />
                </Button>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {selectedBroker && (
        <BrokerConfiguration brokerKey={selectedBroker} />
      )}
    </div>
  );
}

function BrokerConfiguration({ brokerKey }: { brokerKey: string }) {
  const queryClient = useQueryClient();
  const [clientId, setClientId] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [apiSecret, setApiSecret] = useState('');
  
  const { data: credential, isLoading } = useQuery({
    queryKey: ['broker-credential', brokerKey],
    queryFn: () => api.get(`/brokers/${brokerKey}/credential`).then(res => res.data),
  });

  const saveMutation = useMutation({
    mutationFn: () => api.put(`/brokers/${brokerKey}/credential`, {
      broker_credential: {
        client_id: clientId || undefined,
        api_key: apiKey || undefined,
        api_secret: apiSecret || undefined
      }
    }),
    onSuccess: () => {
      toast.success("Broker credentials saved successfully");
      queryClient.invalidateQueries({ queryKey: ['broker-credential'] });
      queryClient.invalidateQueries({ queryKey: ['brokers-list'] });
      setApiKey('');
      setApiSecret('');
    },
    onError: () => toast.error("Failed to save credentials")
  });

  const syncMutation = useMutation({
    mutationFn: () => api.post(`/brokers/${brokerKey}/sync`),
    onSuccess: () => toast.success("Sync started in background")
  });

  if (isLoading) return <div className="p-4 border rounded-xl bg-card">Loading configuration...</div>;

  return (
    <div className="grid gap-6 md:grid-cols-2">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="w-5 h-5 text-primary" />
            API Configuration
          </CardTitle>
          <CardDescription>
            Enter your API keys for {brokerKey}. They are stored securely and encrypted at rest.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium">Client ID</label>
            <Input 
              placeholder={credential?.client_id || "e.g. 110011XXXX"} 
              value={clientId}
              onChange={e => setClientId(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium">API Key</label>
            <Input 
              type="password"
              placeholder={credential?.has_api_key ? "•••••••••••••••• (Set)" : "Enter API Key"} 
              value={apiKey}
              onChange={e => setApiKey(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium">API Secret (or Token)</label>
            <Input 
              type="password"
              placeholder={credential?.has_api_secret ? "•••••••••••••••• (Set)" : "Enter API Secret/Token"} 
              value={apiSecret}
              onChange={e => setApiSecret(e.target.value)}
            />
          </div>
          <Button 
            className="w-full mt-2" 
            onClick={() => saveMutation.mutate()}
            disabled={saveMutation.isPending}
          >
            {saveMutation.isPending ? "Saving..." : "Save Configuration"}
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <RefreshCw className="w-5 h-5 text-indigo-500" />
            Data Sync Operations
          </CardTitle>
          <CardDescription>
            Import trades, update holdings, and sync your portfolio.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="p-4 bg-muted/30 rounded-lg border flex flex-col gap-3">
            <div className="flex items-center gap-2 font-medium text-sm">
              <Download className="w-4 h-4 text-blue-500" /> Auto-Sync Holdings & Positions
            </div>
            <p className="text-xs text-muted-foreground">
              Syncs your current equity and F&O positions. Also imports trades from the last 7 days.
            </p>
            <Button 
              variant="outline" 
              className="w-full bg-background"
              onClick={() => syncMutation.mutate()}
              disabled={syncMutation.isPending || !credential?.client_id}
            >
              Start Sync
            </Button>
          </div>
          
          <div className="p-4 bg-amber-500/10 rounded-lg border border-amber-500/20 flex flex-col gap-3">
            <div className="flex items-center gap-2 font-medium text-sm text-amber-700 dark:text-amber-400">
              <AlertCircle className="w-4 h-4" /> Import Historical Trades
            </div>
            <p className="text-xs text-amber-700/80 dark:text-amber-400/80">
              Fetch the entire historical ledger for tax and capital gains calculation. This may take several minutes due to rate limits.
            </p>
            <div className="flex gap-2">
              <Input type="date" className="text-xs" />
              <Input type="date" className="text-xs" />
            </div>
            <Button variant="secondary" className="w-full bg-amber-500 hover:bg-amber-600 text-white border-0" disabled={!credential?.client_id}>
              Import Full History
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
