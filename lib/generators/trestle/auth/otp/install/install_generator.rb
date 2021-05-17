module Trestle
  module Auth
    module Otp
      module Generators
        class InstallGenerator < ::Rails::Generators::Base

          include Rails::Generators::Migration

          desc "Installs trestle-auth-otp"

          argument :model, type: :string, default: "Administrator"

          class_option :devise, type: :boolean, default: false, desc: "Setup trestle-auth-otp with Devise integration"

          source_root File.expand_path("../templates", __FILE__)

          def check_trestle_installed
            unless ::File.exist?("config/initializers/trestle.rb")
              raise Thor::Error, "The file config/initializers/trestle.rb does not appear to exist. Please run `trestle:install` first."
            end
          end

          def insert_configuration
            inject_into_file "config/initializers/trestle.rb", before: /^end/ do
              format_configuration(template_content("basic.rb.erb"))
            end
          end

          def generate_model
            generate "trestle:auth:otp:model", model unless devise?
          end

          def generate_admin
            generate "trestle:auth:otp:admin", model, ("--devise" if devise?)
          end

          def generate_migration
            filename = 'migration.rb'
            path = File.expand_path(find_in_source_paths(filename.to_s))
            text = File.read(path)
            content = text.gsub('[]', "[#{ActiveRecord::Migration.current_version}]")
            File.open(path, "w") { |file| file << content }

            migration_template(filename, "db/migrate/add_otp_fields.rb")
          end

          def devise?
            options[:devise]
          end

          def self.next_migration_number(dirname)
            next_migration_number = current_migration_number(dirname) + 1
            ActiveRecord::Migration.next_migration_number(next_migration_number)
          end

        private
          def format_configuration(source)
            "\n#{source.indent(2)}\n"
          end

          def template_content(path, options={})
            path = File.expand_path(find_in_source_paths(path.to_s))
            context = options.delete(:context) || instance_eval("binding")

            content = capturable_erb(path).tap do |erb|
              erb.filename = path
            end.result(context)
          end

          def capturable_erb(path)
            match = ERB.version.match(/(\d+\.\d+\.\d+)/)

            if match && match[1] >= "2.2.0" # Ruby 2.6+
              CapturableERB.new(::File.binread(path), trim_mode: "-", eoutvar: "@output_buffer")
            else
              CapturableERB.new(::File.binread(path), nil, "-", "@output_buffer")
            end
          end
        end
      end
    end
  end
end