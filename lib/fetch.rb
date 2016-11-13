class Fetch
  def initialize(data = {})
    @data = data
    @current_url = nil
  end

  def current_url
    @current_url
  end

  def get_broker
    doc = get_doc('/user/CaiConsultant.html')
    info = doc.css('.yaoqingma_user_box li').map { |li|
      [ li.at_css('label').text.strip.sub('：', ''), li.at_css('span').text.strip ]
    }.to_h
    return nil if info.empty?
    name = info.delete('财富顾问')
    Broker.create_with(info: info).find_or_create_by!(name: name)
  end

  def get_client(broker)
    doc = get_doc('/accountmge.html')
    info = doc.css('.dlm_jbxx tr').map do |row|
      key, value = row.css('td')
      next nil if value.nil?
      [ key.text.sub('：', ''), value.text ]
    end.compact.to_h
    info.except!('头像')
    return nil if info.empty?
    broker.clients.create_with(password: @data.fetch(:password), info: info).find_or_create_by!(cellphone: @data.fetch(:cellphone))
  end

  def get_order_group(client, order_group)
    id = order_group[:id]
    orders = order_group[:orders]
    pdf = post_html('/user/Createagreement.html', { oid: id }).body.strip
    order_group = client.order_groups.create_with(
      kind: order_group[:kind],
      info: { basic: order_group[:basic], agreement: pdf },
    ).find_or_create_by!(ogid: id)
    return order_group, orders
  end

  def get_orders(page = 1)
    order_groups = []
    requests_count = 0

    doc = get_doc("/tender.html?page=#{page}")

    last_page = doc.css('.trrnpage a').find { |a| a.text == '末页' }
    max_page = last_page && last_page.attr('href').scan(/\d+/).first.to_i || 1

    doc.css('.sy_tabel_jilv tr').drop(1).each do |row|
      next if row.nil? or row.css('td').first.nil?
      td = row.css('td').first
      case td.attr('class')
      when 'tdfirst'
        name = td.text.lines.first.strip
        id = td.css('a').first.attr('onclick').scan(/\d+/).first
        tds = row.css('td')
        basic = ['平台建议的年均出借回报率约', '出借金额', '过往收益', '出借期限', '收益方式', '出借时间'].map.with_index do |col, i|
          [ col, tds[1 + i].text.strip ]
        end.to_h
        order_groups << {
          id: id,
          kind: name,
          basic: basic,
        }
        requests_count += 1
      when 'sx_BigTd'
        td.css('table tr').drop(1).each do |row|
          id = row.css('a').first.attr('href').scan(/\d+/).first
          tds = row.css('td')
          info = ['匹配金额', '匹配借款数', '匹配时间', '账单日', '剩余期限', '状态'].map.with_index do |col, i|
            [ col, tds[1 + i].text.strip ]
          end.to_h
          order_groups.last[:orders] ||= []
          order_groups.last[:orders] << {
            id: id,
            info: info,
          }
          requests_count += 1
        end
      end
    end

    if page < max_page
      groups, count = get_orders(page+1)
      order_groups += groups
      requests_count += count
    end

    return order_groups, requests_count
  end

  def get_contracts(order_group, order)
    doc = get_doc("/tender/view/id/#{order[:id]}.html")

    blocks = doc.css('.H_dlb_info')

    info = order[:info]
    info = info.merge(vertical_table(blocks.first.css('td')))
    key, value = blocks.first.parent.at_css('.H_time_deal').text.split('：', 2)
    info = info.merge({ key.strip => value.strip })

    extra = []
    blocks.drop(1).each do |block|
      enfo = vertical_table(block.css('td'))
      enfo.merge!(block.parent.at_css('.H_time_deal').css('li').map { |li| li.text.sub(/(\d)/, '：\1').split('：', 2) }.to_h)
      extra << {
        name: block.parent.at_css('.T_box2_title').text.strip,
        info: enfo,
      }
    end

    contracts = []
    if order[:info].fetch('状态') == '出借中'
      doc.css('.H_table_style tr').drop(1).each do |row|
        name = row.css('td').first.text
        cid, oid = row.css('a').first.attr('href').scan(/\d+/)
        contracts << {
          name: name,
          cid: cid,
          oid: oid,
        }
      end
    end
    return order_group.orders.create_with(info: { basic: info, extra: extra }).find_or_create_by!(oid: order[:id]), contracts
  end

  def get_contract(order, contract)
    cid, oid = contract[:cid], contract[:oid]
    doc = get_doc("/tender/details/id/#{cid}/oid/#{oid}.html")

    info = {}
    info[:loan_agreement] = fix_pdf_url(doc.css('.dlm_hetongCon iframe').first.attr('src'))
    lta = doc.css('.dlm_jkTit a').first
    info[:loan_transfer_agreement] = fix_pdf_url(lta.attr('href')) if lta.present?

    contract = vertical_table(doc.at_css('.dlm_tyTab').css('th, td'))
    info[:basic] = contract

    borrower = Borrower.create_with(info: contract.extract!('职业情况')).find_or_create_by!(name: contract.delete('借款人'), identity: contract.delete('借款人身份证'))
    order.contracts.create_with(info: info, borrower: borrower).find_or_create_by!(cid: cid)
  end

  def get(&progress)
    progress = Proc.new {} if not block_given?

    ActiveRecord::Base.transaction do
      done = 0

      progress.call(done+=5, '获取财富顾问...')
      broker = get_broker
      break false if broker.nil?

      progress.call(done+=5, '获取个人信息...')
      client = get_client(broker)
      break false if client.nil?

      progress.call(done+=5, '获取订单...')

      order_groups = []
      orders = []
      orders_count = 0
      contracts_count = 0

      groups, requests_count = get_orders
      per = 35.to_f / requests_count

      groups.each.with_index do |order_group, i|
        progress.call(done+=per, "获取服务协议 (#{i+1}/#{groups.size}) ...")
        order_groups << get_order_group(client, order_group)
        orders_count += order_groups.last.last.size
      end

      count = 0
      order_groups.each do |(order_group, _orders)|
        _orders.each do |order|
          progress.call(done+=per, "获取订单详情 (#{count+=1}/#{orders_count}) ...")
          orders << get_contracts(order_group, order)
          contracts_count += orders.last.last.size
        end
      end

      per = (100 - done).to_f / orders.inject(0) { |sum, (order, contracts)| sum + contracts.size }
      count = 0
      orders.each do |(order, contracts)|
        contracts.each do |contract|
          progress.call(done+=per, "获取借款信息 (#{count+=1}/#{contracts_count}) ...")
          get_contract(order, contract)
        end
      end

      client.touch

      true
    end
  end

  private

    def post_html(path, payload)
      RestClient::Request.execute(
        url: "https://www.hengyirong.com#{path}",
        method: :post,
        cookies: @data.slice(:PHPSESSID, :TOKEN, :USERID),
        payload: payload,
      )
    end

    def get_doc(path)
      @current_url = "https://www.hengyirong.com#{path}"
      resp = RestClient::Request.execute(
        url: "https://www.hengyirong.com#{path}",
        method: :get,
        cookies: @data.slice(:PHPSESSID, :TOKEN, :USERID),
      )
      Nokogiri::HTML(resp.body)
    end

    def fix_pdf_url(str)
      str.strip.gsub(/(?:[^:]|\A)\/{2,}/, '/').gsub('/displaypdf/index?pdfurl=', '')
    end

    def vertical_table(cells)
      cells.map(&:text).map(&:strip).each_slice(2).sort_by.with_index{ |_, i| [ i.odd? ? 1 : 0, i ] }.to_h
    end
end
