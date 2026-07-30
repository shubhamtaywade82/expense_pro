class IncomeBlueprint < Blueprinter::Base
  identifier :id

  fields :source, :amount, :income_date, :is_recurring, :frequency, :notes,
         :is_received, :parent_id, :income_type, :gross_amount, :tax_deducted,
         :pf_deducted, :other_deductions, :created_at, :updated_at

  field :is_custom do |income|
    income.is_custom || (income.parent_id.present? && income.amount != income.parent&.amount)
  end

  field :change_reason do |income|
    income.change_reason
  end

  field :original_amount do |income|
    income.base_amount.to_s
  end

  field :amount_difference do |income|
    income.amount_difference
  end

  field :is_latest_recurring do |income|
    income.latest_recurring?
  end

  field :is_ongoing do |income|
    income.ongoing?
  end

  field :gap_info do |income|
    income.gap_info
  end

  association :tax_deductions, blueprint: TaxDeductionBlueprint, default: []

  view :extended do
    association :parent, blueprint: IncomeBlueprint
  end
end
