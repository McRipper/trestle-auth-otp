require "rails_helper"

RSpec.describe "OTP CSRF protection", type: :request do
  around do |example|
    controllers = [Trestle::Auth::SessionsController, Trestle::Auth::Otp::ChallengesController, Trestle::Auth::Otp::SettingsController]
    previous = controllers.to_h { |controller| [controller, controller.allow_forgery_protection] }
    controllers.each { |controller| controller.allow_forgery_protection = true }
    example.run
  ensure
    previous.each { |controller, value| controller.allow_forgery_protection = value }
  end

  it "rejects forged requests on every state-changing OTP endpoint" do
    [["post", "/admin/login"], ["post", "/admin/otp/challenge"],
      ["delete", "/admin/otp/challenge"], ["post", "/admin/otp/setup"],
      ["post", "/admin/otp/enable"], ["post", "/admin/otp/recovery-codes"],
      ["delete", "/admin/otp"]].each do |method, path|
      public_send(method, path, params: {password: "password", otp_code_token: "123456"})
      expect(response).to have_http_status(:unprocessable_content), "#{method.upcase} #{path} accepted a missing CSRF token"
    end
  end

  it "permits a same-origin login with a valid token and preserves a Rails-compatible referrer policy" do
    Administrator.create!(email: "csrf@example.test", password: "password")
    get "/admin/login"
    expect(response.headers["Referrer-Policy"]).to eq("same-origin")
    token = Nokogiri::HTML(response.body).at_css('input[name="authenticity_token"]')["value"]
    origin = request.base_url
    post "/admin/login", params: {authenticity_token: token, user: {email: "csrf@example.test", password: "password"}}, headers: {"Origin" => origin}
    expect(response).to redirect_to("/admin")
  end
end
