module Trestle
  module Auth
    module Otp
      module Generators
        class ModelGenerator < ::Rails::Generators::Base
          desc "Add OTP to an Administrator model for use with trestle-auth"

          argument :name, type: :string, default: "Administrator"

          def inject_model_methods
            inject_into_file "app/models/#{name.underscore}.rb", "  include Trestle::Auth::Otp::ModelMethods\n", before: /^end/
          end
        end
      end
    end
  end
end
