# Income System Overhaul — Complete Implementation Plan

## Status: Backend Phase 1 already done
`income_type` enum, `gross_amount`, `tax_deducted`, `pf_deducted`, `other_deductions`, `metadata` columns already exist in schema. TaxCalculatorService already splits by income_type.

## Phase 1: Frontend — Income Type UI

### 1.1 Types (`frontend/src/types/index.ts`)
Replace the `Income` type to add `incomeType`, `grossAmount`, `taxDeducted`, `pfDeducted`, `otherDeductions`, `employmentId`. Add new types `Employment`, `SalaryComponent`, `TaxDeduction`.

### 1.2 Income dialog (`frontend/src/pages/Income.tsx`)
**Form state** (line 66-79): Add `incomeType`, `grossAmount`, `taxDeducted`, `pfDeducted`, `otherDeductions`

**Dialog** (around line 337-338): After the source/amount/date grid, add:

```tsx
{/* Income Category */}
<div>
  <Label className="text-sm font-medium">Income Category</Label>
  <Select value={form.incomeType} onValueChange={(v) => setForm({ ...form, incomeType: v })}>
    <SelectTrigger className="mt-1"><SelectValue placeholder="Select category" /></SelectTrigger>
    <SelectContent>
      <SelectItem value="salary">Salary / Employment</SelectItem>
      <SelectItem value="freelance">Freelance / Consulting</SelectItem>
      <SelectItem value="bonus">Bonus / Incentive</SelectItem>
      <SelectItem value="fnf_settlement">FNF Settlement</SelectItem>
      <SelectItem value="interest">Interest Income</SelectItem>
      <SelectItem value="rental">Rental Income</SelectItem>
      <SelectItem value="other">Other Income</SelectItem>
    </SelectContent>
  </Select>
</div>

{/* Gross Amount (show for salary/freelance) */}
{(form.incomeType === "salary" || form.incomeType === "freelance") && (
  <div className="p-3 rounded-xl bg-muted/30 border space-y-2">
    <p className="text-xs font-medium text-muted-foreground">Salary Structure</p>
    <div className="grid grid-cols-2 gap-3">
      <div>
        <Label className="text-xs">Gross / CTC Amount (₹)</Label>
        <Input type="number" step="0.01" className="mt-1" value={form.grossAmount} onChange={(e) => setForm({...form, grossAmount: e.target.value})} />
      </div>
      <div>
        <Label className="text-xs">Net Take-Home (₹)</Label>
        {form.grossAmount && (
          <p className="mt-2 text-sm font-semibold">₹{formatCurrency(parseFloat(form.amount))}</p>
        )}
      </div>
    </div>
    {form.incomeType === "salary" && (
      <div className="grid grid-cols-3 gap-2 pt-1">
        <div>
          <Label className="text-[10px] text-muted-foreground">TDS Deducted</Label>
          <Input type="number" step="0.01" className="mt-0.5 h-8 text-xs" value={form.taxDeducted} onChange={(e) => setForm({...form, taxDeducted: e.target.value})} />
        </div>
        <div>
          <Label className="text-[10px] text-muted-foreground">PF Deducted</Label>
          <Input type="number" step="0.01" className="mt-0.5 h-8 text-xs" value={form.pfDeducted} onChange={(e) => setForm({...form, pfDeducted: e.target.value})} />
        </div>
        <div>
          <Label className="text-[10px] text-muted-foreground">Other Deductions</Label>
          <Input type="number" step="0.01" className="mt-0.5 h-8 text-xs" value={form.otherDeductions} onChange={(e) => setForm({...form, otherDeductions: e.target.value})} />
        </div>
      </div>
    )}
  </div>
)}
```

**handleSubmit** (line 199-212): Add `incomeType`, `grossAmount`, `taxDeducted`, `pfDeducted`, `otherDeductions` to payload.

**handleEdit** (line 226-239): Set `incomeType`, `grossAmount`, `taxDeducted`, `pfDeducted`, `otherDeductions` from the income being edited.

