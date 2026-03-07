class CreatePushEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :push_events do |t|
      t.string :github_id, null: false
      t.references :actor, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      t.string :ref, null: false
      t.string :head, null: false
      t.string :before, null: false
      t.bigint :push_id
      t.jsonb :raw_payload, null: false

      t.timestamps
    end

    add_index :push_events, :github_id, unique: true
  end
end
