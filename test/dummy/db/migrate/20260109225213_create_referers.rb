class CreateReferers < ActiveRecord::Migration[8.1]
  def change
    create_table :referers, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name

      t.timestamps
    end
  end
end
