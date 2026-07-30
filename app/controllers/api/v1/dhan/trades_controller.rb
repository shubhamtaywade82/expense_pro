require "csv"

module Api
  module V1
    module Dhan
      class TradesController < BaseController
        def orders
          render json: DhanDataService.new.orders
        end

        def trade_book
          render json: DhanDataService.new.trade_book
        end

        def trade_history
          from = params[:from_date] || 30.days.ago.to_date.to_s
          to = params[:to_date] || Date.current.to_s
          result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
          render json: { trades: result[:trades], truncated: result[:truncated] }
        end

        def import
          from = params.require(:from_date)
          to = params.require(:to_date)
          result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
          if result[:truncated]
            render json: { error: "Too many trades in this range — import per month instead" },
                   status: :unprocessable_entity
            return
          end
          count = DhanTradeImportService.new(current_user, result[:trades]).call
          render json: { imported: count, from_date: from, to_date: to }
        end

        def pnl_report
          from = params[:from_date] || 30.days.ago.to_date.to_s
          to = params[:to_date] || Date.current.to_s
          format = params[:format]

          trades = current_user.trades
            .for_broker("dhan")
            .for_period(from, to)
            .recent_first

          rows = trades.map { |t| trade_report_row(t) }
          summary = compute_report_summary(rows)

          respond_to do |format|
            format.json { render json: { from_date: from, to_date: to, trades: rows, summary: summary } }
            format.csv { render plain: generate_csv(rows), content_type: "text/csv" }
          end
        end

        private

        def trade_report_row(t)
          {
            trade_date: t.trade_date&.strftime("%d-%m-%Y"),
            symbol: t.display_symbol,
            security_id: t.security_id,
            isin: t.isin,
            exchange_segment: t.exchange_segment,
            product_type: t.product_type,
            instrument: t.instrument,
            transaction_type: t.transaction_type,
            quantity: t.traded_quantity&.to_f,
            price: t.traded_price&.to_f,
            total_value: t.total_value,
            brokerage: t.brokerage.to_f,
            stt: t.stt.to_f,
            gst: t.gst.to_f,
            sebi_tax: t.sebi_tax.to_f,
            exchange_charges: t.exchange_charges.to_f,
            stamp_duty: t.stamp_duty.to_f,
            total_charges: t.total_charges,
            net_value: t.net_value,
            expiry: t.expiry_date&.strftime("%d-%m-%Y"),
            strike_price: t.strike_price&.to_f,
            option_type: t.option_type,
            segment: t.segment_key
          }
        end

        def compute_report_summary(rows)
          summary = Hash.new { |h, k| h[k] = { buy_value: 0.0, sell_value: 0.0, charges: 0.0, net_pnl: 0.0, trade_count: 0 } }

          rows.each do |row|
            seg = row[:segment]
            summary[seg][:trade_count] += 1
            summary[seg][:charges] += row[:total_charges].to_f

            if row[:transaction_type] == "BUY"
              summary[seg][:buy_value] += row[:total_value].to_f
            else
              summary[seg][:sell_value] += row[:total_value].to_f
            end
          end

          summary.each do |_seg, s|
            s[:net_pnl] = (s[:sell_value] - s[:buy_value] - s[:charges]).round(2)
            s.transform_values! { |v| v.is_a?(Float) ? v.round(2) : v }
          end

          summary
        end

        def generate_csv(rows)
          headers = %w[Trade_Date Symbol Security_ID ISIN Segment Product_Type Instrument Type Quantity Price Total_Value Brokerage STT GST SEBI_Tax Exchange_Charges Stamp_Duty Total_Charges Net_Value Expiry Strike Option_Type]
          CSV.generate(headers: true) do |csv|
            csv << headers
            rows.each { |r| csv << r.values_at(*headers.map(&:underscore).map(&:to_sym)) }
          end
        end
      end
    end
  end
end
