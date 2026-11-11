require "trestle/auth/otp/version"

require "trestle"
require "trestle/auth"

require "active_model_otp"
require "rqrcode"
require "digest"
require "json"
require "securerandom"

module Trestle
  module Auth
    module Otp
      extend ActiveSupport::Autoload

      autoload :ModelMethods
      autoload :Backend
      autoload :SessionsControllerMethods
      autoload :ControllerMethods
      autoload :Adapter

      class Configuration
        include Trestle::Configurable

        option :challenge_ttl, 5.minutes
        option :max_attempts, 5
        option :lock_duration, 5.minutes
        option :drift, 30
        option :recovery_codes_count, 10
      end

    end
  end
end

Trestle::Auth::Configuration.option :otp, Trestle::Auth::Otp::Configuration.new

# Protect routing constraints and custom callers as well as the login form.
Trestle::Auth::Backends::Basic.prepend(Trestle::Auth::Otp::Backend)
Trestle::Auth::Backends::Warden.prepend(Trestle::Auth::Otp::Backend)
Trestle::Adapters::ActiveRecordAdapter.prepend(Trestle::Auth::Otp::Adapter)

require "trestle/auth/otp/engine" if defined?(Rails)