**resetForm** (line 171-189): Reset the new fields.

**Income list rendering** (find the income card/item): Add an income type badge next to the source name, e.g.:
```tsx
{inc.incomeType && inc.incomeType !== "salary" && (
  <Badge className="text-[10px] h-5 bg-purple-500/10 text-purple-600 border-purple-500/30">
    {inc.incomeType.replace("_", " ")}
  </Badge>
)}
```

### 1.3 API (`frontend/src/lib/api.ts`)
Add imports for new types, add `employments`, `salaryComponents`, `taxDeductions` objects to the api client.

---

## Phase 3: Employment Tracking

### 3.1 Migration
```ruby
# db/migrate/TIMESTAMP_create_employments.rb
class CreateEmployments < ActiveRecord::Migration[7.1]
  def change
    create_table :employments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :employer_name, null: false
      t.string :designation
      t.date :start_date, null: false
      t.date :end_date
      t.boolean :is_current, default: false
      t.decimal :monthly_ctc, precision: 14, scale: 2
      t.string :pan_of_employer
      t.timestamps
    end
    add_index :employments, [:user_id, :is_current]
    add_index :employments, [:user_id, :start_date]
  end
end
```

### 3.2 Migration — add employment_id to incomes
```ruby
# db/migrate/TIMESTAMP_add_employment_to_incomes.rb
class AddEmploymentToIncomes < ActiveRecord::Migration[7.1]
  def change
    add_reference :incomes, :employment, foreign_key: true
  end
end
```

### 3.3 Model (`app/models/employment.rb`)
```ruby
class Employment < ApplicationRecord
  belongs_to :user
  has_many :incomes, dependent: :nullify

  validates :employer_name, presence: true
  validates :start_date, presence: true
  validate :end_date_after_start_date

  scope :current, -> { where(is_current: true) }
  scope :past, -> { where(is_current: false).where.not(end_date: nil) }
  scope :chronological, -> { order(start_date: :desc) }

  def fnf_settlement?
    !is_current? && end_date.present?
  end

  def duration_months
    return nil if start_date.nil?
    end_d = end_date || Date.current
    ((end_d.year * 12 + end_d.month) - (start_date.year * 12 + start_date.month))
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end
```

### 3.4 Income model update (`app/models/income.rb`)
Add:
```ruby
belongs_to :employment, optional: true
```

### 3.5 Controller (`app/controllers/api/v1/employments_controller.rb`)
```ruby
module Api
  module V1
    class EmploymentsController < BaseController
      before_action :set_employment, only: [:update, :destroy]

      def index
        render json: current_user.employments.chronological.includes(:incomes)
      end

      def create
        employment = current_user.employments.build(employment_params)
        employment.save!
        render json: employment, status: :created
      end

      def update
        @employment.update!(employment_params)
        render json: @employment
      end

      def destroy
        @employment.destroy!
        head :no_content
      end

      private

      def set_employment
        @employment = current_user.employments.find(params[:id])
      end

      def employment_params
        params.permit(:employer_name, :designation, :start_date, :end_date, :is_current, :monthly_ctc, :pan_of_employer)
      end
    end
  end
end
```

### 3.6 Routes (`config/routes.rb`)
Add:
```ruby
resources :employments, only: [:index, :create, :update, :destroy]
```

### 3.7 Frontend — Employment section in Income.tsx
Add to the Income page header (after the tab navigation or as a dialog):
- "Employment History" button that opens an employment list/modal
- Each employment shows: employer name, dates, CTC, current/past badge
- Add/Edit/Delete employment dialog
- When an employment is added: optionally auto-create salary income records

---

## Phase 2: Salary Structure / CTC

