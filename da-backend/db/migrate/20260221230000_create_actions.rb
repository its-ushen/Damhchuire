class CreateActions < ActiveRecord::Migration[8.1]
  def change
    create_table :actions do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, null: false, default: true
      t.string :http_method, null: false, default: "GET"
      t.text :url_template, null: false
      t.json :headers_template, null: false, default: {}
      t.json :request_schema, null: false, default: {}
      t.json :response_schema, null: false, default: {}

      t.timestamps
    end

    add_index :actions, :slug, unique: true
  end
end
