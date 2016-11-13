class OrderGroup < ApplicationRecord
  belongs_to :client

  has_many :orders, dependent: :delete_all
end
