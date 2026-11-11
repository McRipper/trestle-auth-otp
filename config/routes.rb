Trestle::Engine.routes.draw do
  get "otp/challenge", to: "trestle/auth/otp/challenges#new", as: :otp_challenge
  post "otp/challenge", to: "trestle/auth/otp/challenges#create"
  delete "otp/challenge", to: "trestle/auth/otp/challenges#destroy"
  get "otp", to: "trestle/auth/otp/settings#show", as: :otp_settings
  post "otp/setup", to: "trestle/auth/otp/settings#setup", as: :otp_setup
  get "otp/enrollment", to: "trestle/auth/otp/settings#enrollment", as: :otp_enrollment
  post "otp/enable", to: "trestle/auth/otp/settings#enable", as: :otp_enable
  post "otp/recovery-codes", to: "trestle/auth/otp/settings#recovery_codes", as: :otp_recovery_codes
  delete "otp", to: "trestle/auth/otp/settings#destroy"
end
