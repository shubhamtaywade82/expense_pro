# ExpensePro

ExpensePro tracks loans, credit cards, and discretionary spending for Indian retail investors. The backend is Rails 8 on Ruby 3.3 with Postgres, Redis, and Sidekiq.

## Setup
1. Copy `.env.example` to `.env` and adjust the connection strings for your environment.
2. Install dependencies with `bundle install` and `yarn install`.
3. Create and migrate the database: `bin/rails db:create db:migrate`.
4. Start the application with `bin/dev`.

## Domain Model
The finance ledger is organised around the following entities:

- **Users** (UUID primary keys) store profile data, including monthly income.
- **Institutions** catalogue lenders/issuers.
- **Accounts** wrap both loans and credit cards with utilisation snapshots.
- **LoanDetail** and **CreditCardDetail** add per-product attributes.
- **CardEmiPlan**, **RepaymentSchedule**, and **Payment** model the repayment calendar and settlements.
- **Statements** and **CardTransactions** provide optional card statement ingestion.
- **Expenses** capture discretionary spends outside the repayment calendar.

All money fields now use decimal columns with precision 15 and scale 2 to keep the database human-readable while preserving rounding safety. Utilisation ratios are stored as precision 8, scale 4 decimals to avoid lossy basis-point conversions. Key scopes on `Account`, `RepaymentSchedule`, and `Expense` power the dashboard and summaries.

## Dashboard Metrics
`User` exposes helpers for due, paid, and expense totals across daily, weekly, monthly, and lifetime periods, plus a portfolio-wide card utilisation ratio. The dashboard view renders these aggregates directly without additional services.

## Product Walkthrough
Follow this flow to understand how a household finance manager would operate the app in production:

1. **First-time setup**
   - Create a Devise account, set your time zone, and record monthly income so DTI math has a baseline.
   - Add institutions for each lender/issuer, then open accounts (loan or credit card) with basic metadata such as masked number, status, and open date.
   - Attach product details: fill loan principal/outstanding/EMI or credit-card limit/outstanding/statement and due days. Optionally import CSV exports from Google Sheets via *Settings → Import*; the preview maps columns before persisting.
   - When accounts are saved, the system generates repayment schedules for the current and next month automatically.

2. **Daily rhythm**
   - Land on the dashboard to review tiles for due today/this week, total paid, expenses, card utilisation, and DTI.
   - Open the 14-day upcoming table to confirm obligations. When you clear a payment, hit **Mark Payment**, capture amount/date/method, and the dashboard refreshes instantly.

3. **Weekly review**
   - Use the repayment calendar filtered to *This Week* to tackle EMIs and card dues, logging payments directly from each row.
   - Audit credit-card utilisation; if a card climbs above 70%, convert a portion to an EMI plan so future dues smooth out.
   - Batch enter discretionary spends under **Expenses**, or import a CSV if you track them externally.

4. **Month-end wrap**
   - Record credit-card statements (balance, minimum due) so next-cycle dues are pre-seeded.
   - Explore the summary selector (Day/Week/Month/All) to evaluate due vs. paid vs. expenses, Savings Estimate (income − obligations), DTI, and utilisation trends.
   - Prepay loans or create card EMI plans as needed; the repayment calendar and risk ratios adjust automatically.

5. **Navigation cheatsheet**
   - *Dashboard*: summary tiles, charts, quick payment actions.
   - *Accounts*: dedicated tables for loans and cards with actions for payments and EMI conversions; card EMI plans mirror the Google Sheet tab.
   - *Repayment Calendar*: status/type filters, bulk mark-paid, and CSV export.
   - *Expenses*: quick add/import, category breakdowns, optional monthly caps.
   - *Reports*: due vs. paid vs. expense trends plus utilisation/DTI leaders.
   - *Settings*: income/time-zone preferences, import/export, institution admin, notification toggles.

6. **Notifications & safeguards**
   - Emails/Telegram alerts fire 3 days before due dates, on overdue detection, and when utilisation or DTI crosses configured thresholds.
   - Payment ingestion, schedule generation, and utilisation recalculations run in Sidekiq with transactional guards to keep ledger state ACID.

7. **Typical workflows**
   - *Record today’s EMI*: dashboard → row action **Mark Payment** → submit details → observe Paid This Month/DTI refresh.
   - *Convert a card charge to EMI*: accounts → card → **Convert to EMI** → define amount, tenure, rate → app seeds plan and repayment entries.
   - *Capture rent & utilities*: expenses → **Add Expense** → choose category, amount, date → dashboard expense tile updates.

8. **Data export**
   - Repayment schedules, payments, accounts, and expenses all provide CSV export for reconciliation or migration.

9. **Security posture**
   - Row-level scoping ensures a user only sees their own ledger.
   - All financial mutations use database transactions with decimal money fields (precision 15, scale 2) and UTC timestamps; presentation respects the user’s time zone.

## Tests
RSpec is the preferred test framework. Add specs under `spec/` and run them with `bundle exec rspec` once the suite is in place.
