class Contract < ApplicationRecord
  belongs_to :order
  belongs_to :borrower

  has_one :client, through: :order
end
