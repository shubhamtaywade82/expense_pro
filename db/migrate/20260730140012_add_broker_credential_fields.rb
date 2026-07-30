class AddBrokerCredentialFields < ActiveRecord::Migration[8.0]
  def change
    add_column :broker_credentials, :broker_type, :string, default: "dhan", null: false
    add_column :trades, :broker_type, :string, default: "securities", null: false
  end
end
