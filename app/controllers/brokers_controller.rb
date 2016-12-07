class BrokersController < ApplicationController
  before_action :set_borker, except: [ :index, :new, :create ]

  def index
    @brokers = Broker.order(id: :asc)
  end

  def new
    @broker = Broker.new
  end

  def create
    @broker = Broker.new(broker_params)
    @broker.save
    redirect_to brokers_path
  end

  def edit
  end

  def update
    @broker.assign_attributes(broker_params)
    @broker.save
    redirect_to brokers_path
  end

  def toggle_status
    @broker.status = @broker.active? ? nil : 'active'
    @broker.save
    redirect_to brokers_path
  end

  private

    def set_borker
      @broker = Broker.find(params[:id])
    end

    def broker_params
      params.require(:broker).permit(:name)
    end
end
