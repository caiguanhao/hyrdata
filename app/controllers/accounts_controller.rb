class AccountsController < ApplicationController
  before_action :set_account, except: [ :index, :new, :create, :done ]

  skip_before_action :verify_authenticity_token, only: [ :done ]

  def index
    @accounts = Account.order(id: :desc)
  end

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)
    @account.save
    redirect_to accounts_path
  end

  def edit
  end

  def update
    @account.assign_attributes(account_params)
    @account.save
    redirect_to accounts_path
  end

  def done
    d = {
      '106' => 3,
      '105' => 2,
      '104' => 1.5,
      '103' => 1,
      '102' => 0.5,
    }.fetch(params[:id], 1) * params[:amount].to_i
    broker = params[:broker].map { |b| [ b[:key], b[:value] ] }.to_h
    account = Account.find_by!('restrictions <@ ?', broker.to_json)
    free = '10:00:20'
    free_end = '10:10:00'
    is_free = Time.now.localtime >= Time.parse(free) && Time.now.localtime <= Time.parse(free_end)
    if is_free
      d = 0
    else
      account.decrement!(:quota, d)
    end
    render json: { ok: true, decrement: d }
  end

  private

    def set_account
      @account = Account.find(params[:id])
    end

    def account_params
      params.require(:account).permit(:quota, *Account::RESTRICTIONS.keys)
    end
end
