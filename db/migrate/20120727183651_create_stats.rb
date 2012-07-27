class CreateStats < ActiveRecord::Migration
  def change
    create_table :stats do |t|
      t.float :min
      t.float :max
      t.integer :right
      t.integer :draw
      t.integer :wrong
      t.float :percentage

      t.timestamps
    end
  end
end
