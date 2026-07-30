class CreateEmployments < ActiveRecord::Migration[8.0]
  def change
    create_table :employments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :employer_name, null: false
      t.string :designation
      t.date :start_date, null: false
      t.date :end_date
      t.boolean :is_current, default: true
      t.decimal :monthly_ctc, precision: 12, scale: 2
      t.string :pan_of_employer

      t.timestamps
    end

    add_index :employments, [:user_id, :is_current]
    add_index :employments, [:user_id, :employer_name]
  end
end
