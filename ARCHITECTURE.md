# ExpensePro Architecture

## Overview

ExpensePro follows a **microservices architecture** that combines the rapid development capabilities of Rails 8 with the accuracy of a specialized Python tax engine and the intelligence of local LLMs.

## System Components

### 1. Rails 8 Application (Main App)

**Port**: 3000  
**Purpose**: Core application handling UI, authentication, data persistence, and external integrations.

**Responsibilities**:
- User authentication and authorization
- Financial data CRUD operations (expenses, income, bills, loans, investments, budgets)
- Broker API integrations (Zerodha, Dhan, CoinDCX)
- Document upload and parsing (26AS, AIS, Form 16)
- AI chat interface and tool orchestration
- Background job processing (via Sidekiq/Redis)

**Key Models**:
```
User
├── Category
├── Expense
├── Income
├── Bill
├── Loan
│   └── EmiPayment
├── Investment
├── Budget
└── ChatMessage
```

### 2. Python Tax Service (itr_service)

**Port**: 8000  
**Framework**: FastAPI  
**Purpose**: Accurate Indian tax calculations using the battle-tested india-itr-copilot engine.

**Why a Separate Service?**
- **Accuracy**: 25 hand-verified test cases ensure correctness
- **Maintainability**: Tax rules change yearly; JSON registry allows updates without code changes
- **Isolation**: Tax bugs cannot crash the main application
- **Performance**: Python has superior PDF/Excel libraries for document processing

**Endpoints**:
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check with rules directory status |
| `/compare-regimes` | GET | Compare old vs new tax regimes |
| `/calculate-tax` | POST | Detailed tax calculation with all heads |
| `/unlock-document` | POST | Unlock password-protected 26AS/AIS PDFs |
| `/reconcile-ledger` | POST | Reconcile transactions against AIS/26AS |

**Tax Features**:
- Head-wise computation (Salary, House Property, Business/F&O, Capital Gains, Other Sources)
- Section 288B rounding (nearest ₹10, ties UP)
- Marginal relief on 87A rebate AND surcharge boundaries
- Surcharge cap (15%) on Long Term Capital Gains (Section 112A)
- Full Chapter VI-A deductions (80C, 80D, 80TTA/B, HRA)
- Interest calculations (234A, 234B, 234C, 234F) with senior exemptions
- F&O loss set-off and carry-forward logic

**Rules Registry**:
```json
{
  "assessment_year": "AY2026-27",
  "old_regime": {
    "slabs": [
      {"min": 0, "max": 250000, "rate": 0},
      {"min": 250001, "max": 500000, "rate": 0.05},
      {"min": 500001, "max": 1000000, "rate": 0.2},
      {"min": 1000001, "max": null, "rate": 0.3}
    ],
    "rebate_87a_threshold": 500000,
    "rebate_87a_max": 12500
  },
  "new_regime": {
    "slabs": [
      {"min": 0, "max": 300000, "rate": 0},
      {"min": 300001, "max": 600000, "rate": 0.05},
      {"min": 600001, "max": 900000, "rate": 0.1},
      {"min": 900001, "max": 1200000, "rate": 0.15},
      {"min": 1200001, "max": 1500000, "rate": 0.2},
      {"min": 1500001, "max": null, "rate": 0.3}
    ],
    "standard_deduction": 75000
  },
  "surcharge_rates": [
    {"threshold": 5000000, "rate": 0.1},
    {"threshold": 10000000, "rate": 0.15},
    {"threshold": 20000000, "rate": 0.25},
    {"threshold": 50000000, "rate": 0.37}
  ]
}
```

### 3. Ollama LLM Service

**Port**: 11434  
**Model**: qwen3.5:4b  
**Purpose**: Natural language understanding and tax provision explanations.

**Capabilities**:
- Parse user intents for financial actions
- Explain complex tax sections in plain language
- Provide personalized financial advice
- Answer questions about deductions, exemptions, and compliance

**Integration Flow**:
```
User Query → AiChatService → Tool Executor → Ollama API → Response
```

### 4. Supporting Services

#### PostgreSQL Database
**Port**: 5432  
**Purpose**: Persistent storage for all financial data, users, and chat history.

#### Redis
**Port**: 6379  
**Purpose**: 
- Cache for frequently accessed data
- Background job queue (Sidekiq)
- Session storage
- Rate limiting for AI calls

