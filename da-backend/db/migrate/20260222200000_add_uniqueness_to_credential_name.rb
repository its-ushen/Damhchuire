class AddUniquenessToCredentialName < ActiveRecord::Migration[8.1]
  def up
    # Remove duplicates before adding unique constraint
    execute <<~SQL
      DELETE FROM credentials
      WHERE id NOT IN (
        SELECT MIN(id) FROM credentials GROUP BY name
      )
    SQL

    # Remove rows with NULL names
    execute "DELETE FROM credentials WHERE name IS NULL"

    change_column_null :credentials, :name, false
    add_index :credentials, :name, unique: true
  end

  def down
    remove_index :credentials, :name
    change_column_null :credentials, :name, true
  end
end
