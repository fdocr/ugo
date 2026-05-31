class CreateVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :visits do |t|
      t.references :link, null: false, foreign_key: true

      t.string :ip_address, null: false
      t.string :user_agent, null: false
      t.string :referer
      t.datetime :timestamp, null: false, index: true
      t.datetime :processed_at, index: true

      # Device
      t.string :device_type
      t.string :browser_name
      t.string :os_name

      # Geolocation
      t.string :country_code
      t.string :country
      t.string :subdivision
      t.string :city
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.integer :accuracy_radius
    end
  end
end
