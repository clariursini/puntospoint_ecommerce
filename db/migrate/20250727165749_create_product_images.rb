class CreateProductImages < ActiveRecord::Migration[7.2]
  def change
    create_table :product_images do |t|
      t.references :product, null: false, foreign_key: true
      t.string :image_url
      t.string :caption

      t.timestamps
    end
  end
end
