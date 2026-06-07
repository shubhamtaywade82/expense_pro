class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category_type, null: false, default: "expense"
      t.string :icon, null: false, default: "wallet"
      t.string :color, null: false, default: "#6366f1"

      t.timestamps
    end

    add_index :categories, [ :user_id, :category_type ]
    add_index :categories, [ :user_id, :name ], unique: true
  end
end
