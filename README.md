# Trestle Authentication One Time Password

Authenticator-app verification and single-use recovery codes for Trestle 0.10.1
and trestle-auth 0.5.0, using Active Record >= 7.1 and < 9, and Ruby 3.2+.

The supported dependency series are ROTP 6.4, RQRCode 3.2 and rqrcode_core 2.1
(with compatible updates below their next major versions). The plugin uses ROTP
directly and no longer depends on `active_model_otp`, whose released 2.3.4 version
restricts ROTP to 6.3.x. `otp_random_secret`, `otp_code` (including explicit times)
and `provisioning_uri` remain available on OTP-enabled models. If an application
declares `active_model_otp` separately, that dependency must also be migrated or
updated before Bundler can resolve ROTP 6.4. Its global `has_one_time_password`
macro and optional HOTP/backup-code APIs are not supplied by this plugin.
This dependency update does not require an additional schema migration or
regeneration of secrets for applications already using the 0.3.0 schema.

## Install

Add `gem 'trestle-auth-otp'` to the application's Gemfile and run `bundle install`.
For the Basic backend:

```sh
rails generate trestle:auth:install
rails generate trestle:auth:otp:install Administrator
rails db:migrate
```

For a Devise user model, install trestle-auth's Devise integration first, then run:

```sh
rails generate trestle:auth:otp:install User --devise
rails db:migrate
```

The Devise model also needs `Trestle::Auth::Otp::ModelMethods`. The generator
adds it. Set `config.auth.user_class`, `config.auth.user_scope` and
`config.auth.warden.scope` to the correct admin model/scope. Users outside the
configured admin scope cannot use a pending challenge to enter Trestle.

Configure the host application's Active Record encryption keys before enrollment
(`rails db:encryption:init`). Keep the primary key, deterministic key and key
derivation salt in Rails credentials or the host's secret management system.
The plugin does not generate production encryption keys or send email.

## Upgrade from 0.2.x

Version 0.3 changes the login flow and requires a schema migration. Deploy the
schema and encryption configuration before serving requests with the new code:

```sh
rails generate trestle:auth:otp:upgrade Administrator
rails db:migrate
```

Run the generator for the actual model (and separately for each admin model if
needed). A Devise model that never had OTP columns needs the install migration
instead of the upgrade migration. Preserve the existing `otp_secret_key` values:
**do not regenerate existing users' secrets**.

Existing plaintext secrets remain readable during the transition. After configuring
the encryption keys and backing up the database, encrypt them in place:

```ruby
Administrator.find_each(&:encrypt)
```

Verify the stored values are encrypted and retain the encryption keys for future
reads. Remove old `otp_module` checkboxes and QR/secret displays from custom admin
forms. OTP fields are protected from ordinary attribute updates; users now manage
their own factor from the security page. Automatic Trestle tables and forms omit
OTP internals and credential hashes for OTP-enabled model classes. Existing
sessions without the new proof must sign in again. Existing OTP users can create
recovery codes after signing in.

## User flow

The admin header links to **Two-factor authentication** at `/admin/otp` (relative
to the configured Trestle mount path).

1. Confirm the current password, then scan the QR with an authenticator app.
2. Enter a valid app code to activate the factor. Setup expires after five minutes.
3. Save the ten recovery codes. They are shown only in the successful POST response,
   never stored in the session or redisplayed by a GET. Each code works once.
4. Subsequent logins verify password first, then an app code or recovery code.
   A pending password challenge grants no admin access and expires after five minutes.

The setup QR/key is shown only during the current user's pending enrollment.
Replacing recovery codes or disabling OTP requires password and a current factor.
Both operations revoke other sessions and remembered logins. Disabling also signs
out the current session; enabling/replacing keeps the reauthenticated session.
Codes used to confirm enrollment or change settings are consumed too.

The **Remember me** option remains available for password-only accounts. It does
not trust a device for MFA accounts: a new session requires a second factor.
External Devise sessions and password-reset sign-ins do not themselves establish
the Trestle OTP proof. Standard Devise database authentication is supported;
custom Warden strategies need an explicit integration rather than bypassing OTP.

## Security behavior and configuration

TOTP intervals and recovery codes are consumed under an Active Record row lock.
Five failed factor/reauthentication attempts pause verification for five minutes.
Secrets are encrypted and recovery codes are stored as salted SHA-256 hashes of
80-bit random codes. OTPs, secrets and security tokens are filtered from Rails
request logs and excluded from ordinary record serialization.

```ruby
Trestle.configure do |config|
  config.auth.otp.challenge_ttl = 5.minutes
  config.auth.otp.max_attempts = 5
  config.auth.otp.lock_duration = 5.minutes
  config.auth.otp.drift = 30 # seconds in each direction
  config.auth.otp.recovery_codes_count = 10
end
```

Use HTTPS and a secure session store in the host, and apply its password-login/IP
rate limits. Account-scoped factor limits are database-backed and work across
processes. Verify any independent login endpoints and instrumentation in the host.
Recovery from losing both the authenticator and all recovery codes needs a
separately authorized identity-verification process; there is no password-only
MFA reset endpoint.

## Development

`bundle exec rspec` runs model, feature, HTTP, CSRF and generator tests. The CI
uses Ruby 3.2/3.3/3.4 with Rails 8.1 and Sprockets/Propshaft. The model tests exercise
stale instances; the explicit concurrency check uses an isolated PostgreSQL
database whose name begins with `trestle_otp_test`:

```sh
RAILS_ENV=test DATABASE_URL=postgresql:///trestle_otp_test bundle exec ruby spec/concurrency/otp_concurrency.rb
```

## License

Based on trestle-auth by Sam Pohlenz. Available under the
[LGPLv3 License](https://opensource.org/licenses/LGPL-3.0).
