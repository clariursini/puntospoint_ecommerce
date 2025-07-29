require 'rails_helper'

RSpec.describe Product, type: :model do
  let(:admin) { create(:admin) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      product = build(:product, admin: admin)
      expect(product).to be_valid
    end

    it 'requires a name' do
      product = build(:product, name: nil, admin: admin)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it 'requires name to be between 2 and 200 characters' do
      product = build(:product, name: 'A', admin: admin)
      expect(product).not_to be_valid
      
      product = build(:product, name: 'A' * 201, admin: admin)
      expect(product).not_to be_valid
    end

    it 'requires a description' do
      product = build(:product, description: nil, admin: admin)
      expect(product).not_to be_valid
      expect(product.errors[:description]).to include("can't be blank")
    end

    it 'requires description to be between 10 and 1000 characters' do
      product = build(:product, description: 'Short', admin: admin)
      expect(product).not_to be_valid
      
      product = build(:product, description: 'A' * 1001, admin: admin)
      expect(product).not_to be_valid
    end

    it 'requires a price greater than 0' do
      product = build(:product, price: 0, admin: admin)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include('must be greater than 0')
    end

    it 'requires stock to be greater than or equal to 0' do
      product = build(:product, stock: -1, admin: admin)
      expect(product).not_to be_valid
      expect(product.errors[:stock]).to include('must be greater than or equal to 0')
    end
  end

  describe 'associations' do
    it { should belong_to(:admin) }
    it { should have_many(:product_categories).dependent(:destroy) }
    it { should have_many(:categories).through(:product_categories) }
    it { should have_many(:product_images).dependent(:destroy) }
    it { should have_many(:purchases).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:in_stock_product) { create(:product, stock: 10, admin: admin) }
    let!(:out_of_stock_product) { create(:product, stock: 0, admin: admin) }

    describe '.in_stock' do
      it 'returns products with stock > 0' do
        expect(Product.in_stock).to include(in_stock_product)
        expect(Product.in_stock).not_to include(out_of_stock_product)
      end
    end

    describe '.out_of_stock' do
      it 'returns products with stock = 0' do
        expect(Product.out_of_stock).to include(out_of_stock_product)
        expect(Product.out_of_stock).not_to include(in_stock_product)
      end
    end

    describe '.by_price_range' do
      let!(:cheap_product) { create(:product, price: 10, admin: admin) }
      let!(:expensive_product) { create(:product, price: 100, admin: admin) }

      it 'returns products within price range' do
        products = Product.by_price_range(50, 150)
        expect(products).to include(expensive_product)
        expect(products).not_to include(cheap_product)
      end
    end
  end

  describe 'callbacks' do
    it 'creates audit log on creation' do
      Current.admin = admin
      
      expect {
        create(:product, admin: admin)
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.action).to eq('created')
      expect(audit_log.admin).to eq(admin)
    end
  end

  describe 'instance methods' do
    let(:product) { create(:product, admin: admin, price: 100, stock: 10) }
    let(:customer) { create(:customer) }

    describe '#total_purchases_count' do
      it 'returns total number of purchases' do
        create_list(:purchase, 3, product: product, customer: customer)
        expect(product.total_purchases_count).to eq(3)
      end
    end

    describe '#total_revenue' do
      it 'returns total revenue from all purchases' do
        # Limpiar purchases existentes para este producto específico
        product.purchases.destroy_all
        
        create(:purchase, product: product, customer: customer, quantity: 1, total_price: 100)
        create(:purchase, product: product, customer: customer, quantity: 2, total_price: 200)
        
        expect(product.total_revenue.to_f).to eq(300.0)
      end
    end

    describe '#first_purchase' do
      it 'returns the first purchase made' do
        first = create(:purchase, product: product, customer: customer, purchased_at: 1.day.ago)
        create(:purchase, product: product, customer: customer, purchased_at: Time.current)
        
        expect(product.first_purchase).to eq(first)
      end
    end

    describe '#last_purchase' do
      it 'returns the last purchase made' do
        create(:purchase, product: product, customer: customer, purchased_at: 1.day.ago)
        last = create(:purchase, product: product, customer: customer, purchased_at: Time.current)
        
        expect(product.last_purchase).to eq(last)
      end
    end

    describe '#reduce_stock!' do
      it 'reduces stock by given quantity' do
        expect {
          product.reduce_stock!(3)
        }.to change { product.reload.stock }.from(10).to(7)
      end

      it 'raises error when insufficient stock' do
        expect {
          product.reduce_stock!(15)
        }.to raise_error(StandardError, /Stock insuficiente/)
      end
    end

    describe '#total_sold' do
      it 'returns total quantity sold' do
        create(:purchase, product: product, customer: customer, quantity: 3)
        create(:purchase, product: product, customer: customer, quantity: 2)
        
        expect(product.total_sold).to eq(5)
      end
    end
  end

  describe 'class methods' do
    let(:category) { create(:category, admin: admin) }
    let!(:product1) { create(:product, admin: admin, categories: [category]) }
    let!(:product2) { create(:product, admin: admin, categories: [category]) }
    let(:customer) { create(:customer) }

    describe '.most_purchased_by_category' do
      it 'returns products grouped by category ordered by purchase count' do
        create_list(:purchase, 3, product: product1, customer: customer)
        create_list(:purchase, 1, product: product2, customer: customer)
        
        results = Product.most_purchased_by_category
        expect(results.first.id).to eq(product1.id)
      end
    end

    describe '.top_revenue_by_category' do
      it 'returns products grouped by category ordered by revenue' do
        test_category = create(:category, admin: admin)
        Purchase.destroy_all
        
        test_product1 = create(:product, admin: admin, categories: [test_category], price: 100, stock: 50)
        test_product2 = create(:product, admin: admin, categories: [test_category], price: 100, stock: 50)
        
        create(:purchase, product: test_product1, customer: customer, quantity: 3)  # = 300
        create(:purchase, product: test_product2, customer: customer, quantity: 1)  # = 100
        
        results = Product.top_revenue_by_category
        expect(results.first.total_revenue.to_f).to eq(300.0)
      end
    end
  end
end
