Trestle.configure do |config|

  config.hook('auth.login.form') do
    render 'trestle/auth/otp'
  end

end
