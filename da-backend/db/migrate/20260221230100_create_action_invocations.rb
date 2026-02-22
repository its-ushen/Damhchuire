class CreateActionInvocations < ActiveRecord::Migration[8.1]
  def change
    create_table :action_invocations, id: :string do |t|
      t.integer :chain_request_id, null: false, limit: 8
      t.string :chain_tx_signature, null: false
      t.string :action_slug, null: false
      t.string :status, null: false, default: "received"
      t.json :input_params
      t.json :action_snapshot
      t.integer :http_status
      t.text :response_body
      t.json :callback_payload
      t.string :callback_tx_signature
      t.text :error_message

      t.timestamps
    end

    add_index :action_invocations,
      [ :chain_tx_signature, :chain_request_id ],
      unique: true,
      name: "index_action_invocations_on_chain_identity"
    add_index :action_invocations, :action_slug
    add_index :action_invocations, :status
  end
end
