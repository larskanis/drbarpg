class CreateDrbarpgDrbarpgMessages < ActiveRecord::Migration
  def change
    create_table :drbarpg_messages do |t|
      t.integer "target_id"
      t.text "name"
      t.text "parameters"
      t.text "result"
      t.integer "source_id"
    end
  end
end
