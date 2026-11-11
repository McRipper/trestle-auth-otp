require "rails_helper"

RSpec.describe "OTP settings", type: :request do
  let!(:user) { Administrator.create!(email: "admin@example.com", password: "password") }

  def sign_in
    post "/admin/login", params: {user: {email: user.email, password: "password"}}
  end

  def start_setup
    sign_in
    post "/admin/otp/setup", params: {password: "password"}
    follow_redirect!
    document = Nokogiri::HTML(response.body)
    document.at_css("details code").text
  end

  it "protects security settings from unauthenticated access" do
    get "/admin/otp"
    expect(response).to redirect_to("/admin/login")
  end

  it "requires password reauthentication before showing the QR" do
    sign_in
    post "/admin/otp/setup", params: {password: "wrong"}
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include("<svg")
    get "/admin/otp/enrollment"
    expect(response).to redirect_to("/admin/otp")
  end

  it "enables only after confirmation, shows codes once and hides the secret afterwards" do
    secret = start_setup
    qr = Nokogiri::HTML(response.body).at_css("svg")
    expect(qr).not_to be_nil
    expect(qr["xmlns"]).to eq("http://www.w3.org/2000/svg")
    expect(qr.css("path, rect")).not_to be_empty
    expect(user.reload.otp_module?).to be false
    expect(response.headers["Cache-Control"]).to include("no-store")
    post "/admin/otp/enable", params: {otp_code_token: "invalid"}
    expect(user.reload.otp_module?).to be false
    post "/admin/otp/enable", params: {otp_code_token: ROTP::TOTP.new(secret).now}
    expect(user.reload.otp_module?).to be true
    codes = Nokogiri::HTML(response.body).css("li code").map(&:text)
    expect(codes.size).to eq(10)
    expect(response.headers["Cache-Control"]).to include("no-store")
    get "/admin/otp"
    expect(response.body).not_to include(secret, codes.first)
    get "/admin/otp/enrollment"
    expect(response).to redirect_to("/admin/otp")
    post "/admin/otp/enable", params: {otp_code_token: ROTP::TOTP.new(secret).now}
    expect(response).to redirect_to("/admin/otp")
  end

  it "does not enable from an expired enrollment" do
    secret = start_setup
    Timecop.travel(Time.current + 6.minutes) do
      post "/admin/otp/enable", params: {otp_code_token: ROTP::TOTP.new(secret).now}
      expect(response).to redirect_to("/admin/otp")
      expect(user.reload.otp_module?).to be false
    end
  end

  it "cannot reveal another administrator's QR or secret" do
    other = Administrator.create!(email: "other@example.com", password: "password")
    enable_otp_for(other)
    sign_in
    get "/admin/auth/administrators/#{other.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(other.otp_secret_key, "<svg")
    expect(response.body).not_to include('name="administrator[otp_module]"')
  end

  it "revokes an existing session when OTP is enabled elsewhere" do
    sign_in
    enable_otp_for(user)
    get "/admin"
    expect(response).to redirect_to("/admin/login")
  end

  it "requires both factors to disable and revokes the current login" do
    codes = enable_otp_for(user)
    sign_in
    post "/admin/otp/challenge", params: {otp_code_token: user.otp_code}
    delete "/admin/otp", params: {password: "wrong", otp_code_token: codes.first}
    expect(user.reload.otp_module?).to be true
    delete "/admin/otp", params: {password: "password", otp_code_token: codes.first}
    expect(response).to redirect_to("/admin/login")
    expect(user.reload.otp_module?).to be false
    get "/admin"
    expect(response).to redirect_to("/admin/login")
  end

  it "replaces recovery codes and keeps only the current session" do
    codes = enable_otp_for(user)
    sign_in
    post "/admin/otp/challenge", params: {otp_code_token: codes.first}
    other = ActionDispatch::Integration::Session.new(Rails.application)
    other.post "/admin/login", params: {user: {email: user.email, password: "password"}}
    other.post "/admin/otp/challenge", params: {otp_code_token: codes.second}
    old_signature = other.request.session[:trestle_otp_auth]["version"]
    post "/admin/otp/recovery-codes", params: {password: "password", otp_code_token: codes.third}
    expect(Nokogiri::HTML(response.body).css("li code").size).to eq(10)
    expect(user.reload.otp_session_signature).not_to eq(old_signature)
    get "/admin"
    expect(response).to have_http_status(:ok)
    other.get "/admin"
    expect(other.response.status).to eq(302)
    expect(other.response.location).to end_with("/admin/login")
  end

  it "rejects a tampered update to another user's OTP state" do
    sign_in
    patch "/admin/auth/administrators/#{user.id}", params: {administrator: {otp_module: true, otp_secret_key: Administrator.otp_random_secret}}
    expect(user.reload.otp_module?).to be false
    expect(user.otp_secret_key).to be_nil
  end

  it "hides internal security fields from automatic Trestle tables and forms" do
    other = Administrator.create!(email: "automatic@example.test", password: "password")
    enable_otp_for(other)
    sign_in
    ["/admin/automatic_administrators", "/admin/automatic_administrators/#{other.id}/edit"].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other.otp_secret_key, other.otp_session_token,
        other.password_digest, 'name="administrator[otp_module]"', 'name="administrator[otp_secret_key]"')
    end
  end
end
