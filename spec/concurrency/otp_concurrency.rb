# Run explicitly against an isolated PostgreSQL test database, never production:
# RAILS_ENV=test DATABASE_URL=... bundle exec ruby spec/concurrency/otp_concurrency.rb
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "timecop"

abort "An isolated PostgreSQL test database is required" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL" &&
  ActiveRecord::Base.connection_db_config.database.start_with?("trestle_otp_test")
ActiveRecord::MigrationContext.new(File.expand_path("../dummy/db/migrate", __dir__)).migrate

def race(user, code)
  ready = Queue.new
  start = Queue.new
  threads = 2.times.map do
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        independent_user = Administrator.find(user.id)
        ready << true
        start.pop
        !!independent_user.authenticate_otp(code)
      end
    end
  end
  2.times { ready.pop }
  2.times { start << true }
  threads.each { |thread| raise "Verification timed out" unless thread.join(10) }
  results = threads.map(&:value)
  raise "A code was accepted more or less than once" unless results.count(true) == 1
end

user = Administrator.create!(email: "concurrency@example.test", password: "test-password")
secret = Administrator.otp_random_secret
codes = Timecop.freeze(Time.current - 60) do
  user.enable_otp!(secret: secret, code: ROTP::TOTP.new(secret).now, expected_signature: user.otp_session_signature)
end
race(user, user.otp_code)
race(user, codes.first)
puts "PostgreSQL: concurrent TOTP and recovery-code verification each accepted exactly one request"
user.destroy!
