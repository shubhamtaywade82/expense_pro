class AddBrokerCredentialFields < ActiveRecord::Migration[8.0]
  def change
    change_table :broker_credentials do |t|
      t.text :api_key
      t.text :api_secret
      t.string :api_passphrase
      t.string :broker_type, default: "dhan", null: false
    end

    add_column :trades, :broker_type, :string, default: "securities", null: false
  end
end
