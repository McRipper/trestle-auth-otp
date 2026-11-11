require "rails_helper"

feature "Authentication with OTP enabled" do
  before do
    Trestle.config.auth.backend = :basic
    @user = Administrator.create!(first_name: "Admin", last_name: "User",
      email: "admin@example.com", password: "password")
    enable_otp_for(@user)
  end

  scenario "rejects a password without a token" do
    login
    expect(page).to have_current_path("/admin/otp/challenge")
    visit "/admin"
    expect(page).to have_current_path("/admin/login")
  end

  scenario "rejects an invalid token" do
    login(otp_code: "invalid")
    expect(page).to have_current_path("/admin/otp/challenge")
    expect(page).to have_content("invalid, expired or already used")
  end

  scenario "accepts a current token" do
    login(otp_code: @user.otp_code)
    expect(page).to have_current_path("/admin")
    expect(page).to have_content("Admin User")
  end

  scenario "rejects an expired token" do
    token = @user.otp_code
    Timecop.travel(Time.current + 180) do
      login(otp_code: token)
      expect(page).to have_current_path("/admin/otp/challenge")
    end
  end
end
