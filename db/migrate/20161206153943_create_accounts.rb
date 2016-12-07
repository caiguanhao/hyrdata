class CreateAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :accounts do |t|
      t.jsonb :restrictions, default: {}, null: false
      t.integer :quota, default: 0
    end
  end
end
