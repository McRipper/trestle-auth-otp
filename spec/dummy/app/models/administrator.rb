class Administrator < ApplicationRecord
  include Trestle::Auth::ModelMethods
  include Trestle::Auth::ModelMethods::Rememberable
  include Trestle::Auth::Otp::ModelMethods
end
