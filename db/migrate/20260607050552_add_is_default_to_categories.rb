class AddIsDefaultToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :is_default, :boolean, null: false, default: false
  end
end
