class CreateExternalRefs < ActiveRecord::Migration[8.1]
  def change
    create_table :external_refs, id: :integer do |t|
      t.string :name
      t.belongs_to :user, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
