class CreateRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendations do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :tmdb_id
      t.string :media_type
      t.string :title
      t.string :poster_path
      t.text :reason
      t.boolean :seen

      t.timestamps
    end
  end
end
