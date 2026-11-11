module Trestle
  module Auth
    module Test
      module LoginHelpers
        def login(email: "admin@example.com", password: "password", remember_me: false, otp_code: nil)
          visit "/admin/login"

          fill_in "Email", with: email
          fill_in "Password", with: password
          check "Remember me" if remember_me

          click_button "Login"
          if otp_code && page.has_current_path?("/admin/otp/challenge")
            fill_in "Authentication code", with: otp_code
            click_button "Verify and sign in"
          end
        end

        def logout
          click_link "Logout"
        end
      end
    end
  end
end
