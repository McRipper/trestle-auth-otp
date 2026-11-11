module Trestle
  module Auth
    module Otp
      module Adapter
      protected
        def default_attributes
          attributes = super
          return attributes unless model < ModelMethods

          hidden = ModelMethods::SECURITY_ATTRIBUTES + %w[password_digest encrypted_password
            remember_token reset_password_token]
          attributes.reject { |attribute| hidden.include?(attribute.name.to_s) }
        end
      end
    end
  end
end
