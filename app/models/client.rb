class Client < ApplicationRecord
  belongs_to :broker

  has_many :order_groups, dependent: :destroy
  has_many :orders, through: :order_groups do
    def delete_all
      Order.where(id: pluck(:id)).delete_all
    end
  end
  has_many :contracts, ->(client) { unscope(:where).where(order: client.orders) }, dependent: :destroy
end
