class CreateWatchItems < ActiveRecord::Migration[8.1]
  def change
    create_table :watch_items do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :tmdb_id
      t.string :media_type
      t.string :title
      t.string :poster_path
      t.string :status
      t.integer :current_season
      t.integer :current_episode
      t.decimal :vote_average
      t.text :overview
      t.string :genres

      t.timestamps
    end
  end
end
