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

ActiveRecord::Schema[8.1].define(version: 2026_05_02_104130) do
  create_table "recommendations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "media_type"
    t.string "poster_path"
    t.text "reason"
    t.boolean "seen"
    t.string "title"
    t.integer "tmdb_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_recommendations_on_user_id"
  end

  create_table "rotation_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "episodes_per_turn"
    t.integer "position"
    t.integer "rotation_id", null: false
    t.datetime "updated_at", null: false
    t.integer "watch_item_id", null: false
    t.index ["rotation_id"], name: "index_rotation_items_on_rotation_id"
    t.index ["watch_item_id"], name: "index_rotation_items_on_watch_item_id"
  end

  create_table "rotations", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_rotations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "watch_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_episode"
    t.integer "current_season"
    t.string "genres"
    t.string "media_type"
    t.text "overview"
    t.string "poster_path"
    t.string "status"
    t.string "title"
    t.integer "tmdb_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.decimal "vote_average"
    t.index ["user_id"], name: "index_watch_items_on_user_id"
  end

  add_foreign_key "recommendations", "users"
  add_foreign_key "rotation_items", "rotations"
  add_foreign_key "rotation_items", "watch_items"
  add_foreign_key "rotations", "users"
  add_foreign_key "watch_items", "users"
end
