require "rails_helper"

describe Trestle::Auth::Otp::ModelMethods do
  subject(:model) { Administrator }

  describe ".authenticate" do
    before(:each) do
      @user = model.create!(email: "test@example.com", password: "password", first_name: "Test", last_name: "Example", otp_module: true)
    end

    it "returns the user matching the given identifier, password and token" do
      user = model.authenticate("test@example.com", "password")
      expect(user).to eq(@user)
    end

    it "returns nil if the token is incorrect for the user matching the given identifier" do
      user = model.authenticate("test@example.com", "incorrect")
      expect(user).to be_nil
    end
  end
end
