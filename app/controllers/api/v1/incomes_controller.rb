module Api
  module V1
    class IncomesController < BaseController
      before_action :set_income, only: [ :update, :destroy, :toggle_received ]

      def index
        if params[:month].present? && params[:year].present?
          start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
          incomes = IncomeProjectionService.new(current_user, start_date, start_date.end_of_month, include_parent: true).call
          render json: IncomeBlueprint.render_as_hash(incomes)
        elsif params[:year].present?
          start_date = Date.new(params[:year].to_i, 1, 1)
          end_date = Date.new(params[:year].to_i, 12, 31)
          incomes = IncomeProjectionService.new(current_user, start_date, end_date, include_parent: true).call
          render json: IncomeBlueprint.render_as_hash(incomes)
        else
          render json: IncomeBlueprint.render_as_hash(current_user.incomes.includes(:parent, :tax_deductions).recent_first)
        end
      end

      def summary
        if params[:month].present? && params[:year].present?
          start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
          incomes = IncomeProjectionService.new(current_user, start_date, start_date.end_of_month).call
        elsif params[:year].present?
          start_date = Date.new(params[:year].to_i, 1, 1)
          end_date = Date.new(params[:year].to_i, 12, 31)
          incomes = IncomeProjectionService.new(current_user, start_date, end_date).call
        else
          incomes = current_user.incomes.includes(:parent).to_a
        end

        total = incomes.sum { |inc| inc.amount.to_f }
        received = incomes.select(&:is_received).sum { |inc| inc.amount.to_f }
        expected = total - received

        render json: { total: total.to_s, count: incomes.count, received: received, expected: expected }
      end

      def yearly
        year = (params[:year] || Date.current.year).to_i
        start_date = Date.new(year, 1, 1)
        end_date = Date.new(year, 12, 31)

        all_incomes = IncomeProjectionService.new(current_user, start_date, end_date).call

        months_summary = (1..12).map do |m|
          m_start = Date.new(year, m, 1)
          m_end = m_start.end_of_month
          m_incomes = all_incomes.select { |inc| inc.income_date >= m_start && inc.income_date <= m_end }

          total = m_incomes.sum { |inc| inc.amount.to_f }
          received = m_incomes.select(&:is_received).sum { |inc| inc.amount.to_f }
          expected = total - received

          {
            month: m,
            month_name: m_start.strftime("%b"),
            full_month_name: m_start.strftime("%B"),
            total: total,
            received: received,
            expected: expected,
            count: m_incomes.count,
            incomes: m_incomes
          }
        end

        total_year_income = months_summary.sum { |ms| ms[:total] }
        total_year_received = months_summary.sum { |ms| ms[:received] }

        render json: {
          year: year,
          total_income: total_year_income,
          total_received: total_year_received,
          months: months_summary
        }
      end

      def create
        income = current_user.incomes.build(income_params)
        income.save!
        render json: IncomeBlueprint.render_as_hash(income), status: :created
      end

      def update
        @income.update!(income_params)
        render json: IncomeBlueprint.render_as_hash(@income)
      end

      def destroy
        @income.destroy!
        head :no_content
      end

      def toggle_received
        @income.update!(is_received: !@income.is_received)
        render json: IncomeBlueprint.render_as_hash(@income)
      end

      private

      def set_income
        @income = current_user.incomes.find(params[:id])
      end

      def income_params
        params.permit(:source, :amount, :income_date, :is_recurring, :frequency, :notes, :parent_id, :is_received, :end_date, :is_custom, :change_reason, :original_amount, :income_type, :gross_amount, :tax_deducted, :pf_deducted, :other_deductions, :employment_id, metadata: {})
      end
    end
  end
end
