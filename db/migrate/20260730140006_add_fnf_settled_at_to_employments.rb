class AddFnfSettledAtToEmployments < ActiveRecord::Migration[8.0]
  def change
    add_column :employments, :fnf_settled_at, :datetime
  end
end
