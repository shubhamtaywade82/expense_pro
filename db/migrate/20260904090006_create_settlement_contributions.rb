# Money the user sets aside towards a future settlement. These build the
# "settlement fund" that makes a case eligible for negotiation; they are
# savings, not expenses, and never hit the expense ledger directly.
class CreateSettlementContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :settlement_contributions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :settlement_case, null: false, foreign_key: true

      t.date   :contributed_on, null: false
      t.bigint :amount_paise, null: false, default: 0
      t.string :source, default: "salary"   # salary / bonus / increment / other income
      t.string :reference
      t.text   :notes

      t.timestamps
    end

    add_index :settlement_contributions, [:settlement_case_id, :contributed_on], name: "idx_settl_contrib_case_on_date"
    add_index :settlement_contributions, [:user_id, :contributed_on]
  end
end
