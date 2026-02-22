class AddUniquenessToCredentialName < ActiveRecord::Migration[8.1]
  def change
    change_column_null :credentials, :name, false
    add_index :credentials, :name, unique: true
  end
end
