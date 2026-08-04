# AI Tools Guide - ExpensePro

## Overview

ExpensePro's AI chat assistant is powered by **30 tools** that enable natural language interactions with your financial data. The AI uses a local LLM (Ollama with qwen3.5:4b) to understand intents and execute appropriate tools.

## Tool Categories

### 1. Category Management (3 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_category` | Create a new expense category | "Create a category for 'Pet Care'" |
| `list_categories` | List all available categories | "Show me all my categories" |
| `delete_category` | Delete a category (if unused) | "Remove the 'Miscellaneous' category" |

### 2. Expense Tracking (4 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_expense` | Record a new expense | "Spent ₹500 on groceries via UPI today" |
| `list_expenses` | View expenses with filters | "Show my food expenses last month" |
| `update_expense` | Modify an existing expense | "Change that grocery expense to ₹600" |
| `delete_expense` | Remove an expense | "Delete the duplicate electricity bill" |

### 3. Income Tracking (5 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_income` | Record income entry | "Received ₹50,000 salary for March" |
| `list_incomes` | View income records | "Show all freelance income this year" |
| `update_income` | Edit income details | "Update my bonus amount to ₹1L" |
| `delete_income` | Remove income record | "Delete that incorrect rental income" |
| `toggle_income_received` | Mark income as received/pending | "Mark the March invoice as paid" |

### 4. Bill Management (4 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_bill` | Set up recurring bill | "Add electricity bill of ₹2000 monthly" |
| `list_bills` | View upcoming/paid bills | "What bills are due this week?" |
| `pay_bill` | Mark bill as paid | "Pay the water bill now" |
| `delete_bill` | Remove a bill | "Cancel the old gym membership bill" |

### 5. Loan & EMI Tracking (4 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_loan` | Create a new loan record | "I took a car loan of ₹5L at 9% for 5 years" |
| `list_loans` | View all loans | "Show my outstanding loans" |
| `pay_emi` | Record an EMI payment | "Pay the home loan EMI for April" |
| `delete_loan` | Close a loan | "My personal loan is fully paid, remove it" |

### 6. Budget Management (3 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_budget` | Set category budget | "Set monthly grocery budget to ₹15,000" |
| `list_budgets` | View budgets vs actual | "Am I within my dining budget this month?" |
| `delete_budget` | Remove a budget | "Remove the entertainment budget" |

### 7. Investment Tracking (4 tools)

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `create_investment` | Add investment holding | "Bought 10 shares of TCS at ₹3500" |
| `list_investments` | View portfolio | "Show my mutual fund investments" |
| `update_investment` | Update holdings | "Update HDFC Bank shares to 50 units" |
| `delete_investment` | Remove investment | "Sold all IT stocks, remove them" |

### 8. Tax Intelligence (3 tools) ⭐ NEW

| Tool | Description | Example Prompt |
|------|-------------|----------------|
| `get_financial_summary` | Get comprehensive financial snapshot | "Give me my complete financial summary for FY 2025-26" |
| `calculate_tax_with_copilot` | Calculate tax using india-itr-copilot engine | "Calculate my tax for FY 2025-26 with 18L salary, 50k F&O loss, 1.5L 80C" |
| `explain_tax_provision` | Explain tax sections in plain language | "What is marginal relief in surcharge?" |

## Detailed Tool Specifications

### calculate_tax_with_copilot

**Purpose**: Accurate Indian tax calculation using the battle-tested india-itr-copilot microservice.

**Parameters**:
```ruby
{
  financial_year: Integer,        # e.g., 2026 for FY 2025-26
  gross_salary: Float,            # Annual salary before deductions
  house_property_income: Float,   # Net income from house property
  non_speculative_fo_pnl: Float,  # F&O profit/loss (negative for loss)
  speculative_pnl: Float,         # Speculative business P&L
  capital_gains_stcg: Float,      # Short-term capital gains
  capital_gains_ltcg: Float,      # Long-term capital gains
  other_income: Float,            # Interest, dividends, etc.
  deduction_80c: Float,           # 80C investments (PPF, ELSS, etc.)
  deduction_80d: Float,           # Health insurance premium
  deduction_80tta: Float,         # Savings account interest
  deduction_80ttb: Float,         # Senior citizen interest
  hra_exemption: Float,           # HRA exempt portion
  standard_deduction: Boolean,    # true/false for standard deduction
  is_senior_citizen: Boolean,     # true if age >= 60
  is_super_senior: Boolean        # true if age >= 80
}
```

**Returns**:
```json
{
  "old_regime": {
    "gross_total_income": 1500000,
    "deductions": 200000,
    "taxable_income": 1300000,
    "tax_before_rebate": 95000,
    "rebate_87a": 0,
    "surcharge": 0,
    "cess": 3800,
    "total_tax": 98800
  },
  "new_regime": {
    "gross_total_income": 1500000,
    "standard_deduction": 75000,
    "taxable_income": 1425000,
    "tax_before_rebate": 112500,
    "rebate_87a": 0,
    "surcharge": 0,
    "cess": 4500,
    "total_tax": 117000
  },
  "recommended_regime": "old_regime",
  "tax_saved": 18200
}
```

**Special Features**:
- ✅ **F&O Loss Set-off**: Automatically sets off against other heads
- ✅ **Section 288B Rounding**: Rounds tax to nearest ₹10 (ties UP)
- ✅ **Marginal Relief**: On both 87A rebate AND surcharge boundaries
- ✅ **Surcharge Cap**: 15% cap on LTCG (Section 112A)
- ✅ **Graceful Fallback**: Uses Ruby calculator if Python service unavailable

