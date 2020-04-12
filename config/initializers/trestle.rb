Trestle.configure do |config|

  config.hook('auth.login.form') do
    render 'trestle/auth/otp'
  end

  config.auth.authenticate = ->(params) {

    scope = Trestle.config.auth.user_scope

    user = scope.authenticate(params[Trestle.config.auth.authenticate_with], params[:password])

    if user && user.otp_module?
      if params[:otp_code_token].present? && user.authenticate_otp(params[:otp_code_token], drift: 60)
        return user
      else
        return false
      end
    else
      return user
    end

  }

end
