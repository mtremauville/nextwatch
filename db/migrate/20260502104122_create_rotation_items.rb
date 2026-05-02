class CreateRotationItems < ActiveRecord::Migration[8.1]
  def change
    create_table :rotation_items do |t|
      t.references :rotation, null: false, foreign_key: true
      t.references :watch_item, null: false, foreign_key: true
      t.integer :position
      t.integer :episodes_per_turn

      t.timestamps
    end
  end
end
