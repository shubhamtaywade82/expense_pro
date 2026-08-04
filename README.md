# ExpensePro - Intelligent Personal Finance Platform

> **Production Ready** | **AI-Powered** | **Indian Tax Compliant** | **Microservices Architecture**

ExpensePro is a next-generation personal finance platform built with Rails 8, featuring an integrated AI chat assistant powered by local LLMs (Ollama) and a battle-tested Indian tax calculation engine (india-itr-copilot).

## 🚀 Key Features

### 💰 Comprehensive Financial Tracking
- **Expenses**: Multi-category tracking with UPI/Card/Cash support
- **Income**: Salary, freelance, rental, and investment income
- **Bills**: Recurring bill management with payment reminders
- **Loans & EMIs**: Loan tracking with amortization schedules
- **Budgets**: Category-wise budgeting with alerts
- **Investments**: Stocks, mutual funds, and crypto tracking

### 🧠 AI-Powered Chat Assistant (30 Tools)
Interact with your finances naturally using our AI chatbot:
- **"Show me my expenses last month"** → Lists expenses with filters
- **"Create a budget of ₹20k for groceries"** → Sets up budgets instantly
- **"Calculate my tax for FY 2025-26"** → Uses india-itr-copilot engine
- **"Explain Section 87A rebate"** → LLM explains tax provisions simply
- **"Pay my electricity bill"** → Triggers bill payment workflows

**Supported Intents**:
- Create/List/Update/Delete Expenses, Income, Bills, Loans, Investments
- Budget management and financial summaries
- **Tax Calculations**: Old vs New regime, F&O loss set-off, surcharge caps, marginal relief
- **Tax Explanations**: Plain English explanations of complex sections (80C, 80D, 112A, etc.)

### 🇮🇳 Accurate Indian Tax Engine
Integrated **india-itr-copilot** microservice ensures 100% tax compliance:
- **Head-based Computation**: Salary, House Property, Business/F&O, Capital Gains, Other Sources
- **Advanced Provisions**:
  - ✅ F&O loss set-off and carry-forward
  - ✅ Surcharge cap (15%) on Long Term Capital Gains (Section 112A)
  - ✅ Marginal Relief on 87A Rebate and Surcharge boundaries
  - ✅ Section 288B Rounding (nearest ₹10, ties UP)
  - ✅ Full Chapter VI-A Deductions (80C, 80D, 80TTA/B, HRA)
  - ✅ Interest Calculations (234A, 234B, 234C, 234F) with senior exemptions
- **Rules Registry**: JSON-driven tax slabs (AY2026-27+) for easy updates without code changes
- **Reconciliation**: AIS/26AS tie-out with tolerance checks

### 🔒 Security & Privacy
- **Local LLM**: Runs on your infrastructure (Ollama + qwen3.5:4b), no data leaves your server
- **Document Vault**: Password-protected 26AS/AIS unlocking with PAN+DOB mining
- **Role-Based Access**: Granular permissions for users and admins
- **Audit Logs**: Complete trail of AI actions and financial changes

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     EXPENSEPRO (Rails 8)                        │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Document     │  │ Broker       │  │ UI (React/Hotwire)   │  │
│  │ Vault        │  │ Adapters     │  │                      │  │
│  │ (Active      │  │ (Dhan/CoinDCX│  │  Uploads / Review /  │  │
│  │  Storage)    │  │  /Zerodha)   │  │  Reconciliation view │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────┘  │
│         │                 │                                     │
│         └────────┬────────┘                                     │
│                  ▼                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Data Assembly Service  (Ruby)                            │  │
│  │ - Normalizes broker trades                               │  │
│  │ - Parses 26AS/AIS PDFs                                   │  │
│  │ - Builds deduction ledger                                │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
           │
           │ HTTP POST /calculate-tax
           ▼
┌─────────────────────────────────────────────────────────────────┐
│              ITR SERVICE (Python + FastAPI)                     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Rules Registry (JSON per AY)                             │  │
│  │ - Slabs, rebates, surcharge rates                        │  │
│  │ - Source-cited, hand-verified                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Tax Brain (india-itr-copilot)                            │  │
│  │ - Head-wise computation                                  │  │
│  │ - 288B rounding, marginal relief                         │  │
│  │ - 112A surcharge cap, 87A rebate                         │  │
│  │ - 234A/B/C interest                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Response: { old_regime: {...}, new_regime: {...} }            │
└─────────────────────────────────────────────────────────────────┘
           │
           │ Optional: Explain provision
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OLLAMA (Local LLM)                           │
│  Model: qwen3.5:4b                                              │
│  - Explains tax sections in plain language                      │
│  - Answers user queries about deductions                        │
└─────────────────────────────────────────────────────────────────┘
```

### Microservices Strategy
1. **Rails 8 (Main App)**: Handles UI, authentication, data persistence, and broker syncs.
2. **Python Tax Service (`itr_service`)**: Dedicated microservice for tax calculations.
   - **Why?** Preserves battle-tested logic, 25 hand-verified test cases, and yearly rule updates via JSON.
   - **Communication**: HTTP/JSON with graceful fallback to Ruby calculator if unavailable.
3. **Ollama (LLM)**: Local inference server for natural language understanding and explanations.

## 🛠 Tech Stack

| Component | Technology |
|-----------|------------|
| **Backend** | Ruby 3.3, Rails 8 |
| **Frontend** | Hotwire, Turbo Streams, Tailwind CSS |
| **Database** | PostgreSQL 16 |
| **Cache/Queue** | Redis 7 |
| **AI/LLM** | Ollama (qwen3.5:4b), LangChain.rb |
| **Tax Engine** | Python 3.11, FastAPI, india-itr-copilot |
| **Deployment** | Docker, Docker Compose |
| **Testing** | RSpec, Pytest |

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Git

### Installation

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd expense-pro
   ```

2. **Start all services**:
   ```bash
   docker-compose up --build
   ```
   This starts:
   - Rails App (Port 3000)
   - PostgreSQL
   - Redis
   - Python Tax Service (Port 8000)
   - Ollama LLM (Port 11434)

3. **Access the application**:
   - Web UI: http://localhost:3000
   - API Docs: http://localhost:3000/api/docs
   - Tax Service Health: http://localhost:8000/health

### Initial Setup
```bash
# Run migrations
docker-compose exec rails bin/rails db:migrate

# Seed initial data (optional)
docker-compose exec rails bin/rails db:seed

# Pull LLM model (first time only)
docker-compose exec ollama ollama pull qwen3.5:4b
```

## 📖 Documentation

- [Architecture Details](ARCHITECTURE.md) - Deep dive into microservices and data flow
- [AI Tools Guide](AI_TOOLS_GUIDE.md) - Complete list of 30 AI tools and usage examples
- [Deployment Guide](DEPLOYMENT.md) - Production deployment checklist and scaling
- [Testing Strategy](TESTING_STRATEGY.md) - How we ensure tax accuracy and AI reliability

## 🧪 Testing

### Run Ruby Tests
```bash
docker-compose exec rails bin/rspec
```

### Run Python Tax Tests
```bash
docker-compose exec itr_service pytest
```

### Validate Tax Accuracy
The system includes 25 hand-verified test cases covering edge cases like:
- Income exactly at rebate boundaries (₹5L, ₹7L)
- Surcharge thresholds (₹50L, ₹1Cr, ₹2Cr)
- F&O losses with other income heads
- Senior citizen interest exemptions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **india-itr-copilot**: For the robust open-source tax calculation engine
- **Ollama**: For making local LLM inference accessible
- **Rails Community**: For the incredible Rails 8 framework

---

**Built with ❤️ for Indian Investors**
