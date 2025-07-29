class ProductImage < ApplicationRecord
  belongs_to :product
  
  # Validations
  validates :image_url, presence: true, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }
  validates :caption, length: { maximum: 200 }
  
  # Callbacks
  before_save :set_default_caption

  private

  def set_default_caption
    if caption.blank? && product.present?
      self.caption = "Imagen de #{product.name}"
    end
  end
end
