class EmiSchedule < ApplicationRecord
  belongs_to :loan_account

  scope :for_fy, ->(year) {
    y = year.to_i
    where(due_date: Date.new(y - 1, 4, 1)..Date.new(y, 3, 31))
  }
end
