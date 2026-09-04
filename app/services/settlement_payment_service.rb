# frozen_string_literal: true

# Orchestrates a settlement payment end to end. Recording the cash-out is
# NOT just creating a row — it must also:
#
#   1. accept the chosen offer (when one is attached),
#   2. advance the case state machine (paying -> settled),
#   3. zero out the debt account and mark it settled,
#   4. optionally mirror the outflow into the expense ledger so monthly
#      reports and budgets keep seeing the full picture.
#
# Keeping this in one service stops callers from half-recording a
# settlement (e.g. payment without account closure).
class SettlementPaymentService
  EXPENSE_CATEGORY_NAME = "Debt Settlement"

  class << self
    def record(user:, settlement_case:, settlement_offer: nil, paid_on: Date.current,
               settlement_amount_paise: nil, service_fee_paise: nil, gst_paise: nil,
               payment_mode: "neft", reference_number: nil, notes: nil, sync_to_expenses: true)
      offer = settlement_offer
      amounts = amounts_from(offer, settlement_case, settlement_amount_paise, service_fee_paise, gst_paise)

      payment = nil
      ActiveRecord::Base.transaction do
        offer&.accept!

        payment = SettlementPayment.create!(
          user: user,
          settlement_case: settlement_case,
          settlement_offer: offer,
          paid_on: paid_on,
          settlement_amount_paise: amounts[:settlement_amount_paise],
          service_fee_paise: amounts[:service_fee_paise],
          gst_paise: amounts[:gst_paise],
          total_paid_paise: amounts[:total_paise],
          payment_mode: payment_mode,
          reference_number: reference_number,
          notes: notes
        )

        settlement_case.mark_settled! unless settlement_case.settled?
        sync_expense(user, settlement_case, payment, amounts) if sync_to_expenses
      end

      { success: true, payment: payment }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, error: e.record.errors.full_messages.to_sentence }
    end

    private

    # Prefer the offer's own frozen numbers; otherwise compute from the
    # case's current claim and terms; otherwise take explicit paise.
    def amounts_from(offer, settlement_case, settlement_amount_paise, service_fee_paise, gst_paise)
      if offer
        {
          settlement_amount_paise: offer.settlement_amount_paise,
          service_fee_paise: offer.service_fee_paise,
          gst_paise: offer.gst_paise,
          total_paise: offer.total_amount_paise
        }
      else
        result = SettlementCalculator.call(
          claim_paise: settlement_case.current_claim_paise,
          settlement_percentage: settlement_case.target_max_percentage,
          service_fee_percentage: settlement_case.service_fee_percentage,
          gst_percentage: settlement_case.gst_percentage
        )
        {
          settlement_amount_paise: settlement_amount_paise || result[:settlement_amount_paise],
          service_fee_paise: service_fee_paise || result[:service_fee_paise],
          gst_paise: gst_paise || result[:gst_paise],
          total_paise: result[:total_paise]
        }
      end
    end

    # One classified expense per settlement keeps reporting honest: the
    # outflow lands under a dedicated category instead of drowning in
    # generic spending.
    def sync_expense(user, settlement_case, payment, amounts)
      category = user.categories.find_or_create_by!(name: EXPENSE_CATEGORY_NAME) do |c|
        c.category_type = "expense"
        c.icon = "landmark"
        c.color = "#ef4444"
      end

      Expense.create!(
        user: user,
        category: category,
        amount: amounts[:total_paise] / 100.0,
        expense_date: payment.paid_on,
        payment_method: "net_banking",
        description: "Settlement — #{settlement_case.debt_account.name} (case ##{settlement_case.id})"
      )
      payment.update!(synced_to_expenses: true)
    end
  end
end
