source 'https://rubygems.org'

gem 'rails', '~> 8.1.0'
gem ENV.fetch('ASSET_PIPELINE', 'sprockets-rails')
gem 'trestle', github: 'TrestleAdmin/trestle', branch: 'main'
gem 'trestle-auth', github: 'TrestleAdmin/trestle-auth', branch: 'main'
gem 'rake', '~> 13.0'

group :test do
  gem 'coveralls_reborn', require: false
  gem 'capybara'
  gem 'sqlite3', '>= 2.1'
  gem 'devise'
end

gemspec
