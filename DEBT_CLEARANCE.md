# Debt Clearance System

A full debt-settlement pipeline inside ExpensePro: a unified debt
registry, Freed-style settlement math, a ranked settlement queue, a
"What can I settle with ₹X?" simulator, income/scenario projections and
the road to a projected debt-free date.

## Domain model

```
DebtAccount  (source of truth for every debt)
 ├── protected/serviced  — home loan, insurance loan, ... (pay normally)
 └── settlement          — unsecured accounts in the clearance pipeline
      └── SettlementCase
           ├── SettlementOffer        (claim x % + fee + GST breakdown)
           ├── SettlementContribution (savings building the fund)
           ├── SettlementPayment      (the cash-out that closes the debt)
           └── SettlementDocument     (notices, offer letters, NOC...)
DebtStrategy      — the plan layer (allocation, priority method)
DebtSnapshot      — point-in-time balance readings
IncomeScenario    — salary/increment scenarios feeding projections
```

The core distinction: **a settlement is not an expense category.** It is
a debt-resolution event that eventually produces one or more cash
transactions (recorded by `SettlementPaymentService`, optionally
mirrored into the expense ledger under the "Debt Settlement" category).

## The money math (SettlementCalculator)

```
Settlement amount = claim × settlement %
Service fee       = claim × service fee %        (fee is on the CLAIM)
GST               = service fee × GST %
Total cost        = settlement amount + service fee + GST
```

Example — claim ₹1,00,000 @ 45%, fee 15%, GST 18%:

| Settlement | Fee     | GST    | Total    |
|-----------:|--------:|-------:|---------:|
| ₹45,000    | ₹15,000 | ₹2,700 | ₹62,700  |

`SettlementCalculator.scenarios` renders the full 20–45% ladder. All
arithmetic runs on integer paise with BigDecimal ratios (half-up), and
monetary columns use the money-rails `monetize` macro:

```ruby
monetize :claim_amount_paise, as: :claim_amount   # => Money (INR)
```

## Queue stages (DebtQueueRanker)

| Stage | Meaning            | Rule                                        |
|------:|--------------------|---------------------------------------------|
| 1     | legal_opportunity  | formal notice received or active negotiation |
| 2     | small_balance      | claim ≤ ₹25,000 (quick wins)                 |
| 3     | medium_balance     | claim ≤ ₹1,00,000                            |
| 4     | large_unsecured    | claim > ₹1,00,000                            |

Within a stage a 0–100 score ranks cases:
readiness (30) + cash required (20) + debt size (15) + cashflow impact
(15) + legal status (15) + account age (5).

## Case state machine

```
drafting -> funding -> negotiation -> offer_received -> agreed
        -> paying -> settled -> closed        (stalled from anywhere)
```

A case becomes **eligible to negotiate** once its settlement fund
covers `eligibility_threshold_percentage` (default 50%) of the
estimated maximum cost.

## API (all under /api/v1, JWT auth)

| Endpoint | Purpose |
|---|---|
| `GET/POST/PATCH/DELETE /debt_accounts` | debt registry CRUD |
| `POST /debt_accounts/:id/snapshot` | record balance reading |
| `GET/POST/PATCH/DELETE /settlement_cases` | settlement pipeline |
| `GET /settlement_cases/:id` | case detail + offers + scenario table |
| `POST /settlement_cases/:id/record_payment` | close the settlement |
| `POST /settlement_cases/:id/settlement_offers` | record offer (auto fee/GST math) |
| `PATCH /settlement_cases/:case_id/settlement_offers/:id` | edit / `{ "status": "accepted" }` to accept |
| `POST /settlement_cases/:id/settlement_contributions` | fund the case |
| `POST/GET/DELETE /settlement_cases/:id/settlement_documents` | notice/receipt/NOC files |
| `GET /debt_dashboard/overview` | totals, fund, pipeline, cashflow, debt-free date |
| `GET /debt_dashboard/forecast?monthly_allocation=` | projected settlement dates |
| `GET /debt_dashboard/simulate_settlement?amount=100000` | "what can I settle with ₹X?" |
| `GET/POST/PATCH /debt_strategies` + `PATCH :id/set_default` | strategy layer |
| `GET/POST/PATCH /income_scenarios` + `PATCH :id/activate` | salary scenarios |

Money arrives as major-unit numbers (`currentBalance: 64888`) and is
stored as integer paise internally.

## AI tools

The assistant gained: `debt_overview`, `settlement_queue`,
`settle_with_amount`, `debt_forecast`, `compare_settlement_scenarios`,
`add_settlement_contribution` — try *"What can I settle with ₹75,000?"*
or *"Compare settling IDFC at 25/30/35/40%."*

## Frontend

`/debt-clearance` — Debt Clearance dashboard (pipeline, cashflow,
simulator, registry) built with React Query + shadcn/ui + recharts.

## Running the tests

```bash
bundle install          # picks up money-rails
bin/rails db:migrate
bin/rails test test/services/settlement_calculator_test.rb \
               test/services/debt_queue_ranker_test.rb \
               test/services/settlement_simulator_test.rb \
               test/services/debt_forecast_engine_test.rb \
               test/services/settlement_payment_service_test.rb \
               test/models/settlement_offer_test.rb
```
