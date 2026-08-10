class AddUnifiedBrokerFieldsToBrokerCredentials < ActiveRecord::Migration[8.0]
  def change
    change_table :broker_credentials, bulk: true do |t|
      t.integer  :status, default: 0, null: false
      t.text     :access_token
      t.text     :refresh_token
      t.text     :passphrase
      t.jsonb    :config, default: {}, null: false
      t.datetime :token_expires_at
      t.datetime :last_authenticated_at
      t.datetime :last_sync_at
    end

    # The column defaulted to "dhan", which is not a key in BrokerCredential's
    # broker_type enum (the adapter registers itself as "dhanhq").
    reversible do |dir|
      dir.up   { execute "UPDATE broker_credentials SET broker_type = 'dhanhq' WHERE broker_type = 'dhan'" }
      dir.down { execute "UPDATE broker_credentials SET broker_type = 'dhan' WHERE broker_type = 'dhanhq'" }
    end
    change_column_default :broker_credentials, :broker_type, from: "dhan", to: "dhanhq"
  end
end
