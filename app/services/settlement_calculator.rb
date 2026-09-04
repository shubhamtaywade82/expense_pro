# frozen_string_literal: true

# Pure money math for the Freed-style settlement model. Single source of
# truth for every rupee in the debt clearance domain.
#
#   Settlement amount = claim × settlement %
#   Service fee       = claim × service fee %        (fee is on the CLAIM)
#   GST               = service fee × GST %
#   Total cost        = settlement amount + service fee + GST
#
# Example (claim ₹1,00,000 @ 45%, fee 15%, GST 18%):
#   settlement ₹45,000 + fee ₹15,000 + GST ₹2,700 = ₹62,700
#
# All arithmetic runs on integer paise with BigDecimal ratios and rounds
# half-up to the nearest paisa, so results are stable and float-free.
class SettlementCalculator
  # The comparison ladder the UI renders by default.
  DEFAULT_PERCENTAGES = [20, 25, 30, 35, 40, 45].freeze

  class << self
    def call(claim_paise:, settlement_percentage:, service_fee_percentage: 15.0, gst_percentage: 18.0)
      claim = claim_paise.to_i
      pct = settlement_percentage.to_d
      fee_pct = service_fee_percentage.to_d
      gst_pct = gst_percentage.to_d

      settlement_amount = (claim * pct / 100).round
      service_fee = (claim * fee_pct / 100).round
      gst = (service_fee * gst_pct / 100).round

      {
        claim_paise: claim,
        settlement_percentage: pct,
        settlement_amount_paise: settlement_amount,
        service_fee_paise: service_fee,
        gst_paise: gst,
        total_paise: settlement_amount + service_fee + gst
      }
    end

    # The scenario table: what does each settlement level really cost?
    def scenarios(claim_paise:, percentages: DEFAULT_PERCENTAGES, service_fee_percentage: 15.0, gst_percentage: 18.0)
      percentages.map do |pct|
        call(
          claim_paise: claim_paise,
          settlement_percentage: pct,
          service_fee_percentage: service_fee_percentage,
          gst_percentage: gst_percentage
        )
      end
    end

    # Convenience for display layers: paise -> major-unit floats.
    def to_major(result)
      result.transform_values { |v| v.is_a?(Integer) ? (v / 100.0) : v }
    end
  end
end
