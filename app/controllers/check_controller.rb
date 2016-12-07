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
    broker = params[:broker].map { |b| [ b[:key], b[:value] ] }.to_h
    a = Account.select(:id, :quota).find_by('restrictions <@ ?', broker.to_json).try(:as_json) || {}
    render json: a.merge(ok: a.fetch('quota', 0) > 0 ? 1 : 0)
  end
end
