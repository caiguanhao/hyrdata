class PagesController < ApplicationController
  def home
  end

  def sytlist
    resp, success = HYR.new.get_syt_list
    syts = []
    if success
      resp['data'].each do |syt|
        syts << {
          id: syt['qu_id'],
          name: "随易投 #{syt['rate']} #{syt['term']}天 #{syt['lowmoney']}元起",
        } if syt['status'] == 2
      end
    end
    render json: syts
  end
end