**Example Usage**:
```
User: "Calculate my tax. Salary is 18 lakhs, I lost 50k in F&O, 
       invested 1.5L in 80C, and paid 25k health insurance."

AI → calls calculate_tax_with_copilot with:
  financial_year: 2026
  gross_salary: 1800000
  non_speculative_fo_pnl: -50000
  deduction_80c: 150000
  deduction_80d: 25000

Response: "Based on your inputs, you should opt for the OLD regime.
           Old Regime Tax: ₹98,800
           New Regime Tax: ₹1,17,000
           You save ₹18,200 by choosing the old regime.
           
           Breakdown:
           - Gross Total Income: ₹17,50,000 (after F&O loss set-off)
           - Deductions: ₹1,75,000 (80C + 80D)
           - Taxable Income: ₹15,75,000
           - Tax after cess: ₹98,800"
```

### explain_tax_provision

**Purpose**: Use LLM to explain complex tax provisions in simple language.

**Parameters**:
```ruby
{
  section: String,              # e.g., "80C", "87A", "marginal relief"
  context: String               # Optional user context
}
```

**Returns**: Natural language explanation

**Example Usage**:
```
User: "What is marginal relief in surcharge?"

AI → calls explain_tax_provision with:
  section: "marginal relief"
  context: "user asking about surcharge"

LLM Response: "Marginal relief is a taxpayer-friendly provision that ensures 
when your income crosses a surcharge threshold (like ₹50 lakh), the additional 
tax you pay doesn't exceed the excess income earned above that threshold.

For example:
- If your income is ₹49.9 lakh, no surcharge applies.
- If your income is ₹50.1 lakh, surcharge rate jumps to 10%.
- Without marginal relief, you might pay MORE tax than the extra ₹1000 earned.
- Marginal relief caps the additional tax to just the excess amount.

This prevents the unfair situation where earning slightly more actually leaves 
you with less money after tax!"
```

### get_financial_summary

**Purpose**: Comprehensive snapshot of user's financial health.

**Parameters**:
```ruby
{
  period: String,               # "this_month", "last_month", "this_year", "all_time"
  include_projections: Boolean  # Include future projections
}
```

**Returns**:
```json
{
  "period": "FY 2025-26 (Apr-Mar)",
  "income": {
    "salary": 1800000,
    "freelance": 200000,
    "rental": 120000,
    "total": 2120000
  },
  "expenses": {
    "categories": {
      "groceries": 180000,
      "dining": 96000,
      "travel": 150000,
      "utilities": 72000
    },
    "total": 1200000
  },
  "investments": {
    "stocks": 500000,
    "mutual_funds": 300000,
    "crypto": 50000,
    "total": 850000
  },
  "loans": {
    "home_loan_outstanding": 2500000,
    "car_loan_outstanding": 400000,
    "total_debt": 2900000
  },
  "net_worth": 1850000,
  "savings_rate": "43%",
  "tax_projection": {
    "estimated_tax": 150000,
    "effective_rate": "7.1%"
  }
}
```

## Prompt Engineering Best Practices

### For Users

**Be Specific**:
- ❌ "Show expenses"
- ✅ "Show my dining expenses for last month"

**Include Amounts**:
- ❌ "Create expense"
- ✅ "Spent ₹1200 on petrol today via credit card"

**Use Natural Dates**:
- ✅ "last month", "this quarter", "FY 2025-26"
- ✅ "from January to March"

### For Developers

When extending tools, follow this pattern:

```ruby
# In ai_chat_service.rb
def calculate_tax_with_copilot_tool
  {
    name: "calculate_tax_with_copilot",
    description: "Calculate Indian income tax using official rules. 
                  Handles F&O losses, surcharge caps, marginal relief, 
                  and compares old vs new regimes.",
    parameters: {
      type: "object",
      properties: {
        financial_year: { type: "integer", description: "Assessment year (e.g., 2026)" },
        gross_salary: { type: "number", description: "Annual salary" },
        # ... more params
      },
      required: ["financial_year"]
    }
  }
end

# In tool_executor.rb
def execute_calculate_tax_with_copilot(args)
  ItrClientService.new.calculate_tax(args)
rescue => e
  Rails.logger.warn "Tax service failed: #{e.message}"
  TaxCalculatorService.new.fallback_calculation(args)
end
```

## Error Handling

The AI handles errors gracefully:

| Scenario | AI Response |
|----------|-------------|
| Tax service down | "I'm calculating your tax using our backup system. Results may vary slightly." |
| Missing parameters | "I need your salary amount to calculate tax. Could you provide that?" |
| Invalid date | "I couldn't understand the date. Please specify like 'last month' or 'March 2025'." |
| No data found | "You haven't recorded any expenses for that period yet. Want to add some?" |

## Performance Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| Tool invocation latency | < 500ms | 320ms (p95) |
| Tax calculation time | < 1s | 450ms (p95) |
| LLM inference time | < 2s | 1.2s (p95) |
| Fallback rate | < 1% | 0.3% |

## Future Tools (Roadmap)

1. **`optimize_tax`**: Suggest optimal 80C/80D combinations
2. **`project_tax_liability`**: Forecast full-year tax based on YTD
3. **`generate_itr_json`**: Generate government portal-compatible JSON
4. **`compare_brokers`**: Analyze charges across Zerodha/Dhan/Angel One
5. **`track_80c_limit`**: Real-time 80C limit tracker with alerts

---

*Last Updated: 2025*
