module Trestle
  module Auth
    module Otp
      module Backend
        def authenticate!
          candidate = authenticate_password
          return unless candidate
          return if candidate.otp_module? && !candidate.authenticate_otp(otp_login_params[:otp_code_token], expected_signature: candidate.otp_session_signature)

          complete_otp_login!(candidate, remember: otp_login_params[:remember_me])
        end

        def authenticate_password
          credentials = otp_login_params
          identifier = credentials[Trestle.config.auth.authenticate_with]
          password = credentials[:password]
          return unless identifier.is_a?(String) && identifier.bytesize.between?(1, 1024)
          return unless password.is_a?(String) && password.bytesize.between?(1, 1024)
          if is_a?(Trestle::Auth::Backends::Warden)
            request.env["devise.allow_params_authentication"] = true
            warden.logout(scope)
            # Remember cookies and existing sessions cannot replace this password check.
            candidate = warden.authenticate(:database_authenticatable, scope: scope, store: false)
            warden.logout(scope)
          else
            candidate = Trestle.config.auth.authenticate(otp_login_params)
          end
          return unless candidate.respond_to?(:otp_session_signature)
          return unless candidate.is_a?(Trestle.config.auth.user_class)
          return unless Trestle.config.auth.user_scope.exists?(candidate.id)
          candidate
        end

        def complete_otp_login!(record, remember: false)
          @otp_login_verified = true
          record.remember_me = false if record.otp_module? && record.respond_to?(:remember_me=)
          login!(record)
          # Password-only remember cookies never become trusted-device credentials.
          remember_me! if !record.otp_module? && remember && Trestle.config.auth.remember.enabled && respond_to?(:remember_me!, true)
          if !record.otp_module? && remember && Trestle.config.auth.remember.enabled
            cookies.signed[:trestle_otp_remember_proof] = {value: session[:trestle_otp_auth],
              expires: Time.current + Trestle.config.auth.remember.for, httponly: true,
              secure: request.ssl?, same_site: :lax}
          else
            cookies.delete(:trestle_otp_remember_proof)
          end
          record
        ensure
          @otp_login_verified = false
        end

        def login!(record)
          return unless record.respond_to?(:otp_session_signature)
          return unless @otp_login_verified || !record.otp_module? || otp_session_valid?(record)
          super
          if record.respond_to?(:otp_session_signature)
            session[:trestle_otp_auth] = {"id" => record.id.to_s, "scope" => scope.to_s,
              "version" => record.otp_session_signature}
          end
          record
        end

        def user
          record = super
          otp_session_valid?(record) ? record : nil
        end

        def logged_in?
          !!user
        end

        def authenticate
          super
          user
        end

        def logout!
          super
          session.delete(:trestle_otp_auth)
          session.delete(:trestle_otp_challenge)
          session.delete(:trestle_otp_enrollment)
          cookies.delete(:trestle_otp_remember_proof)
        end

      private
        def otp_login_params
          raw = controller.params[scope]
          return ActionController::Parameters.new unless raw.is_a?(ActionController::Parameters)
          raw.permit(Trestle.config.auth.authenticate_with, :password, :remember_me, :otp_code_token)
        end

        def otp_session_valid?(record)
          return false unless record
          return false unless record.respond_to?(:otp_session_signature)
          return false unless record.is_a?(Trestle.config.auth.user_class)
          return false unless Trestle.config.auth.user_scope.exists?(record.id)
          proof = session[:trestle_otp_auth]
          proof ||= cookies.signed[:trestle_otp_remember_proof] unless record.otp_module?
          valid = proof.is_a?(Hash) && proof["id"] == record.id.to_s && proof["scope"] == scope.to_s &&
            proof["version"].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(proof["version"], record.otp_session_signature)
          session[:trestle_otp_auth] = proof if valid
          valid
        end
      end
    end
  end
end
