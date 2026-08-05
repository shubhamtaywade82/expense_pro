# db/migrate/20250804120000_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notifiable, polymorphic: true, null: true
      t.string :subject, null: false
      t.text :message, null: false
      t.string :category, null: false, default: 'info' # tax, cash_flow, investment, info
      t.boolean :read, default: false, null: false
      t.boolean :archived, default: false, null: false
      t.jsonb :payload, default: {}, null: false
      t.timestamp :viewed_at
      t.timestamp :read_at
      t.timestamps

      t.index [:user_id, :read]
      t.index [:user_id, :archived]
      t.index [:user_id, :created_at], order: { created_at: :desc }
      t.index :category
    end

    add_index :notifications, :payload, using: :gin
  end
end
