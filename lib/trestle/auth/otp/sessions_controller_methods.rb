module Trestle
  module Auth
    module Otp
      module SessionsControllerMethods
        include ControllerMethods

        def create
          otp_no_cache
          session.delete(:trestle_otp_challenge)
          candidate = authentication_backend.authenticate_password
          unless candidate
            flash[:error] = t("admin.auth.error", default: "Incorrect login details.")
            return redirect_to login_path, status: :see_other
          end

          if candidate.otp_module?
            return_to = session[:trestle_return_to]
            reset_session
            @_authentication_backend = nil
            session[:trestle_return_to] = return_to
            session[:trestle_otp_challenge] = otp_pending_data(candidate)
            redirect_to otp_challenge_path, status: :see_other
          else
            credentials = params[authentication_scope]
            remember = ActiveModel::Type::Boolean.new.cast(credentials[:remember_me])
            return_to = otp_reset_and_login(candidate, remember: remember)
            redirect_to otp_login_destination(return_to), status: :see_other
          end
        end

        def new
          otp_no_cache
          session.delete(:trestle_otp_challenge)
          super
        end

        def destroy
          super
          reset_session
        end
      end
    end
  end
end
