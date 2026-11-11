module OtpHelpers
  def enable_otp_for(user)
    secret = user.class.otp_random_secret
    codes = nil
    Timecop.freeze(Time.current - 60) do
      codes = user.enable_otp!(secret: secret, code: ROTP::TOTP.new(secret).now,
        expected_signature: user.otp_session_signature)
    end
    raise "OTP fixture enrollment failed" unless codes
    codes
  end
end

RSpec.configure do |config|
  config.include OtpHelpers
end
