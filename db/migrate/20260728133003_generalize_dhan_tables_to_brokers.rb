class GeneralizeDhanTablesToBrokers < ActiveRecord::Migration[8.0]
  def change
    rename_table :dhan_access_tokens, :broker_access_tokens
    rename_table :dhan_credentials, :broker_credentials

    add_column :broker_access_tokens, :broker, :string, null: false, default: "dhan"
    add_column :broker_credentials, :broker, :string, null: false, default: "dhan"

    add_index :broker_access_tokens, %i[user_id broker]
    remove_index :broker_credentials, :user_id, unique: true
    add_index :broker_credentials, %i[user_id broker], unique: true
  end
end