### 2.1 Migration
```ruby
# db/migrate/TIMESTAMP_create_salary_components.rb
class CreateSalaryComponents < ActiveRecord::Migration[7.1]
  def change
    create_table :salary_components do |t|
      t.references :income, null: false, foreign_key: true
      t.string :component_type, null: false  # basic, hra, lta, special_allowance, employer_pf, employee_pf, gratuity, medical, other
      t.decimal :amount, precision: 14, scale: 2, null: false, default: 0
      t.boolean :is_employer_contribution, default: false
      t.timestamps
    end
    add_index :salary_components, [:income_id, :component_type], unique: true
  end
end
```

### 2.2 Model (`app/models/salary_component.rb`)
```ruby
class SalaryComponent < ApplicationRecord
  COMPONENT_TYPES = %w[basic hra lta special_allowance employer_pf employee_pf gratuity medical_allowance other].freeze

  belongs_to :income

  validates :component_type, presence: true, inclusion: { in: COMPONENT_TYPES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :component_type, uniqueness: { scope: :income_id }

  scope :earnings, -> { where(is_employer_contribution: false) }
  scope :deductions, -> { where(is_employer_contribution: true) }
end
```

### 2.3 Income model update (`app/models/income.rb`)
Add:
```ruby
has_many :salary_components, dependent: :destroy
accepts_nested_attributes_for :salary_components, allow_destroy: true
```

### 2.4 Controller (`app/controllers/api/v1/salary_components_controller.rb`)
```ruby
module Api
  module V1
    class SalaryComponentsController < BaseController
      def index
        income = current_user.incomes.find(params[:income_id])
        render json: income.salary_components
      end

      def create
        income = current_user.incomes.find(params[:income_id])
        component = income.salary_components.build(component_params)
        component.save!
        render json: component, status: :created
      end

      def update
        component = current_user.incomes.joins(:salary_components).find(salary_components: { id: params[:id] })
        component.update!(component_params)
        render json: component
      end

      def destroy
        component = SalaryComponent.find(params[:id])
        component.destroy!
        head :no_content
      end

      private

      def component_params
        params.permit(:component_type, :amount, :is_employer_contribution)
      end
    end
  end
end
```

### 2.5 Service (`app/services/hra_exemption_service.rb`)
```ruby
class HraExemptionService
  def initialize(income)
    @income = income
  end

  def call
    components = @income.salary_components.index_by(&:component_type)
    hra_received = components["hra"]&.amount.to_f
    basic = components["basic"]&.amount.to_f
    rent_paid = @income.metadata&.dig("monthly_rent").to_f
    metro = @income.metadata&.dig("metro_city") != false

    return 0 if hra_received <= 0 || basic <= 0

    # Minimum of:
    # 1. Actual HRA received
    # 2. Rent paid - 10% of basic
    # 3. 50% of basic (metro) / 40% (non-metro)
    exemption = [
      hra_received,
      [rent_paid - (0.1 * basic), 0].max,
      metro ? (0.5 * basic) : (0.4 * basic)
    ].min

    exemption.round(2)
  end
end
```

### 2.6 Frontend — Salary structure dialog
In Income.tsx, when editing a salary income:
- "Salary Breakup" button that opens a dialog
- Shows: Basic (%), HRA (%), LTA (%), Special Allowance, Employee PF (%), Employer PF, Gratuity
- Percentage inputs auto-calculate amounts from gross
- Total should match gross_amount
- HRA exemption calculator with rent input + metro toggle

---

## Phase 4: Tax Deduction Tracking

### 4.1 Migration
```ruby
# db/migrate/TIMESTAMP_create_tax_deductions.rb
class CreateTaxDeductions < ActiveRecord::Migration[7.1]
  def change
    create_table :tax_deductions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :income, foreign_key: true
      t.string :deduction_type, null: false  # tds, advance_tax, self_assessment
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :deduction_date, null: false
      t.string :section  # 192, 194J, 194C, 194A, etc.
      t.string :notes
      t.timestamps
    end
    add_index :tax_deductions, [:user_id, :deduction_type]
    add_index :tax_deductions, [:user_id, :deduction_date]
  end
end
```

