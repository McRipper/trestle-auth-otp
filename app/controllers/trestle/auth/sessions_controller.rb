class Trestle::Auth::SessionsController < Trestle::ApplicationController
  layout 'trestle/auth'

  skip_before_action :authenticate_user, only: [:new, :create]
  skip_before_action :require_authenticated_user

  def new; end

  def create
    if user = Trestle.config.auth.authenticate(params)

      if user&.otp_module?
        if params[:otp_code_token].size > 0
          if user.authenticate_otp(params[:otp_code_token], drift: 60)
            continue_sign_in(user)
          else
            logout!
            flash[:error] = t('admin.auth.error', default: 'Bad Credentials Supplied.')
            redirect_to instance_exec(&Trestle.config.auth.redirect_on_login)
          end
        else
          logout!
          flash[:error] = t('admin.auth.error', default: 'Your account needs to supply a token.')
          redirect_to instance_exec(&Trestle.config.auth.redirect_on_login)
        end
      else
        continue_sign_in(user)
      end
    else
      flash[:error] = t('admin.auth.error', default: 'Incorrect login details.')
      redirect_to action: :new
    end
  end

  def destroy
    logout!
    redirect_to instance_exec(&Trestle.config.auth.redirect_on_logout)
  end

  private

  def continue_sign_in(user)
    login!(user)
    remember_me! if params[:remember_me] == '1'
    redirect_to previous_location || instance_exec(&Trestle.config.auth.redirect_on_login)
  end
end

