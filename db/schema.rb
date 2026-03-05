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

ActiveRecord::Schema[7.1].define(version: 2026_03_04_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "actors", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "display_login"
    t.string "avatar_url"
    t.string "url"
    t.jsonb "raw_payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_actors_on_github_id", unique: true
  end

  create_table "push_events", force: :cascade do |t|
    t.string "github_id", null: false
    t.bigint "actor_id", null: false
    t.bigint "repository_id", null: false
    t.string "ref", null: false
    t.string "head", null: false
    t.string "before", null: false
    t.bigint "push_id"
    t.jsonb "raw_payload", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_push_events_on_actor_id"
    t.index ["github_id"], name: "index_push_events_on_github_id", unique: true
    t.index ["repository_id"], name: "index_push_events_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.string "name", null: false
    t.string "full_name"
    t.string "url"
    t.jsonb "raw_payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_repositories_on_github_id", unique: true
  end

  add_foreign_key "push_events", "actors"
  add_foreign_key "push_events", "repositories"
end
