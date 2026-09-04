# Point-in-time balance/Dpd readings for a DebtAccount. Used for trend
# lines ("is the claim growing?") and for reconciling statements against
# what the user last recorded.
class CreateDebtSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :debt_snapshots do |t|
      t.references :debt_account, null: false, foreign_key: true
      t.date    :recorded_on, null: false
      t.bigint  :balance_paise, null: false, default: 0
      t.integer :dpd, null: false, default: 0
      t.string  :source, default: "manual"   # manual | statement | notice | credit_report
      t.text    :notes

      t.timestamps
    end

    add_index :debt_snapshots, [:debt_account_id, :recorded_on]
  end
end
