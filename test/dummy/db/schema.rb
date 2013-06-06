# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130601144555) do

  create_table "drbarpg_connections", :force => true do |t|
    t.text "listen_channel"
  end

  add_index "drbarpg_connections", ["listen_channel"], :name => "index_drbarpg_connections_on_listen_channel", :unique => true

  create_table "drbarpg_messages", :force => true do |t|
    t.integer "drbarpg_connection_id"
    t.text    "payload"
  end

end
