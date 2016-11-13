class Order < ApplicationRecord
  belongs_to :order_group

  has_one :client, through: :order_group

  has_many :contracts, dependent: :destroy
end
