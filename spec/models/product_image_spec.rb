require 'rails_helper'

RSpec.describe ProductImage, type: :model do
  let(:admin) { create(:admin) }
  let(:product) { create(:product, admin: admin) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      product_image = build(:product_image, product: product)
      expect(product_image).to be_valid
    end

    it 'requires image_url to be present' do
      product_image = build(:product_image, image_url: nil, product: product)
      expect(product_image).not_to be_valid
      expect(product_image.errors[:image_url]).to include("can't be blank")
    end

    it 'requires image_url to be a valid URL' do
      product_image = build(:product_image, image_url: 'invalid-url', product: product)
      expect(product_image).not_to be_valid
      expect(product_image.errors[:image_url]).to include('must be a valid URL')
    end

    it 'accepts valid URLs' do
      valid_urls = ['http://example.com/image.jpg', 'https://example.com/image.png']
      valid_urls.each do |url|
        product_image = build(:product_image, image_url: url, product: product)
        expect(product_image).to be_valid
      end
    end

    it 'validates caption length' do
      product_image = build(:product_image, caption: 'A' * 201, product: product)
      expect(product_image).not_to be_valid
      expect(product_image.errors[:caption]).to include('is too long (maximum is 200 characters)')
    end
  end

  describe 'associations' do
    it { should belong_to(:product) }
  end

  describe 'callbacks' do
    it 'sets default caption before save when caption is blank' do
      product_image = build(:product_image, caption: '', product: product)
      product_image.save!
      
      # Verificar caption en lugar de alt_text que no existe
      expect(product_image.caption).to include(product.name)
    end
  end
end
