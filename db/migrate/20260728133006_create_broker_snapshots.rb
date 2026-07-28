class CreateBrokerSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :broker_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.string :broker, null: false
      t.string :kind, null: false # "holding" | "position"
      t.string :security_id, null: false
      t.string :trading_symbol
      t.jsonb :data, null: false, default: {}
      t.datetime :synced_at, null: false

      t.timestamps
    end

    add_index :broker_snapshots, %i[user_id broker kind security_id],
              unique: true,
              name: "index_broker_snapshots_on_user_broker_kind_security"
  end
end
