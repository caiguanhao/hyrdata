class PagesChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'pages'
  end

  def pay(data)
    begin
      cellphone = data.fetch('cellphone')
      hyr = HYR.new(cellphone, data.fetch('password'), data.fetch('uid'), data.fetch('ukey'))
      type = data.dig('type', 'type')
      id = data.dig('type', 'id')
      pattern = data.dig('type', 'pattern')
      money = data.fetch('money').to_i
      if money > 0
        broadcast(cellphone, message: '准备抢...')
        resp, success = hyr.pay(type, money, id, pattern)
        if resp['code'].to_i == 1041  # logged in elsewhere
          broadcast(cellphone, message: '登录中...')
          hyr.login
          broadcast(cellphone, message: '重试抢...')
          resp, success = hyr.pay(type, money, id, pattern)
        end
        broadcast(cellphone, message: resp['msg'], enabled: true)
      else
        broadcast(cellphone, message: '金额为0，无法抢', enabled: true)
      end
    rescue HTTP::TimeoutError
      broadcast(cellphone, message: '超时', enabled: true)
    rescue Exception
      broadcast(cellphone, message: '发生错误！', enabled: true)
    end
  end

  def login(data)
    begin
      cellphone = data.fetch('cellphone')
      hyr = HYR.new(cellphone, data.fetch('password'), data.fetch('uid'), data.fetch('ukey') || '(null)')

      broadcast(cellphone, message: '获取信息中...')
      resp, success = hyr.get_orders

      if success
        last = resp.dig('data', 0, 'addtime')
        broadcast(cellphone, message: '成功获取信息', last_order_time: last, enabled: true)
      else
        broadcast(cellphone, message: '登录中...')
        resp, success, uid, ukey = hyr.login
        if success
          broadcast(cellphone, name: hyr.name, uid: uid, ukey: ukey, message: '获取余额...')
          balance, success = hyr.get_balance
          broadcast(cellphone, balance: balance, message: '获取信息中...')
          resp, success = hyr.get_orders
          last = resp.dig('data', 0, 'addtime')
          broadcast(cellphone, message: '成功获取信息', last_order_time: last, enabled: true)
        else
          broadcast(cellphone, message: resp['msg'], enabled: true)
        end
      end
    rescue HTTP::TimeoutError
      broadcast(cellphone, message: '超时', enabled: true)
    rescue Exception
      broadcast(cellphone, message: '发生错误！', enabled: true)
    end
  end

  private

    def broadcast(cellphone, obj = {})
      ActionCable.server.broadcast('pages', { cellphone: cellphone, enabled: false }.merge(obj))
    end
end
