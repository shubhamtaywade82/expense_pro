# frozen_string_literal: true

# The source of truth for every debt the user owes — protected loans that
# are serviced normally AND unsecured accounts targeted for settlement.
#
# Domain rules:
#   * A DebtAccount never IS a settlement — the settlement process lives in
#     SettlementCase. The account only records what is owed and to whom.
#   * When linked to a LoanAccount/Loan, current_balance can be refreshed
#     from the amortization data; standalone (collection) accounts are
#     maintained via DebtSnapshots.
class DebtAccount < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :loan_account, optional: true
  belongs_to :loan, optional: true

  has_many :debt_snapshots, dependent: :destroy
  has_many :settlement_cases, dependent: :destroy

  validates :name, presence: true
  validates :dpd, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate  :only_one_loan_link

  enum :debt_type, {
    personal_loan: 0, credit_card: 1, nbfc_loan: 2, home_loan: 3,
    auto_loan: 4, education_loan: 5, gold_loan: 6, business_loan: 7, other: 8
  }

  # "serviced" accounts are protected debt (paid normally); "settlement"
  # accounts are the unsecured pool the clearance pipeline works through.
  enum :classification, { serviced: 0, settlement: 1 }

  enum :status, {
    current: 0, overdue: 1, in_negotiation: 2,
    charged_off: 3, settled: 4, closed: 5
  }

  monetize :original_principal_paise, as: :original_principal,
           numericality: { greater_than_or_equal_to: 0 }
  monetize :current_balance_paise, as: :current_balance,
           numericality: { greater_than_or_equal_to: 0 }
  monetize :monthly_obligation_paise, as: :monthly_obligation, allow_nil: true

  scope :open, -> { where.not(status: %i[settled closed]) }
  scope :protected_pool, -> { serviced.open }
  scope :settlement_pool, -> { settlement.open }
  scope :by_balance_desc, -> { order(current_balance_paise: :desc) }

  # Records a fresh balance reading and moves the account's balance forward.
  def record_snapshot!(balance_paise:, dpd: 0, recorded_on: Date.current, source: "manual", notes: nil)
    transaction do
      debt_snapshots.create!(
        balance_paise: balance_paise, dpd: dpd,
        recorded_on: recorded_on, source: source, notes: notes
      )
      update!(current_balance_paise: balance_paise, dpd: dpd)
    end
    self
  end

  # Pulls the outstanding principal from the linked amortized loan, when
  # there is one, so the debt overview stays consistent with EMIs paid.
  def sync_balance_from_loan!
    source = loan_account || loan
    return self if source.nil?

    outstanding = source.outstanding_principal.to_money(:inr)
    record_snapshot!(balance_paise: outstanding.cents, source: "amortization")
  end

  # Monthly cash the account demands right now: EMI for serviced loans,
  # minimum due / planned provision for settlement accounts. When the
  # obligation was never maintained but the loan is linked, fall back to
  # the amortized EMI so cashflow math never silently drops a debt.
  def monthly_cashflow_demand
    return monthly_obligation.to_f if monthly_obligation_paise.present? && monthly_obligation_paise.positive?

    linked = loan_account || loan
    linked.try(:emi_amount).to_f
  end

  def age_in_months
    return 0 if first_defaulted_on.nil?

    ((Date.current - first_defaulted_on) / 30.44).floor
  end

  private

  def only_one_loan_link
    if loan_account_id.present? && loan_id.present?
      errors.add(:base, "Link the debt to either a LoanAccount or a Loan, not both")
    end
  end
end
