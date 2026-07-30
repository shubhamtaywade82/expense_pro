class AddPersonaToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :persona, :string, default: "mixed", null: false
    add_index :users, :persona
  end
end
