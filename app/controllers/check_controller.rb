class CheckController < ApplicationController
  skip_before_action :verify_authenticity_token

  def version
    render json: { ok: true }
  end

  def broker
    broker = Broker.find_by(name: params[:name])
    if broker && broker.active?
      render json: { ok: true }
    else
      render json: { ok: false, msg: '请联系负责人升级／充值程序。' }
    end
  end

  def account
    d = {
      '106' => 3,
      '105' => 2,
      '104' => 1.5,
      '103' => 1,
      '102' => 0.5,
    }.fetch(params[:id], 1) * params[:amount].to_i
    broker = params[:broker].map { |b| [ b[:key], b[:value] ] }.to_h
    a = Account.select(:id, :quota).find_by('restrictions <@ ?', broker.to_json).try(:as_json) || {}
    free = '10:00:20'
    ok = a.fetch('quota', -1) >= d || Time.now.localtime > Time.parse(free)
    if ok
      msg = nil
    else
      msg = "配额不足，请联系负责人充值可第一时间开抢。如果你想免费使用，请稍等，软件会一直重试直至#{free}后免费时间段开放。"
    end
    render json: a.merge(ok: ok, msg: msg)
  end
end
