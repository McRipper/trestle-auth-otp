# Changelog

## 0.3.0 (unreleased)

- Verify password and OTP in separate steps, with expiring challenges and no
  authenticated admin session until both factors pass.
- Enforce the factor for both Basic and Devise database authentication, including
  routing constraints and existing Warden sessions.
- Require password reauthentication and a valid app code to enable OTP. Restrict
  the setup QR/key to the account owner's pending enrollment.
- Generate ten single-use recovery codes, show them once and store only hashes.
- Consume TOTP/recovery codes under a database row lock and pause repeated failures.
- Encrypt OTP secrets using host-managed Active Record encryption keys. Filter
  codes/tokens from logs and exclude security attributes from serialization.
- Hide OTP internals and credential hashes from automatic Trestle tables/forms.
- Revoke other sessions and remembered logins after factor/recovery changes.
  Password-only remember cookies cannot bypass OTP.
- Add English/Italian screens with paste/autofill support and mobile-friendly fields.
- Fix generator template mutation, model-specific table selection and Devise model
  installation. Add a migration generator for existing installations.
- Replace active_model_otp with direct ROTP integration, retaining random-secret,
  code-generation and provisioning-URI helpers. Existing enrolled secrets stay valid.
- Require ROTP >= 6.4 and < 7, RQRCode >= 3.2 and < 4, and rqrcode_core >= 2.1 and < 3.
- Require Ruby 3.2+, Active Record >= 7.1 and < 9, Trestle 0.10.1 and trestle-auth 0.5.0.
  See README for the required migration and legacy-secret encryption steps.
