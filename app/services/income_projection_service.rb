class IncomeProjectionService
  def initialize(user, month, year)
    @user = user
    @month = month.to_i
    @year = year.to_i
    @start_date = Date.new(@year, @month, 1)
    @end_date = @start_date.end_of_month
  end

  def call
    real_incomes = @user.incomes.where(income_date: @start_date..@end_date).to_a
    templates = @user.incomes.templates.where("income_date <= ?", @end_date)

    projections = []

    templates.each do |template|
      # Check if this template should have an entry this month
      # For now, we handle monthly, quarterly, and yearly.
      # Weekly is skipped or handled as monthly for simplicity unless requested.
      next unless occurs_in_month?(template)

      # Check if there's already an instance for this month
      # An instance is a record with parent_id = template.id 
      # OR a record with same source and is_recurring = false (if we want to be loose, but parent_id is better)
      has_instance = real_incomes.any? { |inc| inc.parent_id == template.id }
      next if has_instance

      # Also check if the template itself is in this month
      # If the template record's income_date is in this month, we don't need a projection
      # because the template record IS the record for this month.
      next if template.income_date >= @start_date && template.income_date <= @end_date

      projections << build_projection(template)
    end

    (real_incomes + projections).sort_by { |inc| [inc.income_date, inc.id || 0] }.reverse
  end

  private

  def occurs_in_month?(template)
    return false if template.income_date > @end_date
    
    case template.frequency
    when 'monthly'
      true
    when 'quarterly'
      months_diff = (@year * 12 + @month) - (template.income_date.year * 12 + template.income_date.month)
      months_diff >= 0 && months_diff % 3 == 0
    when 'yearly'
      template.income_date.month == @month
    when 'weekly'
      # For weekly, we could have multiple. For now, let's just show it if any week lands here.
      # To keep it simple and fulfill "Salary" (monthly) focus, we'll just return true.
      true
    else
      false
    end
  end

  def build_projection(template)
    day = [template.income_date.day, @end_date.day].min
    projected_date = Date.new(@year, @month, day)

    # Return a non-persisted record
    income = @user.incomes.build(
      source: template.source,
      amount: template.amount,
      income_date: projected_date,
      is_recurring: true,
      frequency: template.frequency,
      notes: template.notes,
      parent_id: template.id,
      is_received: false
    )
    
    # We add a virtual attribute to help the frontend
    income.define_singleton_method(:id) { nil }
    income
  end
end
