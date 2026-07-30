class FixVersionsTable < ActiveRecord::Migration[8.0]
  def up
    remove_column :versions, "{:null=>false}" if column_exists?(:versions, "{:null=>false}")
    change_column_null :versions, :item_type, false
  end

  def down
    change_column_null :versions, :item_type, true
  end
end
