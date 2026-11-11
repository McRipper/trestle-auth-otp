module Trestle
  module Auth
    module Otp
      class Engine < ::Rails::Engine
        initializer "trestle.auth.otp.filter_parameters" do |app|
          app.config.filter_parameters += [:otp_code_token, :otp_secret_key, :otp_recovery_code,
            :otp_recovery_codes_digest, :otp_session_token]
        end

        config.to_prepare do
          controller = Trestle::Auth::SessionsController
          controller.prepend(Trestle::Auth::Otp::SessionsControllerMethods) unless controller < Trestle::Auth::Otp::SessionsControllerMethods
          controller.protect_from_forgery with: :exception, prepend: true
        end
      end
    end
  end
end
