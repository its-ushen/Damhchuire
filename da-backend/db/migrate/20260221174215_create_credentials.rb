class CreateCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :credentials do |t|
      t.string :name
      t.string :value

      t.timestamps
    end
  end
end