### 4.2 Model (`app/models/tax_deduction.rb`)
```ruby
class TaxDeduction < ApplicationRecord
  DEDUCTION_TYPES = %w[tds advance_tax self_assessment].freeze

  belongs_to :user
  belongs_to :income, optional: true

  validates :deduction_type, presence: true, inclusion: { in: DEDUCTION_TYPES }
  validates :amount, numericality: { greater_than: 0 }
  validates :deduction_date, presence: true

  scope :tds, -> { where(deduction_type: "tds") }
  scope :advance_tax, -> { where(deduction_type: "advance_tax") }
  scope :self_assessment, -> { where(deduction_type: "self_assessment") }
  scope :for_fy, ->(year) {
    start_d = Date.new(year - 1, 4, 1)
    end_d = Date.new(year, 3, 31)
    where(deduction_date: start_d..end_d)
  }
end
```

### 4.3 Income model update (`app/models/income.rb`)
Add:
```ruby
has_many :tax_deductions, dependent: :nullify
```

### 4.4 Controller (`app/controllers/api/v1/tax_deductions_controller.rb`)
```ruby
module Api
  module V1
    class TaxDeductionsController < BaseController
      before_action :set_deduction, only: [:update, :destroy]

      def index
        deductions = if params[:financial_year].present?
          fy = params[:financial_year].to_i
          current_user.tax_deductions.for_fy(fy)
        else
          current_user.tax_deductions
        end
        render json: deductions.order(deduction_date: :desc)
      end

      def create
        deduction = current_user.tax_deductions.build(deduction_params)
        deduction.save!
        render json: deduction, status: :created
      end

      def update
        @deduction.update!(deduction_params)
        render json: @deduction
      end

      def destroy
        @deduction.destroy!
        head :no_content
      end

      private

      def set_deduction
        @deduction = current_user.tax_deductions.find(params[:id])
      end

      def deduction_params
        params.permit(:income_id, :deduction_type, :amount, :deduction_date, :section, :notes)
      end
    end
  end
end
```

### 4.5 Routes
```ruby
resources :tax_deductions, only: [:index, :create, :update, :destroy]
```

### 4.6 TaxCalculatorService update
The `tds_paid` calculation currently sums `tax_deducted` from incomes. Update it to also include `TaxDeduction.tds` records:
```ruby
tds_from_incomes = incomes.sum { |inc| inc.tax_deducted.to_f }
tds_from_tracker = @user.tax_deductions.for_fy(@year).tds.sum(:amount)
tds_paid = tds_from_incomes + tds_from_tracker
```

Also add advance_tax and self_assessment to the output:
```ruby
advance_tax_paid = @user.tax_deductions.for_fy(@year).advance_tax.sum(:amount)
self_assessment_paid = @user.tax_deductions.for_fy(@year).self_assessment.sum(:amount)
total_tax_paid = tds_paid + advance_tax_paid + self_assessment_paid

# In the result hash:
tax_paid_summary: {
  tds: tds_paid,
  advance_tax: advance_tax_paid,
  self_assessment: self_assessment_paid,
  total: total_tax_paid
},
tax_due_or_refund: total_tax_new - total_tax_paid  # for recommended regime
```

### 4.7 Frontend — TDS tracking section in Income.tsx
- "Tax Deductions" tab or section
- List of TDS/advance tax/self-assessment entries for the current FY
- Add/Edit/Delete dialog
- Summary: total TDS deducted, advance tax paid, self-assessment tax, net tax paid

### 4.8 ITR page updates (`frontend/src/pages/ITR.tsx`)
- Add "Tax Paid Summary" card showing TDS, advance tax, self-assessment
- Show "Tax Due / Refund" based on total_tax - total_tax_paid
- Color coding: green for refund, red for tax due

---

## Phase 5: FNF Settlement + Bonus Business Logic

