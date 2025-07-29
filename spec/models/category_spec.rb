require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:admin) { create(:admin) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      category = build(:category, admin: admin)
      expect(category).to be_valid
    end

    it 'requires a name' do
      category = build(:category, name: nil, admin: admin)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it 'requires a unique name (case insensitive)' do
      create(:category, name: 'Electronics', admin: admin)
      category = build(:category, name: 'electronics', admin: admin)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include('has already been taken')
    end

    it 'requires name to be between 2 and 100 characters' do
      category = build(:category, name: 'A', admin: admin)
      expect(category).not_to be_valid
      
      category = build(:category, name: 'A' * 101, admin: admin)
      expect(category).not_to be_valid
    end

    it 'requires a description' do
      category = build(:category, description: nil, admin: admin)
      expect(category).not_to be_valid
      expect(category.errors[:description]).to include("can't be blank")
    end

    it 'requires description to be between 10 and 500 characters' do
      category = build(:category, description: 'Short', admin: admin)
      expect(category).not_to be_valid
      
      category = build(:category, description: 'A' * 501, admin: admin)
      expect(category).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:admin) }
    it { should have_many(:product_categories).dependent(:destroy) }
    it { should have_many(:products).through(:product_categories) }
    it { should have_many(:audit_logs).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'creates audit log on deletion' do
      category = create(:category, admin: admin)
      Current.admin = admin
      
      # Contar solo los audit logs de deletion, no los de creation
      expect {
        category.destroy!
      }.to change { AuditLog.where(action: 'deleted').count }.by(1)
      
      audit_log = AuditLog.where(action: 'deleted').last
      expect(audit_log.action).to eq('deleted')
    end
                                        
    it 'creates audit log on update' do
      category = create(:category, admin: admin)
      Current.admin = admin
      
      expect {
        category.update!(name: 'Updated Name')
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.action).to eq('updated')
    end
    
    it 'creates audit log on deletion' do
      category = create(:category, admin: admin)
      Current.admin = admin
      
      # Contar solo los audit logs de deletion, no los de creation
      expect {
        category.destroy!
      }.to change { AuditLog.where(action: 'deleted').count }.by(1)
      
      audit_log = AuditLog.where(action: 'deleted').last
      expect(audit_log.action).to eq('deleted')
    end
  end

  describe 'instance methods' do
    let(:category) { create(:category, admin: admin) }
    let(:product) { create(:product, admin: admin, categories: [category]) }
    let(:customer) { create(:customer) }

    describe '#total_purchases' do
      it 'returns total number of purchases for products in this category' do
        create(:purchase, product: product, customer: customer)
        create(:purchase, product: product, customer: customer)
        
        expect(category.total_purchases).to eq(2)
      end
    end

    describe '#total_revenue' do
      it 'returns total revenue from products in this category' do
        test_product = create(:product, admin: admin, categories: [category], price: 100, stock: 50)
        Purchase.joins(product: :categories).where(categories: { id: category.id }).destroy_all
        
        create(:purchase, product: test_product, customer: customer, quantity: 1)  # total_price se calcula automáticamente: 1 * 100 = 100
        create(:purchase, product: test_product, customer: customer, quantity: 2)  # total_price se calcula automáticamente: 2 * 100 = 200
        
        expect(category.total_revenue.to_f).to eq(300.0)
      end
    end    
    
    describe '#most_purchased_products' do
      it 'returns products ordered by purchase count' do
        product1 = create(:product, admin: admin, categories: [category])
        product2 = create(:product, admin: admin, categories: [category])
        
        # product1 has more purchases
        create_list(:purchase, 3, product: product1, customer: customer)
        create_list(:purchase, 1, product: product2, customer: customer)
        
        most_purchased = category.most_purchased_products
        expect(most_purchased.first.id).to eq(product1.id)
      end
    end
  end
end
