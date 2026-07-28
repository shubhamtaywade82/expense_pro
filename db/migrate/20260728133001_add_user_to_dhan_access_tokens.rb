class AddUserToDhanAccessTokens < ActiveRecord::Migration[8.0]
  def up
    add_reference :dhan_access_tokens, :user, foreign_key: true, index: true
    execute "UPDATE dhan_access_tokens SET user_id = (SELECT id FROM users ORDER BY id LIMIT 1) WHERE user_id IS NULL"
    change_column_null :dhan_access_tokens, :user_id, false
  end

  def down
    remove_reference :dhan_access_tokens, :user, foreign_key: true
  end
end
