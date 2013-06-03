# This migration comes from drbarpg (originally 20130601144555)
class CreateDrbarpgDrbarpgConnections < ActiveRecord::Migration
  def change
    # Only the sequence of this table is used to retrieve a uniqe
    # client id for notifications. No data is stored in the table.
    create_table :drbarpg_connections do |t|
    end
  end
end
