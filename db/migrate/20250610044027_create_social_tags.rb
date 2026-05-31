class CreateSocialTags < ActiveRecord::Migration[8.0]
  def change
    create_table :social_tags do |t|
      t.string :title
      t.string :url
      t.string :image_url
      t.string :description
      t.belongs_to :link, null: false, foreign_key: true
      t.timestamps
    end
  end
end
