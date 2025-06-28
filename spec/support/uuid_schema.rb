ActiveRecord::Schema.define do
  self.verbose = false

  create_table "users", id: false, force: :cascade do |t|
    t.string "id", primary_key: true, null: false, limit: 36
    t.text "hashed_password"
    t.datetime "password_updated_at"
    t.boolean "locked", default: false, null: false
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "clients", id: false, force: :cascade do |t|
    t.string "id", primary_key: true, null: false, limit: 36
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "veri_sessions", id: false, force: :cascade do |t|
    t.string "id", primary_key: true, null: false, limit: 36
    t.string "hashed_token", null: false
    t.datetime "expires_at", null: false
    t.string "authenticatable_id", null: false, limit: 36
    t.string "original_authenticatable_id", limit: 36
    t.datetime "shapeshifted_at"
    t.datetime "last_seen_at", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hashed_token"], name: "index_veri_sessions_on_hashed_token", unique: true
    t.index ["authenticatable_id"], name: "index_veri_sessions_on_authenticatable_id"
    t.index ["original_authenticatable_id"], name: "index_veri_sessions_on_original_authenticatable_id"
  end

  add_foreign_key "veri_sessions", "users", column: "authenticatable_id"
  add_foreign_key "veri_sessions", "users", column: "original_authenticatable_id"
end
