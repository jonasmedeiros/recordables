ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name, null: false
    t.timestamps
  end

  create_table :buckets, force: true do |t|
    t.references :bucketable, polymorphic: true, null: false, index: false
    t.timestamps
  end

  create_table :projects, force: true do |t|
    t.string :name, null: false
    t.timestamps
  end

  create_table :recordings, force: true do |t|
    t.references :bucket
    t.references :parent, foreign_key: { to_table: :recordings }
    t.references :creator, foreign_key: { to_table: :users, on_delete: :nullify }
    t.references :recordable, polymorphic: true, null: false, index: false
    t.integer :position
    t.timestamps
  end

  create_table :events, force: true do |t|
    t.references :recording, foreign_key: { on_delete: :nullify }
    t.references :recordable, polymorphic: true, null: false, index: false
    t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
    t.string :actor_name
    t.string :action, null: false
    t.json :details, null: false, default: {}
    t.datetime :created_at, null: false
  end

  create_table :posts, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :notes, force: true do |t|
    t.text :body, null: false
    t.datetime :created_at, null: false
  end

  create_table :pages, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :drafts, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :topics, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :boards, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :playlists, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :tracks, force: true do |t|
    t.string :title, null: false
    t.datetime :created_at, null: false
  end

  create_table :tags, force: true do |t|
    t.references :draft
    t.references :topic
    t.string :name
  end

  create_table :cards, force: true do |t|
    t.references :board
    t.string :name
    t.datetime :updated_at
  end

  create_table :active_storage_blobs, force: true do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string :name, null: false
    t.references :record, null: false, polymorphic: true, index: false
    t.references :blob, null: false
    t.datetime :created_at, null: false
    t.index [:record_type, :record_id, :name, :blob_id],
            name: :index_storage_attachments_uniqueness, unique: true
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.references :blob, null: false
    t.string :variation_digest, null: false
    t.index [:blob_id, :variation_digest], name: :index_variant_by_blob, unique: true
  end

  create_table :action_text_rich_texts, force: true do |t|
    t.string :name, null: false
    t.text :body
    t.references :record, null: false, polymorphic: true, index: false
    t.timestamps
    t.index [:record_type, :record_id, :name], name: :index_rich_texts_uniqueness, unique: true
  end
end
