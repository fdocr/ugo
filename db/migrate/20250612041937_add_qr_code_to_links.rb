class AddQrCodeToLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :links, :qr_code, :text
  end
end
