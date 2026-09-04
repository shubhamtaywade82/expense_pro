# DebtStrategy is the missing layer between "I owe X" (DebtAccount) and
# "this is how I eliminate it" (queue, funding, forecast). A user keeps
# one default strategy that drives the settlement queue and forecasts.
class CreateDebtStrategies < ActiveRecord::Migration[8.0]
  def change
    create_table :debt_strategies do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :name, null: false
      t.integer :strategy_type, null: false, default: 0     # normal_repayment / settlement / hybrid
      t.bigint  :monthly_allocation_paise, null: false, default: 0
      t.date    :target_date
      t.integer :priority_method, null: false, default: 0   # smallest_balance / highest_interest / ...
      t.string  :status, null: false, default: "active"     # active / paused / completed
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :debt_strategies, [:user_id, :is_default]
  end
end
