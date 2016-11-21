class Broker < ApplicationRecord
  has_many :clients

  def active?
    status == 'active'
  end

  def status_html
    if active?
      return 'ACTIVE', 'text-success'
    else
      return 'INACTIVE', 'text-danger'
    end
  end
end
