class HYR
  KEY       = 'b79ff42fc9d045aed383243a'
  TOKEN_KEY = '6y9d6e9332f5428e89d2f8c2'

  attr_reader :name

  def initialize(cellphone = nil, password = nil, uid = nil, ukey = nil)
    @cellphone = cellphone
    @password = password
    @uid = uid
    @ukey = ukey
  end

  def decrypt(data, key = KEY)
    cipher = OpenSSL::Cipher::Cipher.new('des-ede3')
    cipher.key = key
    cipher.decrypt
    plaintext = cipher.update(Base64.strict_decode64(data))
    plaintext << cipher.final
  end

  def encrypt(data, key = KEY)
    cipher = OpenSSL::Cipher::Cipher.new('des-ede3')
    cipher.encrypt
    cipher.key = key
    cipher.iv = '12345678'
    ciphertext = cipher.update(data)
    ciphertext << cipher.final
    Base64.strict_encode64(ciphertext)
  end

  def request(path, form, ukey = '(null)')
    response = HTTP.timeout(write: 2, connect: 3, read: 4).headers(
      'User-Agent' => 'HengYiRong3.0/3.0.2 CFNetwork/808.1.4 Darwin/16.1.0',
    ).post(path, form: {
      'Token'     => encrypt("hengyirong-#{Time.now.to_i}-0", key = TOKEN_KEY),
      'Signature' => encrypt({
        'app_version'      => 'iPhone[10.1.1]',
        'app_from_type'    => '3',
        'app_version_mark' => '3.0.1',
      }.merge(form).to_json),
      'Key'       => ukey,
    })
    JSON(decrypt(response.to_s))
  end

  def get_syt_list
    response = request('https://appport.hengyirong.com/2-0-0/index.php?r=syt/sytlist', {
      'Num'     => '10069',
      'Control' => 'sytlist',
      'offset'  => '0',
      'limit'   => '5',
    })
    return response, response['code'].to_i == 200
  end

  def login
    response = request('https://appport.hengyirong.com/2-0-0/index.php?r=user/login', {
      'Num'      => '10022',
      'Control'  => 'login',
      'islogin'  => '0',
      'usertype' => '1',
      'userpwd'  => Digest::SHA1.hexdigest(@password[0...12] + 'xxxxxxx'),
      'username' => @cellphone,
    })
    is_success = response['code'].to_i == 200
    if is_success
      @ukey = Digest::MD5.hexdigest(response['yzm'])
      @uid = response['data']['id']
      @name = response['data']['real_name']
      @cellphone = response['data']['phone']
    end
    return response, is_success, @uid, @ukey
  end

  def get_info
    response = request('https://appport.hengyirong.com/2-0-0/index.php?r=user/getuser', {
      'Num'     => '10003',
      'Control' => 'getuser',
      'uid'     => @uid,
    }, @ukey)
    return response, response['code'].to_i == 200
  end

  def get_orders
    response = request('https://appport.hengyirong.com/2-0-0/index.php?r=user/Loannotes', {
      'Num'       => '10014',
      'Control'   => 'Loannotes',
      'uid'       => @uid,
      'id'        => '0',
      'offsetmax' => '10',
      'status'    => '2',
    }, @ukey)
    return response, response['code'].to_i == 200
  end

  def pay(type, money, id, way)
    if type == 'dtpay'
      response = request('https://appport.hengyirong.com/2-0-0/index.php?r=dlbpay/confirmationpay', {
        'Num'       => '10016',
        'Control'   => 'confirmationpay',
        'uid'       => @uid,
        'dlbid'     => id.to_s,
        'investway' => way.to_s,
        'money'     => "#{money}.00",
      }, @ukey)
      return response, response['code'] == 200
    elsif type == 'syt'
      response = request('https://appport.hengyirong.com/2-0-0/index.php?r=syt/sytconfirmationpay', {
        'Num'     => '10071',
        'Control' => 'sytconfirmationpay',
        'uid'     => @uid,
        'quid'    => id.to_s,
        'money'   => "#{money}.00",
      }, @ukey)
      return response, response['code'] == 200
    end
  end

  def get_balance
    response = request('https://appsanbiaoapi.hengyirong.com/appios.php/Account/InvestMoneyN/UserIndexApp/', {
      'user_id' => @uid,
    }, @ukey)
    return response.dig('data', 'balance') || 0, response['code'].to_i == 200
  end
end
