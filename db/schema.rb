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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161120181820) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "borrowers", force: :cascade do |t|
    t.string "name"
    t.string "identity"
    t.jsonb  "info",     default: {}, null: false
    t.index ["name", "identity"], name: "index_borrowers_on_name_and_identity", unique: true, using: :btree
  end

  create_table "brokers", force: :cascade do |t|
    t.string "name"
    t.jsonb  "info",   default: {}, null: false
    t.string "status"
    t.index ["name"], name: "index_brokers_on_name", unique: true, using: :btree
  end

  create_table "clients", force: :cascade do |t|
    t.integer  "broker_id"
    t.string   "cellphone"
    t.string   "password"
    t.jsonb    "info",       default: {}, null: false
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.index ["broker_id"], name: "index_clients_on_broker_id", using: :btree
    t.index ["cellphone"], name: "index_clients_on_cellphone", unique: true, using: :btree
  end

  create_table "contracts", force: :cascade do |t|
    t.integer "cid"
    t.integer "order_id"
    t.integer "borrower_id"
    t.jsonb   "info",        default: {}, null: false
    t.index ["borrower_id"], name: "index_contracts_on_borrower_id", using: :btree
    t.index ["cid"], name: "index_contracts_on_cid", using: :btree
    t.index ["order_id"], name: "index_contracts_on_order_id", using: :btree
  end

  create_table "order_groups", force: :cascade do |t|
    t.integer "ogid"
    t.string  "kind"
    t.jsonb   "info",      default: {}, null: false
    t.integer "client_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "oid"
    t.integer "order_group_id"
    t.jsonb   "info",           default: {}, null: false
    t.index ["oid"], name: "index_orders_on_oid", unique: true, using: :btree
    t.index ["order_group_id"], name: "index_orders_on_order_group_id", using: :btree
  end

end
