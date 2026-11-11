require "rails_helper"

describe Trestle::Auth::Otp::ModelMethods do
  let(:user) { Administrator.create!(email: "test@example.com", password: "password") }

  it "starts disabled without generating an unused secret" do
    expect(user.otp_module?).to be false
    expect(user.otp_secret_key).to be_nil
  end

  it "generates independent 160-bit Base32 secrets and retains custom byte lengths" do
    secret = Administrator.otp_random_secret
    expect(secret).to match(/\A[A-Z2-7]{32}\z/i)
    expect(Administrator.otp_random_secret).not_to eq(secret)
    expect(Administrator.otp_random_secret(10)).to match(/\A[A-Z2-7]{16}\z/i)
  end

  it "retains time-based code helpers using the RFC 6238 SHA1 test secret" do
    account = Administrator.new(otp_secret_key: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
    # The RFC's 8-digit vector at 59 seconds is 94287082; this plugin uses 6 digits.
    Timecop.freeze(Time.at(59).utc) do
      expect(account.otp_code).to eq("287082")
      expect(account.otp_code(time: Time.current)).to eq("287082")
      expect(account.otp_code(Time.current)).to eq("287082")
    end
  end

  it "preserves provisioning account and issuer options for existing integrations" do
    secret = Administrator.otp_random_secret
    account = Administrator.new(email: "alice@example.test", otp_secret_key: secret)
    uri = URI.parse(account.provisioning_uri)
    expect(uri.scheme).to eq("otpauth")
    expect(uri.host).to eq("totp")
    expect(URI.decode_www_form_component(uri.path.delete_prefix("/"))).to eq(account.email)
    expect(URI.decode_www_form(uri.query).to_h.fetch("secret")).to eq(secret)

    uri = URI.parse(account.provisioning_uri("other@example.test", issuer: "Trestle Demo"))
    expect(URI.decode_www_form_component(uri.path.delete_prefix("/"))).to eq("Trestle Demo:other@example.test")
    expect(URI.decode_www_form(uri.query).to_h.fetch("issuer")).to eq("Trestle Demo")
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
