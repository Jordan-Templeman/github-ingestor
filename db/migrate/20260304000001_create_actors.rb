class CreateActors < ActiveRecord::Migration[7.1]
  def change
    create_table :actors do |t|
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :display_login
      t.string :avatar_url
      t.string :url
      t.jsonb :raw_payload

      t.timestamps
    end

    add_index :actors, :github_id, unique: true
  end
end