## Data Flow

### Tax Calculation Flow

```
┌─────────────┐
│   User      │
│  Input      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Rails Controller                       │
│  (Api::V1::TaxController)               │
│  - Validates input                      │
│  - Assembles data from multiple models  │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  ItrClientService (Ruby)                │
│  - HTTP client with retry logic         │
│  - Timeout handling                     │
│  - Graceful fallback to Ruby calculator │
└──────┬──────────────────────────────────┘
       │
       │ HTTP POST /calculate-tax
       │ { gross_salary, fo_pnl, ... }
       ▼
┌─────────────────────────────────────────┐
│  FastAPI Service (Python)               │
│  - Loads rules from JSON registry       │
│  - Runs india-itr-copilot logic         │
│  - Applies 288B rounding                │
│  - Calculates marginal relief           │
└──────┬──────────────────────────────────┘
       │
       │ { old_regime, new_regime, ... }
       ▼
┌─────────────────────────────────────────┐
│  Rails Controller                       │
│  - Returns JSON response                │
│  - Logs calculation for audit           │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────┐
│   User      │
│  Sees       │
│  Result     │
└─────────────┘
```

### AI Chat Flow

```
┌─────────────┐
│   User      │
│  Types:     │
│ "Calculate  │
│  my tax"    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  AiChatService                          │
│  - Sends conversation to Ollama         │
│  - Includes tool definitions            │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Ollama (qwen3.5:4b)                    │
│  - Analyzes intent                      │
│  - Decides to call tool                 │
│  - Returns tool name + arguments        │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  ToolExecutor                           │
│  - Routes to appropriate tool           │
│  - Executes calculate_tax_with_copilot  │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  ItrClientService                       │
│  - Calls Python tax service             │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  AiChatService                          │
│  - Formats result as natural language   │
│  - Sends back to user                   │
└──────┬──────────────────────────────────┘
```

## Resilience Patterns

### Graceful Degradation

If the Python tax service is unavailable:
1. `ItrClientService` catches connection errors
2. Falls back to Ruby `TaxCalculatorService`
3. Logs warning for investigation
4. User receives calculation (with notice if less accurate)

### Retry Logic

```ruby
# ItrClientService implements exponential backoff
begin
  HTTParty.post(url, options)
rescue => e
  sleep(2 ** attempt)
  retry if attempt < 3
  fall_back_to_ruby
end
```

### Circuit Breaker Pattern

- Track failure rate for tax service calls
- If > 50% failures in last minute, open circuit
- Route all requests to fallback immediately
- Half-open after 30 seconds to test recovery

## Security Considerations

### Data Isolation
- Tax service has NO direct database access
- All data passed via encrypted HTTP
- No PII stored in tax service logs

### Local LLM
- Ollama runs on same infrastructure
- No user data sent to external APIs
- Model weights stored locally

### Document Security
- Password-protected PDFs unlocked in isolated container
- PAN+DOB mined securely, never logged
- Temporary files deleted after processing

## Deployment Topology

### Development
```
docker-compose.yml
├── rails (port 3000)
├── postgres (port 5432)
├── redis (port 6379)
├── itr_service (port 8000)
└── ollama (port 11434)
```

### Production
```
Load Balancer
    ├── Rails Pods (×3)
    │   ├── Sidekiq workers
    │   └── Puma server
    ├── Python Tax Service (×2)
    ├── Ollama Pod (GPU-enabled)
    ├── PostgreSQL (Managed RDS)
    └── Redis (ElastiCache)
```

## Monitoring & Observability

### Metrics to Track
- Tax calculation latency (p95 < 500ms)
- Fallback rate (target < 1%)
- AI tool invocation counts
- Ollama inference time
- Error rates by endpoint

### Logging Strategy
- Structured JSON logs
- Correlation IDs across services
- Separate log streams for tax calculations (audit trail)

### Health Checks
- `/health` endpoints on all services
- Database connection pool status
- Redis connectivity
- Ollama model availability

## Future Enhancements

1. **Multi-Year Support**: Load different rule sets for different FYs
2. **Tax Planning**: AI-powered suggestions before year-end
3. **Auto-Filing**: Generate ITR JSON for government portal
4. **Broker Expansion**: Add more broker adapters (Angel One, Groww)
5. **Mobile App**: React Native frontend sharing same backend

---

*Last Updated: 2025*
