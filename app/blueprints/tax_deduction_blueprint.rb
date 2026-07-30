class TaxDeductionBlueprint < Blueprinter::Base
  identifier :id
  fields :deduction_type, :amount, :description, :created_at, :updated_at
end
