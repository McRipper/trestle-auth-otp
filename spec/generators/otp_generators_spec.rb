require "rails_helper"
require "rails/generators"
require "rails/generators/migration"
require "tmpdir"
require "generators/trestle/auth/otp/install/install_generator"
require "generators/trestle/auth/otp/upgrade/upgrade_generator"
require "generators/trestle/auth/otp/model/model_generator"

RSpec.describe "OTP generators" do
  let(:install_class) { Trestle::Auth::Otp::Generators::InstallGenerator }

  it "generates for the selected model and leaves gem templates unchanged across Rails versions" do
    source = File.join(install_class.source_root, "migration.rb.erb")
    original = File.binread(source)
    ["7.1", "8.1"].each do |version|
      allow(ActiveRecord::Migration).to receive(:current_version).and_return(version)
      Dir.mktmpdir do |root|
        install_class.new(["User"], {quiet: true}, destination_root: root).generate_migration
        content = File.read(Dir["#{root}/db/migrate/*.rb"].first)
        expect(content).to include("ActiveRecord::Migration[#{version}]", "add_column :users", ":otp_last_used_at", ":otp_recovery_codes_digest")
        expect(content).not_to include(":administrators")
      end
      expect(File.binread(source)).to eq(original)
    end
  end

  it "creates an upgrade migration which preserves existing OTP secrets" do
    Dir.mktmpdir do |root|
      Trestle::Auth::Otp::Generators::UpgradeGenerator.new(["Administrator"], {quiet: true}, destination_root: root).generate_migration
      content = File.read(Dir["#{root}/db/migrate/*.rb"].first)
      expect(content).to include("change_column :administrators, :otp_secret_key, :text", ":otp_last_used_at")
      expect(content).not_to include("remove_column", "drop_table")
    end
  end

  it "injects model methods once, including into a Devise model" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p("#{root}/app/models")
      file = "#{root}/app/models/user.rb"
      File.write(file, "class User < ApplicationRecord\n  devise :database_authenticatable\nend\n")
      Dir.chdir(root) do
        generator = Trestle::Auth::Otp::Generators::ModelGenerator.new(["User"], {quiet: true}, destination_root: root)
        2.times { generator.inject_model_methods }
      end
      expect(File.read(file).scan("include Trestle::Auth::Otp::ModelMethods").size).to eq(1)
      expect(File.read(file)).to include("devise :database_authenticatable")
    end
  end
end
