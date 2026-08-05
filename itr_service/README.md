# ExpensePro ITR Engine

Python microservice for accurate Indian income tax calculation, wrapping the [india-itr-copilot](https://github.com/caesar0301/india-itr-copilot) tax engine.

## Why a Microservice?

Instead of rewriting the battle-tested Python tax logic in Ruby, we run it as a separate service that ExpensePro calls over HTTP. This gives us:

- **Accuracy**: 25 hand-verified test cases, registry-driven rules
- **Maintainability**: Update tax rules via JSON files (no code changes needed)
- **Isolation**: Tax bugs can't crash document upload or broker sync
- **Speed**: Deploy tax updates independently

## Features Implemented

| Feature | Description |
|---------|-------------|
| **Head-based computation** | F&O loss set-off with carry-forward rules |
| **Surcharge + 15% CG cap** | Component-wise surcharge calculation |
| **Marginal relief** | On 87A rebate AND all surcharge boundaries |
| **Section 288B rounding** | Nearest ₹10, ties rounded UP |
| **Chapter VI-A deductions** | Full 80D structured buckets, 80TTA/B, HRA |
| **Interest calculator** | 234A/B/C/F with senior exemption, deferred-income relief |
| **Rules registry** | One JSON per AY, source-cited |

## API Endpoints

### `POST /calculate`
Calculate tax for both regimes and get recommendation.

```json
{
  "assessment_year": "2026-27",
  "income": {
    "gross_salary": 1800000,
    "freelance_income": 200000,
    "non_speculative_fo_pnl": -150000,
    "stcg_111a": 300000,
    "ltcg_112a": 200000
  },
  "deductions": {
    "section_80c": 150000,
    "section_80d_self": 25000,
    "home_loan_interest": 180000
  },
  "taxpayer": {"age": 32},
  "tds_paid": 280000
}
```

### `GET /compare-regimes?gross_income=1500000&assessment_year=AY2026-27`
Quick comparison for simple salary income.

### `GET /rules/{assessment_year}`
Get tax rules configuration for an assessment year.

### `GET /health`
Health check endpoint.

## Running Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the service
uvicorn app:app --reload --port 8000
```

## Running with Docker

```bash
docker-compose up itr_service
```

## Configuration

| Env Var | Default | Description |
|---------|---------|-------------|
| `COPILOT_ROOT` | `/app` | Root directory for rules files |
| `PORT` | `8000` | Service port |

## Adding New Assessment Years

1. Create `rules/AY20XX-YY.json` based on Finance Act
2. Follow the existing JSON structure
3. No code changes needed!

Example:
```json
{
  "assessment_year": "2027-28",
  "new_regime": {
    "slabs": [...],
    "standard_deduction": 80000
  }
}
```

## Integration with ExpensePro

The Ruby service `ItrClientService` handles:
- Building request payloads from User data
- HTTP communication with retry logic
- Parsing responses into ExpensePro format
- Graceful fallback to Ruby calculator if service is down

## Testing

```bash
# Test health
curl http://localhost:8000/health

# Test calculation
curl -X POST http://localhost:8000/calculate \
  -H "Content-Type: application/json" \
  -d @test_payload.json
```

## License

MIT (inherits from india-itr-copilot)
