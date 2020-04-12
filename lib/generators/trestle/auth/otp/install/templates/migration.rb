class AddOtpFields < ActiveRecord::Migration[6.0]
  def up
    add_column :administrators, :otp_secret_key, :string
    add_column :administrators, :otp_module, :boolean, default: false
  end

  def down
    remove_column :administrators, :otp_module
    remove_column :administrators, :otp_secret_key
  end
end
