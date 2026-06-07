# frozen_string_literal: true

class IncomeProjectionService
  def initialize(user, start_date, end_date)
    @user = user
    @start_date = start_date.to_date
    @end_date = end_date.to_date
  end

  def call
    real_incomes = @user.incomes.where(income_date: @start_date..@end_date).to_a
    templates = @user.incomes.templates
                      .where("income_date <= ?", @end_date)
                      .where("end_date IS NULL OR end_date >= ?", @start_date)

    projections = []
    templates.each do |template|
      months_in_range.each do |month_start|
        next unless occurs_in_month?(template, month_start)
        next if already_exists?(template, real_incomes, month_start)

        projection = build_projection(template, month_start)
        next if template.end_date.present? && projection.income_date > template.end_date

        projections << projection
      end
    end

    (real_incomes + projections).sort_by { |inc| [ inc.income_date, inc.id || 0 ] }.reverse
  end

  private

  def months_in_range
    (@start_date.beginning_of_month..@end_date.beginning_of_month).select { |d| d.day == 1 }.uniq
  end

  def already_exists?(template, real_incomes, month_start)
    month_end = month_start.end_of_month
    
    # Check if template record itself is in this month
    return true if template.income_date >= month_start && template.income_date <= month_end
    
    # Check if there is an instance for this template in this month
    real_incomes.any? { |inc| inc.parent_id == template.id && inc.income_date >= month_start && inc.income_date <= month_end }
  end

  def occurs_in_month?(template, month_start)
    return false if template.income_date > month_start.end_of_month

    case template.frequency
    when "monthly"
      true
    when "quarterly"
      months_diff = (month_start.year * 12 + month_start.month) - (template.income_date.year * 12 + template.income_date.month)
      months_diff >= 0 && (months_diff % 3).zero?
    when "yearly"
      template.income_date.month == month_start.month
    when "weekly"
      true
    else
      false
    end
  end

  def build_projection(template, month_start)
    day = [ template.income_date.day, month_start.end_of_month.day ].min
    projected_date = month_start.change(day: day)

    Income.new(
      user: @user,
      source: template.source,
      amount: template.amount,
      income_date: projected_date,
      is_recurring: true,
      frequency: template.frequency,
      notes: template.notes,
      parent_id: template.id,
      is_received: false
    )
  end
end
