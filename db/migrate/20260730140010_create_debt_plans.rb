class CreateDebtPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :debt_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :strategy, null: false, default: "avalanche"
      t.decimal :monthly_extra, precision: 14, scale: 2, default: 0.0
      t.string :status, null: false, default: "active"
      t.jsonb :loan_priorities, default: []
      t.date :projected_payoff_date
      t.decimal :total_interest_saved, precision: 14, scale: 2, default: 0.0
      t.timestamps
    end

    add_index :debt_plans, :status
    add_index :debt_plans, :strategy
  end
end
