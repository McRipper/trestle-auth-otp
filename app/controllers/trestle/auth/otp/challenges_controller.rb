class Trestle::Auth::Otp::ChallengesController < Trestle::ApplicationController
  include Trestle::Auth::Otp::ControllerMethods
  layout "trestle/auth"
  skip_before_action :authenticate_user
  skip_before_action :require_authenticated_user
  protect_from_forgery with: :exception, prepend: true
  before_action :otp_no_cache
  before_action :require_pending_otp, only: [:new, :create]

  def new
  end

  def create
    if @otp_user.authenticate_otp(otp_scalar_param(:otp_code_token), expected_signature: session[:trestle_otp_challenge]["version"])
      return_to = otp_reset_and_login(@otp_user)
      redirect_to otp_login_destination(return_to), status: :see_other
    else
      @otp_error = t("admin.otp.invalid_code")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session.delete(:trestle_otp_challenge)
    redirect_to login_path, status: :see_other
  end

private
  def require_pending_otp
    @otp_user = otp_pending_user(:trestle_otp_challenge)
    return if @otp_user && @otp_user.otp_module?
    session.delete(:trestle_otp_challenge)
    flash[:error] = t("admin.otp.challenge_expired")
    redirect_to login_path, status: :see_other
  end
end
