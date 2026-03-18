class CreateTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :tokens, id: false do |t|
      t.string :uuid, limit: 36, null: false, primary_key: true
      t.integer :default_status, null: false, default: 200
      t.string :default_content_type, null: false, default: "application/json"
      t.text :default_content, null: false, default: ""
      t.integer :timeout
      t.boolean :cors, null: false, default: true
      t.timestamps
    end
  end
end
