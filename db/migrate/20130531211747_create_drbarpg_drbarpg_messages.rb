class CreateDrbarpgDrbarpgMessages < ActiveRecord::Migration
  def change
    create_table :drbarpg_messages do |t|
      t.references "drbarpg_connection"
      t.text "payload"
    end
  end
end
