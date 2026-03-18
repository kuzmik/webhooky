class CreateWebhookRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_requests, id: false do |t|
      t.string :uuid, limit: 36, null: false, primary_key: true
      t.string :token_id, limit: 36, null: false
      t.string :method_name, null: false
      t.text :url, null: false
      t.string :ip, null: false
      t.string :hostname
      t.text :content
      t.text :headers
      t.text :query
      t.text :form_data
      t.integer :content_size, null: false, default: 0
      t.datetime :created_at, null: false
    end

    add_index :webhook_requests, [:token_id, :created_at], order: { created_at: :desc }
    add_foreign_key :webhook_requests, :tokens, column: :token_id, primary_key: :uuid
  end
end
