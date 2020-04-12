module Trestle
  module Auth
    module Test
      module LoginHelpers
        def login(email: "admin@example.com", password: "password", remember_me: false)
          visit "/admin/login"

          fill_in "Email", with: email
          fill_in "Password", with: password
          fill_in "Token", width: "123123"
          check "Remember me" if remember_me

          click_button "Login"
        end

        def logout
          click_link "Logout"
        end
      end
    end
  end
end
