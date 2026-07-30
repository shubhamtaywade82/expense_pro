class CreateSalaryComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :salary_components do |t|
      t.references :employment, null: false, foreign_key: true
      t.string :component_type, null: false
      t.string :component_label
      t.decimal :monthly_amount, precision: 12, scale: 2, default: 0.0
      t.boolean :is_taxable, default: true
      t.boolean :is_exempt_under_80c, default: false
      t.decimal :hra_rent_paid, precision: 12, scale: 2

      t.timestamps
    end

    add_index :salary_components, [:employment_id, :component_type]
  end
end
