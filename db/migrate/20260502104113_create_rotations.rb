class CreateRotations < ActiveRecord::Migration[8.1]
  def change
    create_table :rotations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.boolean :active

      t.timestamps
    end
  end
end
