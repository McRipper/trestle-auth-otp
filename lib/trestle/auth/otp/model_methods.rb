module Trestle
  module Auth
    module Otp
      module ModelMethods
        extend ActiveSupport::Concern
        SECURITY_ATTRIBUTES = %w[otp_secret_key otp_module otp_last_used_at
          otp_recovery_codes_digest otp_session_token otp_failed_attempts otp_locked_until].freeze

        # active_model_otp includes its own implementation into the model. Prepend
        # this guard so that no caller can fall back to its reusable verifier.
        module Verification
          def authenticate_otp(code, options = {})
            otp_attempt do
              next false if options[:expected_signature] && !same_otp_signature?(options[:expected_signature])
              otp_module? && consume_otp_factor(code)
            end
          end
        end

        included do
          # Read legacy plaintext during the documented upgrade; all writes encrypt.
          encrypts :otp_secret_key, support_unencrypted_data: true
          has_one_time_password if: :otp_module?
          prepend Verification
          before_validation :initialize_otp_session_token, on: :create
          validate :otp_attributes_are_managed
        end

        def otp_session_signature
          password_hash = respond_to?(:encrypted_password) ? encrypted_password : password_digest
          Digest::SHA256.hexdigest([otp_session_token, password_hash].join(":"))
        end

        def otp_authorize_setup(password)
          otp_attempt { !otp_module? && otp_password_valid?(password) }
        end

        # Plaintext recovery codes are returned only to this operation's caller.
        def enable_otp!(secret:, code:, expected_signature:)
          otp_attempt do
            next false if otp_module? || !same_otp_signature?(expected_signature)
            verified_at = verify_totp(secret, code)
            next false unless verified_at

            self.otp_secret_key = secret
            self.otp_module = true
            self.otp_last_used_at = verified_at
            rotate_otp_recovery_codes
          end
        end

        def disable_otp!(password:, code:)
          otp_attempt do
            next false unless otp_module? && otp_password_valid?(password) && consume_otp_factor(code)

            self.otp_module = false
            self.otp_secret_key = nil
            self.otp_last_used_at = nil
            self.otp_recovery_codes_digest = "[]"
            revoke_otp_sessions
            true
          end
        end

        def regenerate_otp_recovery_codes!(password:, code:)
          otp_attempt do
            next false unless otp_module? && otp_password_valid?(password) && consume_otp_factor(code)
            rotate_otp_recovery_codes
          end
        end

        def otp_recovery_codes_remaining
          otp_recovery_digests.size
        end

        def serializable_hash(options = nil)
          super((options || {}).merge(except: Array(options && options[:except]) + SECURITY_ATTRIBUTES))
        end

      private
        def initialize_otp_session_token
          self.otp_session_token ||= SecureRandom.hex(32)
        end

        def otp_attributes_are_managed
          changed = SECURITY_ATTRIBUTES.any? { |name| will_save_change_to_attribute?(name) }
          if new_record?
            changed = otp_module? || otp_secret_key.present? || otp_last_used_at.present? ||
              otp_recovery_codes_digest.to_s != "[]" || otp_failed_attempts.to_i != 0 || otp_locked_until.present?
          end
          errors.add(:base, "Manage two-factor authentication from your security settings") if changed && !@managing_otp
        end

        # Verification, consumption and attempt counters share the same row lock.
        def otp_attempt
          result = false
          with_lock do
            next if otp_locked_until && otp_locked_until > Time.current
            if otp_locked_until
              self.otp_failed_attempts = 0
              self.otp_locked_until = nil
            end

            result = yield
            if result
              self.otp_failed_attempts = 0
              self.otp_locked_until = nil
            else
              self.otp_failed_attempts = otp_failed_attempts.to_i + 1
              self.otp_locked_until = Time.current + otp_options.lock_duration if otp_failed_attempts >= otp_options.max_attempts
            end
            @managing_otp = true
            save!
          ensure
            @managing_otp = false
          end
          result
        end

        def otp_options
          Trestle.config.auth.otp
        end

        def otp_password_valid?(password)
          return false unless password.is_a?(String) && password.bytesize.between?(1, 1024)
          respond_to?(:valid_password?) ? valid_password?(password) : !!authenticate(password)
        end

        def same_otp_signature?(signature)
          signature.is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(otp_session_signature, signature)
        end

        def normalize_otp_code(code)
          code.gsub(/[ \t\r\n-]/, "").downcase if code.is_a?(String) && code.bytesize <= 128
        end

        def verify_totp(secret, code, after: nil)
          normalized = normalize_otp_code(code)
          return false unless normalized&.match?(/\A[0-9]{6}\z/)
          return false unless secret.is_a?(String) && secret.match?(/\A[a-z2-7]{16,128}\z/i)

          ROTP::TOTP.new(secret).verify(normalized, drift_behind: otp_options.drift,
            drift_ahead: otp_options.drift, after: after)
        rescue ArgumentError
          false
        end

        def consume_otp_factor(code)
          verified_at = verify_totp(otp_secret_key, code, after: otp_last_used_at)
          if verified_at
            self.otp_last_used_at = verified_at
            return true
          end

          normalized = normalize_otp_code(code)
          return false unless normalized&.match?(/\A[a-f0-9]{20}\z/)
          digest = recovery_code_digest(normalized)
          digests = otp_recovery_digests
          index = digests.index { |candidate| ActiveSupport::SecurityUtils.secure_compare(candidate, digest) }
          return false unless index

          digests.delete_at(index)
          self.otp_recovery_codes_digest = JSON.generate(digests)
          true
        end

        def otp_recovery_digests
          parsed = JSON.parse(otp_recovery_codes_digest.presence || "[]")
          parsed.is_a?(Array) ? parsed.select { |value| value.is_a?(String) && value.match?(/\A[a-f0-9]{64}\z/) } : []
        rescue JSON::ParserError
          []
        end

        def recovery_code_digest(code)
          Digest::SHA256.hexdigest("#{otp_session_token}:#{code}")
        end

        def rotate_otp_recovery_codes
          revoke_otp_sessions
          codes = Array.new(otp_options.recovery_codes_count) { SecureRandom.hex(10).scan(/.{4}/).join("-") }
          self.otp_recovery_codes_digest = JSON.generate(codes.map { |code| recovery_code_digest(normalize_otp_code(code)) })
          codes
        end

        def revoke_otp_sessions
          self.otp_session_token = SecureRandom.hex(32)
          self.remember_token = nil if has_attribute?(:remember_token)
          self.remember_token_expires_at = nil if has_attribute?(:remember_token_expires_at)
          self.remember_created_at = nil if has_attribute?(:remember_created_at)
        end
      end
    end
  end
end
