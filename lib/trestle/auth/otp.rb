require "trestle/auth/otp/version"

require "trestle"
require "trestle/auth"

require "active_model_otp"
require "rqrcode"

module Trestle
  module Auth
    module Otp
      extend ActiveSupport::Autoload

      autoload :ModelMethods

    end
  end
end

require "trestle/auth/otp/engine" if defined?(Rails)
