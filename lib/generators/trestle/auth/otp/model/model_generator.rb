module Trestle
  module Auth
    module Otp
      module Generators
        class ModelGenerator < ::Rails::Generators::Base
          desc "Add OTP to an Administrator model for use with trestle-auth"

          argument :name, type: :string, default: "Administrator"

          def inject_model_methods
            path = "app/models/#{name.underscore}.rb"
            return if File.read(path).include?("include Trestle::Auth::Otp::ModelMethods")
            inject_into_class path, name, "  include Trestle::Auth::Otp::ModelMethods\n"
          end
        end
      end
    end
  end
end
