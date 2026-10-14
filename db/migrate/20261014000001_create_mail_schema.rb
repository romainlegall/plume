class CreateMailSchema < ActiveRecord::Migration[8.1]
  def change
    # "conversation" plutot que "thread" : Thread est une classe du coeur de
    # Ruby, un modele de ce nom serait refuse par Zeitwerk.
    create_table :conversations do |t|
      t.string :gm_thr_id, null: false
      t.string :subject
      t.datetime :latest_at
      t.integer :message_count, default: 0, null: false
      t.integer :unread_count, default: 0, null: false
      t.boolean :is_starred, default: false, null: false
      t.timestamps
    end
    add_index :conversations, :gm_thr_id, unique: true
    add_index :conversations, :latest_at

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :message_id
      t.datetime :sent_at
      t.string :from_name
      t.string :from_email
      t.text :from_raw
      t.text :to_raw
      t.text :cc_raw
      t.string :subject
      t.text :body_text
      t.text :body_html
      t.text :snippet
      t.boolean :is_read, default: false, null: false
      t.boolean :is_starred, default: false, null: false
      t.boolean :is_outgoing, default: false, null: false
      t.integer :attachment_count, default: 0, null: false
      t.integer :byte_size, default: 0, null: false
      t.timestamps
    end
    add_index :messages, :sent_at
    add_index :messages, :message_id
    add_index :messages, [ :conversation_id, :sent_at ]
    add_index :messages, :is_read

    create_table :labels do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :kind, default: "user", null: false
      t.timestamps
    end
    add_index :labels, :slug, unique: true

    create_table :message_labels do |t|
      t.references :message, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
    end
    add_index :message_labels, [ :message_id, :label_id ], unique: true
    add_index :message_labels, [ :label_id, :message_id ]

    create_table :attachments do |t|
      t.references :message, null: false, foreign_key: true
      t.string :filename
      t.string :content_type
      t.string :content_id
      t.string :sha256
      t.string :storage_path, null: false
      t.integer :byte_size, default: 0, null: false
      t.boolean :is_inline, default: false, null: false
      t.timestamps
    end
    add_index :attachments, :sha256
    add_index :attachments, [ :message_id, :is_inline ]
  end
end