### 5.1 Service (`app/services/fnf_settlement_service.rb`)
```ruby
class FnfSettlementService
  def initialize(employment)
    @employment = employment
    @user = employment.user
  end

  def calculate
    return nil unless @employment.fnf_settlement?

    components = estimate_salary_components
    last_basic = components[:basic]
    years_of_service = (@employment.duration_months / 12.0).floor

    {
      employer: @employment.employer_name,
      last_working_day: @employment.end_date,
      years_of_service: years_of_service,
      monthly_ctc: @employment.monthly_ctc,
      estimated_components: components,
      gratuity_estimate: calculate_gratuity(last_basic, years_of_service),
      leave_encashment_estimate: calculate_leave_encashment(last_basic),
      notice_period_deduction: 0,  # user-provided
      bonus_payout: 0               # user-provided
    }
  end

  def suggest_fnf_income(settlement_data)
    total_amount = settlement_data[:gratuity_estimate] +
                   settlement_data[:leave_encashment_estimate] +
                   settlement_data[:bonus_payout] -
                   settlement_data[:notice_period_deduction]

    @user.incomes.build(
      source: "FNF Settlement - #{@employment.employer_name}",
      amount: total_amount,
      gross_amount: total_amount,
      income_type: "fnf_settlement",
      income_date: @employment.end_date || Date.current,
      frequency: "one_time",
      is_recurring: false,
      employment: @employment,
      notes: "Full & Final settlement from #{@employment.employer_name}. " \
             "Service: #{settlement_data[:years_of_service]}yrs. " \
             "Gratuity: ₹#{settlement_data[:gratuity_estimate]}, " \
             "Leave encashment: ₹#{settlement_data[:leave_encashment_estimate]}"
    )
  end

  private

  def estimate_salary_components
    ctc = @employment.monthly_ctc.to_f
    return { basic: 0, hra: 0, pf: 0, gratuity: 0 } if ctc <= 0

    # Typical Indian salary structure ratios
    basic = (ctc * 0.40).round(2)
    {
      basic: basic,
      hra: (basic * 0.50).round(2),
      pf: (basic * 0.12).round(2),
      gratuity: (basic * 0.0481).round(2)
    }
  end

  def calculate_gratuity(last_basic, years)
    return 0 if years < 5 || last_basic <= 0
    # Gratuity = (15 × last_basic × years) / 26
    ((15 * last_basic * years) / 26.0).round(2)
  end

  def calculate_leave_encashment(last_basic)
    return 0 if last_basic <= 0
    # Assuming 30 unused leave days (user should adjust)
    (last_basic / 30.0 * 30).round(2)
  end
end
```

### 5.2 Employment controller — add `fnf_settlement` action
Add to `EmploymentsController`:
```ruby
def fnf_settlement
  employment = current_user.employments.find(params[:id])
  service = FnfSettlementService.new(employment)
  render json: service.calculate
end
```

Route:
```ruby
get "employments/:id/fnf_settlement", to: "employments#fnf_settlement"
```

### 5.3 Frontend — When ending an employment
In the employment dialog, when `is_current` is set to false and `end_date` is set:
- Show "Generate FNF Settlement" button
- Calls `api.employments.fnfSettlement(id)`
- Shows estimated gratuity, leave encashment, notice period deduction
- "Create FNF Income" button that creates a one-time income with fnf_settlement type

---

## Execution Order

1. Run all 3 migrations (`create_employments`, `add_employment_to_incomes`, `create_salary_components`, `create_tax_deductions`)
2. Create Employment model + controller + routes
3. Update Income model (belongs_to :employment, has_many :salary_components, has_many :tax_deductions, accepts_nested_attributes)
4. Create SalaryComponent model + controller + routes + HraExemptionService
5. Create TaxDeduction model + controller + routes
6. Update TaxCalculatorService to use TaxDeduction records
7. Create FnfSettlementService + employment fnf_settlement endpoint
8. Update frontend types, api.ts, Income.tsx, ITR.tsx
9. Run `rails db:migrate` + `rails test`
10. Run `npx tsc --noEmit` in frontend
