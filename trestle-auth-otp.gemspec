require_relative 'lib/trestle/auth/otp/version'

Gem::Specification.new do |spec|
  spec.name          = "trestle-auth-otp"
  spec.version       = Trestle::Auth::Otp::VERSION
  spec.authors       = ["Emanuele Barban"]

  spec.summary       = "One Time Password plugin for the Trestle admin framework"
  spec.homepage      = "https://www.trestle.io"
  spec.license       = "LGPL-3.0"

  spec.files         = Dir.chdir(__dir__) do
    (Dir.glob("{app,config,lib}/**/*") + %w[README.md LICENSE CHANGELOG.md]).select { |path| File.file?(path) }
  end

  spec.require_paths = ["lib"]

  spec.required_ruby_version = Gem::Requirement.new(">= 3.1")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/McRipper/trestle-auth-otp"

  spec.add_dependency "trestle", "~> 0.10.1"
  spec.add_dependency "trestle-auth",  "~> 0.5.0"
  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "active_model_otp", "~> 2.3", ">= 2.3.4"
  spec.add_dependency "rqrcode", "~> 2.0"

  spec.add_development_dependency "rspec-rails",         ">= 7.0", "< 9"
  spec.add_development_dependency "show_me_the_cookies", "~> 6.0"
  spec.add_development_dependency "timecop",             "~> 0.9.1"

end
