module Api
  module V1
    # Offers on the table for a settlement case. Amount breakdowns are
    # recomputed by the model (SettlementCalculator) on every save, so the
    # controller only passes through claim + percentage + terms metadata.
    class SettlementOffersController < BaseController
      before_action :set_case

      def create
        offer = @case.settlement_offers.create!(offer_params)
        render_camel_json offer_payload(offer), status: :created
      end

      def update
        offer = @case.settlement_offers.find(params[:id])

        if accept_request?(offer)
          offer.accept!
        else
          offer.update!(offer_params)
        end

        render_camel_json offer_payload(offer.reload)
      end

      private

      def set_case
        @case = current_user.settlement_cases.find(params[:settlement_case_id])
      end

      def offer_params
        permitted = params.permit(:offered_on, :claim_amount, :settlement_percentage,
                                  :valid_until, :status, :reference_number, :notes)

        permitted[:claim_amount_paise] = paise(permitted.delete(:claim_amount)) if permitted.key?(:claim_amount)
        permitted[:offered_on] = parse_date(permitted[:offered_on]) || Date.current if permitted.key?(:offered_on)
        permitted[:valid_until] = parse_date(permitted[:valid_until]) if permitted.key?(:valid_until)

        permitted
      end

      # PATCH with { status: "accepted" } accepts the offer and stamps the
      # acceptance date; any other update is a normal edit (e.g. counter).
      def accept_request?(offer)
        offer_params[:status] == "accepted" && offer_params.except(:status).blank?
      end

      def offer_payload(offer)
        offer.as_json.merge(
          "claimAmount" => offer.claim_amount.to_f,
          "settlementPercentage" => offer.settlement_percentage.to_f,
          "settlementAmount" => offer.settlement_amount.to_f,
          "serviceFee" => offer.service_fee.to_f,
          "gst" => offer.gst.to_f,
          "totalAmount" => offer.total_amount.to_f,
          "expired" => offer.expired?
        )
      end

      def paise(value)
        (value.to_f * 100).round
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error
        nil
      end
    end
  end
end
