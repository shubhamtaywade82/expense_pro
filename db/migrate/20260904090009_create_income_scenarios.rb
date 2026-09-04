# Salary/income scenarios power the "what changes after appraisal?"
# projections: current vs appraisal vs aggressive savings rates. One
# scenario is active at a time and feeds the capital & forecast engines.
class CreateIncomeScenarios < ActiveRecord::Migration[8.0]
  def change
    create_table :income_scenarios do |t|
      t.references :user, null: false, foreign_key: true

      t.string  :name, null: false
      t.integer :scenario_type, null: false, default: 5  # current / conservative / base / appraisal / aggressive / custom
      t.date    :effective_on, null: false

      t.bigint  :monthly_income_paise, null: false, default: 0
      t.bigint  :monthly_commitments_paise, null: false, default: 0
      t.bigint  :settlement_allocation_paise, null: false, default: 0
      t.bigint  :buffer_allocation_paise, null: false, default: 0

      t.boolean :is_active, null: false, default: false
      t.text    :notes

      t.timestamps
    end

    add_index :income_scenarios, [:user_id, :is_active]
    add_index :income_scenarios, [:user_id, :scenario_type]
  end
end
