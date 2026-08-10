class AddTaxpayerIdentityToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users, bulk: true do |t|
      t.string :pan
      t.date   :date_of_birth
    end
  end
end
