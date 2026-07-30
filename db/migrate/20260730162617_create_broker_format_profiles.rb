class CreateBrokerFormatProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :broker_format_profiles do |t|
      t.references :user, null: true, foreign_key: true
      t.string :broker_name
      t.jsonb :mapping
      t.jsonb :normalization
      t.boolean :approved

      t.timestamps
    end
  end
end
