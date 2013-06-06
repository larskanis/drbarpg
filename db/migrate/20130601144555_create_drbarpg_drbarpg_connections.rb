class CreateDrbarpgDrbarpgConnections < ActiveRecord::Migration
  def change
    create_table :drbarpg_connections do |t|
      t.text "listen_channel"
    end
    add_index :drbarpg_connections, "listen_channel", :unique => true
  end
end
