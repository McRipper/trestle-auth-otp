class Trestle::Auth::Otp::SettingsController < Trestle::ApplicationController
  include Trestle::Auth::Otp::ControllerMethods
  layout "trestle/auth"
  protect_from_forgery with: :exception, prepend: true
  before_action :otp_no_cache

  def show
    session.delete(:trestle_otp_enrollment)
  end

  def setup
    unless current_user.otp_authorize_setup(otp_scalar_param(:password))
      @otp_error = t("admin.otp.change_failed")
      return render :show, status: :unprocessable_content
    end
    session[:trestle_otp_enrollment] = otp_pending_data(current_user).merge("otp_secret_key" => current_user.class.otp_random_secret)
    redirect_to otp_enrollment_path, status: :see_other
  end

  def enrollment
    return unless require_enrollment
    @otp_uri = ROTP::TOTP.new(@otp_enrollment["otp_secret_key"], issuer: Trestle.config.site_title.to_s).provisioning_uri(current_user.email.to_s)
  end

  def enable
    return unless require_enrollment
    user = current_user
    @recovery_codes = user.enable_otp!(secret: @otp_enrollment["otp_secret_key"],
      code: otp_scalar_param(:otp_code_token), expected_signature: @otp_enrollment["version"])
    if @recovery_codes
      otp_reset_and_login(user)
      render :recovery_codes
    else
      @otp_error = t("admin.otp.invalid_code")
      @otp_uri = ROTP::TOTP.new(@otp_enrollment["otp_secret_key"], issuer: Trestle.config.site_title.to_s).provisioning_uri(current_user.email.to_s)
      render :enrollment, status: :unprocessable_content
    end
  end

  def recovery_codes
    user = current_user
    @recovery_codes = user.regenerate_otp_recovery_codes!(password: otp_scalar_param(:password), code: otp_scalar_param(:otp_code_token))
    if @recovery_codes
      otp_reset_and_login(user)
      render :recovery_codes
    else
      @otp_error = t("admin.otp.change_failed")
      @otp_section = :recovery
      render :show, status: :unprocessable_content
    end
  end

  def destroy
    if current_user.disable_otp!(password: otp_scalar_param(:password), code: otp_scalar_param(:otp_code_token))
      authentication_backend.logout!
      reset_session
      flash[:notice] = t("admin.otp.disabled_notice")
      redirect_to login_path, status: :see_other
    else
      @otp_error = t("admin.otp.change_failed")
      @otp_section = :disable
      render :show, status: :unprocessable_content
    end
  end

private
  def require_enrollment
    user = otp_pending_user(:trestle_otp_enrollment)
    @otp_enrollment = session[:trestle_otp_enrollment]
    return true if user && user.id == current_user.id && !user.otp_module? && @otp_enrollment["otp_secret_key"].is_a?(String)
    session.delete(:trestle_otp_enrollment)
    flash[:error] = t("admin.otp.challenge_expired")
    redirect_to otp_settings_path, status: :see_other
    false
  end
end
