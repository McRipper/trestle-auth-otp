Trestle.resource(:administrators, model: Administrator, scope: Auth) do
  menu do
    group :configuration, priority: :last do
      item :administrators, icon: "fa fa-users"
    end
  end

  table do
    column :avatar, header: false do |administrator|
      avatar_for(administrator)
    end
    column :email, link: true
    column :otp_module, header: 'OTP'
    column :first_name
    column :last_name
    actions do |a|
      a.delete unless a.instance == current_user
    end
  end

  form do |administrator|

    sidebar do
      render 'qr_code' if administrator.persisted?
    end

    text_field :email

    row do
      col(sm: 6) { text_field :first_name }
      col(sm: 6) { text_field :last_name }
    end

    row do
      col(sm: 6) { password_field :password }
      col(sm: 6) { password_field :password_confirmation }
    end

    check_box :otp_module, label: 'Enable OTP'

  end
end
