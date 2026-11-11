require "rails_helper"

RSpec.describe "OTP login", type: :request do
  shared_examples "a protected second factor" do |backend, user_class, scope|
    let(:user) { user_class.create!(email: "admin@example.com", password: "password") }
    let!(:recovery_codes) { enable_otp_for(user) }

    before do
      Trestle.config.auth.backend = backend
      Trestle.config.auth.user_class = -> { user_class }
    end

    def password_step(scope, password: "password", remember: false)
      post "/admin/login", params: {scope => {email: "admin@example.com", password: password, remember_me: remember}}
    end

    it "does not create an authenticated session after the password" do
      password_step(scope)
      expect(response).to redirect_to("/admin/otp/challenge")
      get "/admin"
      expect(response).to redirect_to("/admin/login")
    end

    it "rejects missing, array and invalid OTP values without server errors" do
      password_step(scope)
      [nil, ["123456"], "invalid"].each do |code|
        post "/admin/otp/challenge", params: {otp_code_token: code}
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "completes authentication with a valid current code" do
      password_step(scope)
      post "/admin/otp/challenge", params: {otp_code_token: user.otp_code}
      expect(response).to redirect_to("/admin")
      get "/admin"
      expect(response).to have_http_status(:ok)
    end

    it "accepts a recovery code once, including in another browser" do
      password_step(scope)
      post "/admin/otp/challenge", params: {otp_code_token: recovery_codes.first, recovery: "1"}
      expect(response).to redirect_to("/admin")
      other = ActionDispatch::Integration::Session.new(Rails.application)
      other.post "/admin/login", params: {scope => {email: user.email, password: "password"}}
      other.post "/admin/otp/challenge", params: {otp_code_token: recovery_codes.first}
      expect(other.response).to have_http_status(:unprocessable_content)
    end

    it "rejects TOTP replay across independent browser sessions" do
      code = user.otp_code
      password_step(scope)
      post "/admin/otp/challenge", params: {otp_code_token: code}
      other = ActionDispatch::Integration::Session.new(Rails.application)
      other.post "/admin/login", params: {scope => {email: user.email, password: "password"}}
      other.post "/admin/otp/challenge", params: {otp_code_token: code}
      expect(other.response).to have_http_status(:unprocessable_content)
    end

    it "expires a pending challenge without renewing it on page loads" do
      password_step(scope)
      Timecop.travel(Time.current + 6.minutes) do
        post "/admin/otp/challenge", params: {otp_code_token: user.otp_code}
        expect(response).to redirect_to("/admin/login")
      end
    end

    it "does not permit an OTP request without a password challenge" do
      post "/admin/otp/challenge", params: {otp_code_token: user.otp_code}
      expect(response).to redirect_to("/admin/login")
    end

    it "does not create persistent remember cookies for an MFA account" do
      password_step(scope, remember: true)
      post "/admin/otp/challenge", params: {otp_code_token: user.otp_code}
      expect(cookies["trestle_remember_token"]).to be_blank
      expect(cookies["remember_devise_user_token"]).to be_blank
      expect(cookies["trestle_otp_remember_proof"]).to be_blank
    end

    it "rejects malformed password parameters without a server error" do
      password_step(scope, password: ["password"])
      expect(response).to redirect_to("/admin/login")
    end

    it "invalidates pending verification after a password change" do
      password_step(scope)
      user.update!(password: "new-test-password")
      post "/admin/otp/challenge", params: {otp_code_token: user.otp_code}
      expect(response).to redirect_to("/admin/login")
    end

    it "rejects users outside the configured admin scope" do
      Trestle.config.auth.user_scope = -> { user_class.where(id: -1) }
      password_step(scope)
      expect(response).to redirect_to("/admin/login")
    end

    it "rejects a missing secret without a server error" do
      user.update_columns(otp_secret_key: nil)
      password_step(scope)
      post "/admin/otp/challenge", params: {otp_code_token: "123456"}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context "Basic" do
    include_examples "a protected second factor", :basic, Administrator, :user
  end

  context "Devise" do
    include_examples "a protected second factor", :devise, DeviseUser, :devise_user

    it "rejects an existing Devise session without an OTP proof" do
      Warden.test_mode!
      Warden.on_next_request { |proxy| proxy.set_user(user, scope: :devise_user) }
      get "/admin"
      expect(response).to redirect_to("/admin/login")
    ensure
      Warden.test_reset!
    end
  end

  it "filters secrets and verification codes from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("otp_code_token" => "123456", "otp_secret_key" => "secret", "otp_session_token" => "secret")
    expect(filtered.values).to all(eq("[FILTERED]"))
  end
end
