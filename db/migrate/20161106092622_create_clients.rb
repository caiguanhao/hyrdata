class CreateClients < ActiveRecord::Migration[5.0]
  def change
    create_table :brokers do |t|
      t.string :name
      t.jsonb :info, default: {}, null: false
    end

    add_index :brokers, :name, unique: true

    create_table :clients do |t|
      t.integer :broker_id
      t.string :cellphone
      t.string :password
      t.jsonb :info, default: {}, null: false
      t.timestamps
    end

    add_index :clients, :broker_id
    add_index :clients, :cellphone, unique: true

    create_table :borrowers do |t|
      t.string :name
      t.string :identity
      t.jsonb :info, default: {}, null: false
    end

    add_index :borrowers, [ :name, :identity ], unique: true

    create_table :order_groups do |t|
      t.integer :ogid
      t.string :kind
      t.jsonb :info, default: {}, null: false
      t.integer :client_id
    end

    create_table :orders do |t|
      t.integer :oid
      t.integer :order_group_id
      t.jsonb :info, default: {}, null: false
    end

    add_index :orders, :oid, unique: true
    add_index :orders, :order_group_id

    create_table :contracts do |t|
      t.integer :cid
      t.integer :order_id
      t.integer :borrower_id
      t.jsonb :info, default: {}, null: false
    end

    add_index :contracts, :cid
    add_index :contracts, :order_id
    add_index :contracts, :borrower_id
  end
end
