class CreateDhanCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :dhan_credentials do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :client_id
      t.string :token_service_url
      t.text :token_service_secret
      t.text :fallback_access_token

      t.timestamps
    end
  end
end
