# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_21_230100) do
  create_table "action_invocations", id: :string, force: :cascade do |t|
    t.string "action_slug", null: false
    t.json "action_snapshot"
    t.json "callback_payload"
    t.string "callback_tx_signature"
    t.integer "chain_request_id", limit: 8, null: false
    t.string "chain_tx_signature", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "http_status"
    t.json "input_params"
    t.text "response_body"
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["action_slug"], name: "index_action_invocations_on_action_slug"
    t.index ["chain_tx_signature", "chain_request_id"], name: "index_action_invocations_on_chain_identity", unique: true
    t.index ["status"], name: "index_action_invocations_on_status"
  end

  create_table "actions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.json "headers_template", default: {}, null: false
    t.string "http_method", default: "GET", null: false
    t.string "name", null: false
    t.json "request_schema", default: {}, null: false
    t.json "response_schema", default: {}, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.text "url_template", null: false
    t.index ["slug"], name: "index_actions_on_slug", unique: true
  end

  create_table "credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "value"
  end
end
