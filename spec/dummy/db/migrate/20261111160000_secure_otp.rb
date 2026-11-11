class SecureOtp < ActiveRecord::Migration[7.1]
  def change
    change_column :administrators, :otp_secret_key, :text
    change_column_null :administrators, :otp_module, false, false
    add_column :devise_users, :otp_secret_key, :text
    add_column :devise_users, :otp_module, :boolean, default: false, null: false

    [:administrators, :devise_users].each do |table|
      add_column table, :otp_last_used_at, :bigint
      add_column table, :otp_recovery_codes_digest, :text, default: "[]", null: false
      add_column table, :otp_session_token, :string
      add_column table, :otp_failed_attempts, :integer, default: 0, null: false
      add_column table, :otp_locked_until, :datetime
    end
  end
end
