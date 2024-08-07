class AddCountryAndCurrencyToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :country, :string
    add_column :users, :currency, :string
  end
end
