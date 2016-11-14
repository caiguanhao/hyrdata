class Client < ApplicationRecord
  belongs_to :broker

  has_many :order_groups, dependent: :destroy
  has_many :orders, through: :order_groups do
    def delete_all
      Order.where(id: pluck(:id)).delete_all
    end
  end
  has_many :contracts, ->(client) { unscope(:where).where(order: client.orders) }, dependent: :destroy

  def files_go
    dl = []
    prefixes = {}
    order_groups.preload(orders: { contracts: :borrower }).each do |order_group|
      prefix = "#{cellphone}(#{info['真实姓名']})/#{order_group.info.dig('basic', '出借时间')}-#{order_group.kind.gsub(/\s+/, '')}"
      prefixes[prefix] ||= 0
      prefixes[prefix] += 1
      prefix += "(#{prefixes[prefix]})" if prefixes[prefix] > 1
      order_group.orders.each do |order|
        order.contracts.each do |contract|
          la, lta = contract.info['loan_agreement'], contract.info['loan_transfer_agreement']
          name = contract.borrower.name
          dl << t([ n(la), n("#{prefix}/#{name}/借款协议.pdf"), n("#{name}-借款协议.pdf") ]) if la.present?
          dl << t([ n(lta), n("#{prefix}/#{name}/债权转让协议.pdf"), n("#{name}-债权转让协议.pdf") ]) if lta.present?
        end
      end
    end

    <<-GO
package main

#{dl.present? ? 'import "strings"' : ''}

var files []interface{} = []interface{}{
#{dl.join("\n").indent(1, "\t")}
}
GO
  end

  private

    def n(str)
      %{strings.Join([]string{#{str.chars.to_json[1..-2]}}, "")}
    end

    def j(str)
      str.to_json
    end

    def t(arr)
      "[]string{#{arr.join(', ')}},"
    end
end
