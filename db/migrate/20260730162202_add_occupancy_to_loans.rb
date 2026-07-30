class AddOccupancyToLoans < ActiveRecord::Migration[8.0]
  def change
    add_column :loans, :occupancy, :string, default: "self_occupied"
  end
end
