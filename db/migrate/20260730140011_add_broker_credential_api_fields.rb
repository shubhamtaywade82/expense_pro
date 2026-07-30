class AddBrokerCredentialApiFields < ActiveRecord::Migration[8.0]
  def change
    change_table :broker_credentials do |t|
      t.text :api_key
      t.text :api_secret
      t.string :api_passphrase
    end
  end
end
