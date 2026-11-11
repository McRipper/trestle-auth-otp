Trestle.configure do |config|
  config.hook("view.header", if: -> { logged_in? }) do
    link_to t("admin.otp.settings_title"), trestle.otp_settings_path, class: "btn btn-link btn-sm ms-3"
  end
  config.hook("auth.login.form.after") do
    content_tag(:p, t("admin.otp.login_hint"), class: "text-white small mt-3")
  end

  config.hook("auth.login.form.before") do
    content_tag(:div, flash[:notice], class: "alert alert-success", role: "status") if flash[:notice]
  end
end
