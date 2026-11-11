require "rails_helper"

describe Trestle::Auth::Otp::ModelMethods do
  let(:user) { Administrator.create!(email: "test@example.com", password: "password") }

  it "starts disabled without generating an unused secret" do
    expect(user.otp_module?).to be false
    expect(user.otp_secret_key).to be_nil
  end

  it "requires a valid code to activate and encrypts the secret" do
    secret = Administrator.otp_random_secret
    signature = user.otp_session_signature
    expect(user.enable_otp!(secret: secret, code: "invalid", expected_signature: signature)).to be false
    expect(user.reload.otp_module?).to be false
    codes = user.enable_otp!(secret: secret, code: ROTP::TOTP.new(secret).now, expected_signature: signature)
    expect(codes.size).to eq(10)
    expect(user.reload.otp_secret_key).to eq(secret)
    raw_secret = user.read_attribute_before_type_cast(:otp_secret_key)
    expect(raw_secret).not_to include(secret)
    expect(user.otp_recovery_codes_digest).not_to include(codes.first.delete("-"))
    expect(user.authenticate_otp(ROTP::TOTP.new(secret).now)).to be false
  end

  it "prevents changing OTP state through regular account attributes" do
    expect(user.update(otp_module: true)).to be false
    user.reload
    expect(user.update(otp_secret_key: Administrator.otp_random_secret)).to be false
    expect(user.reload.otp_module?).to be false
  end

  it "consumes a TOTP once, including when another model instance is stale" do
    enable_otp_for(user)
    stale_user = Administrator.find(user.id)
    code = user.otp_code
    expect(user.authenticate_otp(code)).to be_truthy
    expect(stale_user.authenticate_otp(code)).to be false
  end

  it "consumes recovery codes once and stores only hashes" do
    codes = enable_otp_for(user)
    expect(user.authenticate_otp(codes.first)).to be_truthy
    expect(Administrator.find(user.id).authenticate_otp(codes.first)).to be false
    expect(user.reload.otp_recovery_codes_remaining).to eq(9)
    expect(user.otp_recovery_codes_digest).not_to include(codes.last.delete("-"))
  end

  it "rejects malformed input and corrupt/missing secrets without exceptions" do
    enable_otp_for(user)
    [nil, ["123456"], {code: "123456"}, "x" * 129].each do |code|
      expect(user.authenticate_otp(code)).to be false
    end
    user.update_columns(otp_secret_key: nil)
    expect(user.authenticate_otp("123456")).to be false
  end

  it "locks repeated failures and permits a new valid code after the pause" do
    enable_otp_for(user)
    5.times { expect(user.authenticate_otp("invalid")).to be false }
    expect(user.reload.otp_locked_until).to be > Time.current
    expect(user.authenticate_otp(user.otp_code)).to be false
    Timecop.travel(Time.current + 6.minutes) do
      expect(user.authenticate_otp(user.otp_code)).to be_truthy
      expect(user.otp_failed_attempts).to eq(0)
    end
  end

  it "requires password and factor to disable, and revokes recovery/session tokens" do
    codes = enable_otp_for(user)
    version = user.otp_session_signature
    expect(user.disable_otp!(password: "wrong", code: codes.first)).to be false
    expect(user.disable_otp!(password: "password", code: codes.first)).to be_truthy
    expect(user.reload.otp_module?).to be false
    expect(user.otp_secret_key).to be_nil
    expect(user.otp_session_signature).not_to eq(version)
    expect(user.otp_recovery_codes_remaining).to eq(0)
  end

  it "replaces recovery codes only after reauthentication and invalidates the old set" do
    codes = enable_otp_for(user)
    signature = user.otp_session_signature
    fresh = user.regenerate_otp_recovery_codes!(password: "password", code: codes.first)
    expect(fresh.size).to eq(10)
    expect(user.otp_session_signature).not_to eq(signature)
    expect(user.authenticate_otp(codes.last)).to be false
    expect(user.authenticate_otp(fresh.first)).to be_truthy
  end

  it "hides security attributes in serialized records" do
    enable_otp_for(user)
    expect(user.serializable_hash.keys & described_class::SECURITY_ATTRIBUTES).to be_empty
  end

  it "rejects a stale challenge signature atomically without consuming a fresh code" do
    codes = enable_otp_for(user)
    old_signature = user.otp_session_signature
    user.regenerate_otp_recovery_codes!(password: "password", code: codes.first)
    code = user.otp_code
    expect(user.authenticate_otp(code, expected_signature: old_signature)).to be false
    expect(user.authenticate_otp(code)).to be_truthy
  end

  it "preserves and encrypts an existing plaintext secret during upgrade" do
    secret = Administrator.otp_random_secret
    ActiveRecord::Encryption.without_encryption do
      user.update_columns(otp_secret_key: secret, otp_module: true)
    end
    expect(user.reload.otp_secret_key).to eq(secret)
    user.encrypt
    expect(user.reload.otp_secret_key).to eq(secret)
    expect(user.read_attribute_before_type_cast(:otp_secret_key)).not_to include(secret)
    expect(user.authenticate_otp(ROTP::TOTP.new(secret).now)).to be_truthy
  end
end
