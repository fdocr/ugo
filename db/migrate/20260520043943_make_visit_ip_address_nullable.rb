class MakeVisitIpAddressNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :visits, :ip_address, true
    change_column_null :visits, :user_agent, true
  end
end
