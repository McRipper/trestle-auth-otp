module Trestle
  module Auth
    module Otp
      module ModelMethods
        extend ActiveSupport::Concern
        extend ActiveSupport::Autoload

        included do
          has_one_time_password
        end

      end
    end
  end
end
