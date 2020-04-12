# Trestle Authentication One Time Password (trestle-auth-otp)

## Getting Started

These instructions assume you have a working Trestle application. To integrate trestle-auth-otp, first add it to your application's Gemfile:

```ruby
gem 'trestle-auth-otp'
```

Run `bundle install`, and then run the install generator to set up configuration options, user model and user admin resource.

    $ rails generate trestle:auth:install
    $ rails generate trestle:auth:otp:install
    $ rake db:migrate

Then create an initial admin user from the rails console:

    $ rails console
    > Administrator.create(email: "admin@example.com", password: "password", first_name: "Admin", last_name: "User")

To update existing records

    $ rails console
    > Administrator.find_each { |a| a.update_attribute(:otp_secret_key, Administrator.otp_random_secret) }

After restarting your Rails server, any attempt to access a page within your admin will redirect you to the login page.

OTP must be enabled in the Administrator form for every record.

## Notes

This gem is based on the work done by Sam Pohlenz on trestle-auth

## License

The gem is available as open source under the terms of the [LGPLv3 License](https://opensource.org/licenses/LGPL-3.0).
