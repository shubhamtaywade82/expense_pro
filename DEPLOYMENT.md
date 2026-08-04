# Deployment Guide - ExpensePro

## Production Readiness Checklist

### ✅ Pre-Deployment Verification

- [ ] All 30 AI tools tested and documented
- [ ] Python tax service health checks passing
- [ ] Ollama LLM model (qwen3.5:4b) pulled and verified
- [ ] Database migrations run successfully
- [ ] Environment variables configured securely
- [ ] SSL/TLS certificates installed
- [ ] Backup strategy implemented
- [ ] Monitoring dashboards configured

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    PRODUCTION ENVIRONMENT                   │
│                                                             │
│  ┌─────────────┐                                           │
│  │   Load      │                                           │
│  │  Balancer   │                                           │
│  │  (nginx)    │                                           │
│  └──────┬──────┘                                           │
│         │                                                   │
│    ┌────┴────┐                                              │
│    ▼         ▼                                              │
│ ┌──────┐  ┌──────┐                                          │
│ │Rails │  │Rails │  (Horizontal Scaling)                    │
│ │ Pod 1│  │ Pod 2│                                          │
│ └──┬───┘  └──┬───┘                                          │
│    │         │                                               │
│    └────┬────┘                                              │
│         │                                                   │
│    ┌────┴────────────────────────┐                          │
│    ▼                             ▼                          │
│ ┌──────┐                   ┌──────────┐                     │
│ │ ITR  │                   │  Ollama  │                     │
│ │Service│                  │   LLM    │                     │
│ │(×2)   │                  │ (GPU)    │                     │
│ └──────┘                   └──────────┘                     │
│                                                             │
│    ┌────────────┐          ┌──────────┐                     │
│    │ PostgreSQL │          │  Redis   │                     │
│    │  (RDS)     │          │(ElastiCache)                   │
│    └────────────┘          └──────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## Environment Variables

### Required Variables

```bash
# Rails Application
RAILS_ENV=production
RAILS_MASTER_KEY=<your-master-key>
SECRET_KEY_BASE=<generated-secret>

# Database
DATABASE_URL=postgres://user:password@host:5432/expensepro_production

# Redis
REDIS_URL=redis://host:6379/0

# Ollama LLM
OLLAMA_HOST=http://ollama:11434
OLLAMA_MODEL=qwen3.5:4b

# Tax Service
ITR_SERVICE_HOST=http://itr-service:8000
ITR_SERVICE_TIMEOUT=5

# External APIs (if using broker integrations)
ZERODHA_API_KEY=<key>
ZERODHA_ACCESS_TOKEN=<token>
```

### Optional Variables

```bash
# Logging
RAILS_LOG_LEVEL=info
LOG_FORMAT=json

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=3

# Security
ALLOWED_HOSTS=expensepro.example.com,www.expensepro.example.com
FORCE_SSL=true
```

## Docker Compose (Development/Staging)

```yaml
version: '3.8'

services:
  rails:
    build: .
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgres://postgres:password@db:5432/expensepro_production
      - REDIS_URL=redis://redis:6379/0
      - OLLAMA_HOST=http://ollama:11434
      - ITR_SERVICE_HOST=http://itr_service:8000
    depends_on:
      - db
      - redis
      - ollama
      - itr_service
    volumes:
      - ./storage:/app/storage
    command: ./bin/thrust ./bin/rails server -b 0.0.0.0

  itr_service:
    build: ./itr_service
    ports:
      - "8000:8000"
    environment:
      - COPILOT_ROOT=/app
    volumes:
      - ./itr_service:/app
    command: uvicorn app:app --host 0.0.0.0 --port 8000

  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  db:
    image: postgres:16
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=expensepro_production
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
  ollama_data:
```

## Kubernetes Deployment (Production)

### Namespace Setup

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: expensepro
```

### Rails Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails
  namespace: expensepro
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rails
  template:
    metadata:
      labels:
        app: rails
    spec:
      containers:
      - name: rails
        image: expensepro/rails:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: expensepro-secrets
              key: database-url
        - name: REDIS_URL
          value: "redis://redis:6379/0"
        - name: OLLAMA_HOST
          value: "http://ollama:11434"
        - name: ITR_SERVICE_HOST
          value: "http://itr-service:8000"
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: rails-service
  namespace: expensepro
spec:
  selector:
    app: rails
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
```

### ITR Service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: itr-service
  namespace: expensepro
spec:
  replicas: 2
  selector:
    matchLabels:
      app: itr-service
  template:
    metadata:
      labels:
        app: itr-service
    spec:
      containers:
      - name: itr-service
        image: expensepro/itr-service:latest
        ports:
        - containerPort: 8000
        env:
        - name: COPILOT_ROOT
          value: "/app"
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: itr-service
  namespace: expensepro
spec:
  selector:
    app: itr-service
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP
```

### Ollama Deployment (GPU Required)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: expensepro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "8Gi"
          requests:
            nvidia.com/gpu: 1
            memory: "4Gi"
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: expensepro
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
  type: ClusterIP
```

### Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: expensepro-ingress
  namespace: expensepro
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - expensepro.example.com
    secretName: expensepro-tls
  rules:
  - host: expensepro.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rails-service
            port:
              number: 80
```

## CI/CD Pipeline

### GitHub Actions Workflow

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.3.4
        bundler-cache: true
    
    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      run: |
        bundle install
        cd itr_service && pip install -r requirements.txt
    
    - name: Run tests
      run: |
        bin/rails db:migrate
        bin/rspec
        cd itr_service && pytest
    
  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Login to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push Rails image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ghcr.io/${{ github.repository }}/rails:latest
    
    - name: Build and push ITR Service image
      uses: docker/build-push-action@v5
      with:
        context: ./itr_service
        push: true
        tags: ghcr.io/${{ github.repository }}/itr-service:latest
    
  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure kubectl
      uses: azure/k8s-set-context@v3
      with:
        kubeconfig: ${{ secrets.KUBE_CONFIG }}
    
    - name: Deploy to Kubernetes
      run: |
        kubectl apply -f k8s/namespace.yaml
        kubectl set image deployment/rails rails=ghcr.io/${{ github.repository }}/rails:latest -n expensepro
        kubectl set image deployment/itr-service itr-service=ghcr.io/${{ github.repository }}/itr-service:latest -n expensepro
        kubectl rollout restart deployment/rails -n expensepro
        kubectl rollout restart deployment/itr-service -n expensepro
    
    - name: Verify deployment
      run: |
        kubectl rollout status deployment/rails -n expensepro
        kubectl rollout status deployment/itr-service -n expensepro
```

## Monitoring & Alerting

### Prometheus Metrics

```yaml
# Key metrics to monitor
- rails_http_requests_total
- rails_active_record_connections
- itr_service_latency_seconds
- ollama_inference_duration_seconds
- ai_tool_invocations_total
- tax_calculation_fallback_rate
```

### Grafana Dashboard Panels

1. **Request Rate**: HTTP requests per second
2. **Latency**: p50, p95, p99 response times
3. **Error Rate**: 4xx and 5xx errors
4. **Tax Service Health**: Fallback rate, calculation time
5. **AI Usage**: Tool invocations by type
6. **Database**: Connection pool usage, query latency
7. **Cache**: Redis hit/miss ratio

### Alert Rules

```yaml
groups:
- name: expensepro
  rules:
  - alert: HighErrorRate
    expr: rate(rails_http_requests_total{status=~"5.."}[5m]) > 0.05
    for: 5m
    annotations:
      summary: "High error rate detected"
  
  - alert: TaxServiceDown
    expr: up{job="itr-service"} == 0
    for: 1m
    annotations:
      summary: "ITR Service is down"
  
  - alert: OllamaSlow
    expr: histogram_quantile(0.95, rate(ollama_inference_duration_seconds_bucket[5m])) > 3
    for: 10m
    annotations:
      summary: "Ollama inference is slow"
  
  - alert: DatabaseConnectionsHigh
    expr: rails_active_record_connections / rails_active_record_connection_pool_size > 0.9
    for: 5m
    annotations:
      summary: "Database connection pool nearly exhausted"
```

## Backup Strategy

### Database Backups

```bash
#!/bin/bash
# Daily backup script
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump $DATABASE_URL > /backups/expensepro_$DATE.sql.gz
aws s3 cp /backups/expensepro_$DATE.sql.gz s3://expensepro-backups/db/

# Retention: Keep last 30 daily backups
find /backups -name "expensepro_*.sql.gz" -mtime +30 -delete
```

### Volume Backups

```yaml
# Kubernetes CronJob for PVC backup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-ollama
  namespace: expensepro
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox
            command:
            - /bin/sh
            - -c
            - |
              tar czf /backup/ollama_$(date +%Y%m%d).tar.gz /root/.ollama
              aws s3 cp /backup/ s3://expensepro-backups/ollama/ --recursive
          restartPolicy: OnFailure
```

## Scaling Strategy

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rails-hpa
  namespace: expensepro
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rails
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Cost Optimization Tips

1. **Use Spot Instances** for stateless Rails pods
2. **Right-size Ollama GPU** based on actual usage
3. **Enable Cluster Autoscaler** for dynamic scaling
4. **Use Reserved Instances** for baseline capacity
5. **Implement Request Coalescing** for tax calculations

## Disaster Recovery

### RTO/RPO Targets

| Metric | Target |
|--------|--------|
| RTO (Recovery Time Objective) | < 1 hour |
| RPO (Recovery Point Objective) | < 15 minutes |

### DR Steps

1. **Database Failure**: Failover to read replica, promote to primary
2. **Region Failure**: DNS failover to secondary region
3. **Data Loss**: Restore from latest S3 backup
4. **Service Corruption**: Rollback to previous Kubernetes deployment

---

*Last Updated: 2025*
