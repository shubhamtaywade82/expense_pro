class AddBrokerImportKeyToInvestments < ActiveRecord::Migration[8.0]
  def change
    add_column :investments, :broker_import_key, :string
    add_index :investments, %i[user_id broker_import_key],
              unique: true,
              where: "broker_import_key IS NOT NULL",
              name: "index_investments_on_user_and_broker_import_key"
  end
end
