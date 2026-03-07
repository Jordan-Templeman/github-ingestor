class AddEtagToActorsAndRepositories < ActiveRecord::Migration[7.1]
  def change
    add_column :actors, :etag, :string
    add_column :repositories, :etag, :string
  end
end
