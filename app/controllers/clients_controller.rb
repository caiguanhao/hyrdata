class ClientsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    respond_to do |format|
      format.html {
        render :index
      }
      format.json {
        render json: Client.select(:id, :broker_id, :cellphone, :info, :created_at, :updated_at).preload(:broker).order(updated_at: :desc).map { |client|
          json = client.as_json
          json[:broker] = client.broker
          json
        }
      }
    end
  end

  def show
    @client = Client.select(:id, :broker_id, :cellphone, :info, :created_at, :updated_at).find(params[:id])
    json = @client.as_json
    json[:broker] = @client.broker
    json[:order_groups] = @client.order_groups.preload(orders: { contracts: :borrower }).map { |order_group|
      order_group_json = order_group.as_json
      order_group_json[:orders] = order_group.orders.map { |order|
        order_json = order.as_json
        order_json[:contracts] = order.contracts.map { |contract|
          contract_json = contract.as_json
          contract_json[:borrower] = contract.borrower
          contract_json
        }
        order_json
      }
      order_group_json
    }
    render json: json
  end

  def new
    resp = RestClient::Request.execute(
      url: 'https://www.hengyirong.com/site/captcha/',
      method: :get,
    )
    render json: {
      image: Base64.strict_encode64(resp.body),
      session: resp.cookies.fetch('PHPSESSID'),
    }
  end

  def create
    progress = Proc.new { |progress, status, is_last = false|
      ActionCable.server.broadcast 'messages', { progress: [ progress, 100 ].min.round(2), status: status, is_last: is_last }
    }

    progress.call(0, '登录中...')

    username, password, captcha = params[:username], params[:password], params[:captcha]
    if (client = Client.find_by(cellphone: username)).present?
      password = password.presence || client.password
    end

    RestClient::Request.execute(
      url: 'https://www.hengyirong.com/site/login.html',
      method: :post,
      cookies: {
        'PHPSESSID' => params[:session],
      },
      payload: {
        'LoginForm[username]'   => username,
        'LoginForm[password]'   => password,
        'LoginForm[verifyCode]' => captcha,
      },
    ) { |response, request, result, &block|
        case response.code
        when 302
          progress.call(100, '成功登录。')

          Thread.new do
            f = Fetch.new({
              cellphone: params[:username],
              password:  params[:password],
              PHPSESSID: response.cookies['PHPSESSID'],
              TOKEN:     response.cookies['TOKEN'],
              USERID:    response.cookies['USERID'],
            })
            begin
              f.get &progress
              progress.call(100, '已完成', true)
            rescue Exception => e
              puts f.current_url
              puts e.inspect
              puts e.backtrace
              progress.call(100, '获取数据的时候发生错误。', true)
            end
          end

          render json: {
            cookies: response.cookies.slice('PHPSESSID', 'TOKEN', 'USERID'),
          }
        else
          progress.call(100, '登录名、密码或验证码错误。', true)
          render json: { message: 'Bad username, password or captcha.' }, status: 422
        end
      }
  end

  def destroy
    Client.transaction do
      @client = Client.find(params[:id])
      @client.contracts.delete_all
      @client.orders.delete_all
      @client.order_groups.delete_all
      if @client.info['download']
        f = Rails.root.join('public').to_s + @client.info['download']
        File.unlink(f) if File.file?(f)
      end
      @client.info['download'] = nil
      @client.save
    end
    render json: 'OK'
  end

  def fetch
    username, password = params[:username], params[:password]
    phpsessid, token, userid = params[:phpsessid], params[:token], params[:userid]
    Thread.new do
      begin
        f = Fetch.new({
          cellphone: username,
          password:  password,
          PHPSESSID: phpsessid,
          TOKEN:     token,
          USERID:    userid,
        })
        f.get
      rescue Exception => e
        puts f.current_url
        puts e.inspect
        puts e.backtrace
      end
    end
    render json: { message: 'fetch started' }
  end

  def downloads
    client = Client.find(params[:id])
    files_go = client.files_go
    shasum = Digest::SHA1.hexdigest(files_go)
    path = Rails.root.join('public', 'downloads', "#{shasum}.exe")
    download = path.to_s[Rails.root.join('public').to_s.size..-1]
    exists = File.file?(path)

    @progress = 0
    progress = Proc.new do |status, increment = 1, final = false|
      ActionCable.server.broadcast 'messages', {
        type: 'download',
        client_id: client.id,
        progress: (@final ||= final) ? 100 : [ @progress += increment, 99 ].min.round(1),
        status: status.present? ? (@status = status) : @status
      }
    end

    if not exists
      Thread.new do
        fake = Thread.new do
          loop do
            progress.call(nil, 0.1)
            sleep 0.2
          end
        end
        container = Docker::Container.create('Cmd' => ['/dlfiles.exe'], 'Image' => 'dlfiles')
        begin
          container.store_file("#{container.json.dig('Config', 'WorkingDir')}/files.go", files_go)
          container.start
          container.streaming_logs(stdout: true, stderr: true, follow: true) { |_, status|
            progress.call(status.strip)
          }
          container.wait
          data = ''
          container.copy('/dlfiles.exe') do |chunk|
            data << chunk
          end
          Gem::Package::TarReader.new(StringIO.new(data)).seek('dlfiles.exe') do |entry|
            File.binwrite(path, entry.read)
          end
          client.info['download'] = download
          client.save
          progress.call('Done', 1, true)
        rescue Exception => e
          progress.call(e.inspect, 1, true)
        ensure
          container.delete(force: true)
          fake.kill
        end
      end
    end
    render json: {
      url: download,
      exists: exists,
    }
  end
end
