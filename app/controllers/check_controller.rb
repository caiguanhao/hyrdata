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
end
