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

ActiveRecord::Schema[8.0].define(version: 2024_11_26_051852) do
  create_table "commits", force: :cascade do |t|
    t.integer "repository_id"
    t.string "commit_hash"
    t.string "author"
    t.datetime "committer_date"
    t.datetime "author_date"
    t.boolean "for_changes_ledger", default: false
    t.text "parent_hashes"
    t.string "subject"
    t.index ["repository_id", "commit_hash"], name: "index_commits_on_repository_id_and_commit_hash", unique: true
    t.index ["repository_id", "for_changes_ledger", "committer_date"], name: "idx_on_repository_id_for_changes_ledger_committer_d_f429cd9db3"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.string "domain"
    t.string "path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain", "path"], name: "index_repositories_on_domain_and_path", unique: true
  end

  create_table "repository_sync_attempts", force: :cascade do |t|
    t.integer "repository_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id"], name: "index_repository_sync_attempts_on_repository_id"
  end

  create_table "source_file_changes", force: :cascade do |t|
    t.integer "commit_id"
    t.integer "additions", default: 0
    t.integer "deletions", default: 0
    t.integer "source_file_id"
    t.string "category"
    t.index ["commit_id"], name: "index_source_file_changes_on_commit_id"
    t.index ["source_file_id", "commit_id"], name: "index_source_file_changes_on_source_file_id_and_commit_id", unique: true
    t.index ["source_file_id"], name: "index_source_file_changes_on_source_file_id"
  end

  create_table "source_files", force: :cascade do |t|
    t.integer "repository_id"
    t.string "filepath"
    t.index ["repository_id", "filepath"], name: "index_source_files_on_repository_id_and_filepath", unique: true
  end
end
