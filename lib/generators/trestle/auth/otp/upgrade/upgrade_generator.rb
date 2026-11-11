module Trestle
  module Auth
    module Otp
      module Generators
        class UpgradeGenerator < Rails::Generators::Base
          include Rails::Generators::Migration
          argument :model, type: :string, default: "Administrator"
          source_root File.expand_path("templates", __dir__)

          def generate_migration
            migration_template "migration.rb.erb", "db/migrate/secure_otp_for_#{table_name}.rb"
          end

          def self.next_migration_number(dirname)
            ActiveRecord::Migration.next_migration_number(current_migration_number(dirname) + 1)
          end

        private
          def table_name
            klass = model.safe_constantize
            klass && klass.respond_to?(:table_name) ? klass.table_name : model.demodulize.tableize
          end
        end
      end
    end
  end
end
