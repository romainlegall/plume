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

ActiveRecord::Schema[8.1].define(version: 2026_10_14_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "attachments", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.string "filename"
    t.string "content_type"
    t.string "content_id"
    t.string "sha256"
    t.string "storage_path", null: false
    t.integer "byte_size", default: 0, null: false
    t.boolean "is_inline", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "is_inline"], name: "index_attachments_on_message_id_and_is_inline"
    t.index ["message_id"], name: "index_attachments_on_message_id"
    t.index ["sha256"], name: "index_attachments_on_sha256"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "gm_thr_id", null: false
    t.string "subject"
    t.datetime "latest_at"
    t.integer "message_count", default: 0, null: false
    t.integer "unread_count", default: 0, null: false
    t.boolean "is_starred", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gm_thr_id"], name: "index_conversations_on_gm_thr_id", unique: true
    t.index ["latest_at"], name: "index_conversations_on_latest_at"
  end

  create_table "labels", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "kind", default: "user", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_labels_on_slug", unique: true
  end

  create_table "message_labels", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "label_id", null: false
    t.index ["label_id", "message_id"], name: "index_message_labels_on_label_id_and_message_id"
    t.index ["label_id"], name: "index_message_labels_on_label_id"
    t.index ["message_id", "label_id"], name: "index_message_labels_on_message_id_and_label_id", unique: true
    t.index ["message_id"], name: "index_message_labels_on_message_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "message_id"
    t.datetime "sent_at"
    t.string "from_name"
    t.string "from_email"
    t.text "from_raw"
    t.text "to_raw"
    t.text "cc_raw"
    t.string "subject"
    t.text "body_text"
    t.text "body_html"
    t.text "snippet"
    t.boolean "is_read", default: false, null: false
    t.boolean "is_starred", default: false, null: false
    t.boolean "is_outgoing", default: false, null: false
    t.integer "attachment_count", default: 0, null: false
    t.integer "byte_size", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "search_document", type: :tsvector, as: "to_tsvector('french'::regconfig, (((((((COALESCE(subject, ''::character varying))::text || ' '::text) || (COALESCE(from_name, ''::character varying))::text) || ' '::text) || (COALESCE(from_email, ''::character varying))::text) || ' '::text) || \"left\"(COALESCE(body_text, ''::text), 30000)))", stored: true
    t.index ["conversation_id", "sent_at"], name: "index_messages_on_conversation_id_and_sent_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["is_read"], name: "index_messages_on_is_read"
    t.index ["message_id"], name: "index_messages_on_message_id"
    t.index ["search_document"], name: "index_messages_on_search_document", using: :gin
    t.index ["sent_at"], name: "index_messages_on_sent_at"
    t.index ["subject"], name: "index_messages_on_subject_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  add_foreign_key "attachments", "messages"
  add_foreign_key "message_labels", "labels"
  add_foreign_key "message_labels", "messages"
  add_foreign_key "messages", "conversations"
end
