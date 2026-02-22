class AddBodyTemplateToActions < ActiveRecord::Migration[8.1]
  def change
    add_column :actions, :body_template, :json, null: false, default: {}
  end
end
