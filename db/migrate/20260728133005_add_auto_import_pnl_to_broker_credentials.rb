class AddAutoImportPnlToBrokerCredentials < ActiveRecord::Migration[8.0]
  def change
    add_column :broker_credentials, :auto_import_pnl, :boolean, null: false, default: false
  end
end
