module Trestle
  module Auth
    module Otp
      module Generators
        class AdminGenerator < ::Rails::Generators::Base
          desc "Creates a Trestle admin for managing Administrators"

          argument :model, type: :string, default: "Administrator"

          class_option :devise, type: :boolean, default: false, desc: "Create admin for a Devise user model"

          source_root File.expand_path("../templates", __FILE__)

          def create_admin
            template "admin.rb.erb", File.join('app/admin/auth', "#{model.underscore.pluralize}_admin.rb")
          end

          def devise?
            options[:devise]
          end

        protected
          def plural_name
            model.demodulize.underscore.pluralize
          end
        end
      end
    end
  end
end
