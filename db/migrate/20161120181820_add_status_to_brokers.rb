class AddStatusToBrokers < ActiveRecord::Migration[5.0]
  def change
    add_column :brokers, :status, :string
  end
end
