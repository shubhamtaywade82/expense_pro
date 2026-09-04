# SettlementCase represents the user's participation in ONE settlement
# process for a DebtAccount. It holds the negotiated terms (fee %, GST %,
# target range), the funding plan, and the pipeline state.
#
# A settlement is NOT an expense category — it is a debt-resolution event
# that eventually produces cash movements (see SettlementPayment).
class CreateSettlementCases < ActiveRecord::Migration[8.0]
  def change
    create_table :settlement_cases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :debt_account, null: false, foreign_key: true

      t.date    :started_on, null: false

      # What the creditor claims vs what they claim right now (claims grow).
      t.bigint  :original_claim_paise, null: false, default: 0
      t.bigint  :current_claim_paise, null: false, default: 0

      # Negotiation terms — configurable per case, not hard-coded.
      t.integer :target_min_percentage, null: false, default: 20
      t.integer :target_max_percentage, null: false, default: 45
      t.decimal :service_fee_percentage, precision: 5, scale: 2, null: false, default: "15.0"
      t.decimal :gst_percentage, precision: 5, scale: 2, null: false, default: "18.0"

      # Funding plan: how much the user can pile into this case monthly and
      # what share of the projected cost must be saved before negotiating.
      t.bigint  :monthly_contribution_paise, null: false, default: 0
      t.integer :eligibility_threshold_percentage, null: false, default: 50

      t.integer :status, null: false, default: 0    # drafting..closed
      t.integer :stage, null: false, default: 4     # queue stage 1..4 (see DebtQueueRanker)
      t.integer :priority, null: false, default: 1  # low / normal / high / critical
      t.date    :closed_on
      t.text    :notes

      t.timestamps
    end

    add_index :settlement_cases, [:user_id, :status]
    add_index :settlement_cases, [:user_id, :stage]
  end
end
