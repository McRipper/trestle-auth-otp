module Trestle
  module Auth
    module Otp
      module ControllerMethods
      private
        def otp_no_cache
          response.headers["Cache-Control"] = "no-store, private"
          response.headers["Pragma"] = "no-cache"
          # Keep same-origin form submissions compatible with Rails origin checks.
          response.headers["Referrer-Policy"] = "same-origin"
        end

        def otp_reset_and_login(user, remember: false)
          return_to = session[:trestle_return_to]
          reset_session
          @_authentication_backend = nil
          authentication_backend.complete_otp_login!(user, remember: remember)
          return_to
        end

        def otp_login_destination(return_to)
          return_to.presence || instance_exec(&Trestle.config.auth.redirect_on_login)
        end

        def otp_pending_user(key)
          pending = session[key]
          return unless pending.is_a?(Hash) && pending["expires_at"].is_a?(Integer)
          return unless pending["expires_at"] > Time.current.to_i && pending["scope"] == authentication_scope.to_s
          user = Trestle.config.auth.user_scope.find_by(id: pending["id"])
          return unless user.respond_to?(:otp_session_signature) && pending["version"].is_a?(String)
          user if ActiveSupport::SecurityUtils.secure_compare(user.otp_session_signature, pending["version"])
        end

        def otp_pending_data(user)
          {"id" => user.id.to_s, "scope" => authentication_scope.to_s,
            "version" => user.otp_session_signature,
            "expires_at" => (Time.current + Trestle.config.auth.otp.challenge_ttl).to_i}
        end

        def otp_scalar_param(name)
          value = params[name]
          value if value.is_a?(String) && value.bytesize <= 1024
        end
      end
    end
  end
end
