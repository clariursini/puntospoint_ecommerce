require 'rails_helper'

RSpec.describe Customer, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      customer = build(:customer)
      expect(customer).to be_valid
    end

    it 'requires a name' do
      customer = build(:customer, name: nil)
      expect(customer).not_to be_valid
      expect(customer.errors[:name]).to include("can't be blank")
    end

    it 'requires name to be between 2 and 100 characters' do
      customer = build(:customer, name: 'A')
      expect(customer).not_to be_valid
      
      customer = build(:customer, name: 'A' * 101)
      expect(customer).not_to be_valid
    end

    it 'requires an email' do
      customer = build(:customer, email: nil)
      expect(customer).not_to be_valid
      expect(customer.errors[:email]).to include("can't be blank")
    end

    it 'requires a unique email' do
      create(:customer, email: 'test@example.com')
      customer = build(:customer, email: 'test@example.com')
      expect(customer).not_to be_valid
      expect(customer.errors[:email]).to include('has already been taken')
    end

    it 'requires a valid email format' do
      customer = build(:customer, email: 'invalid-email')
      expect(customer).not_to be_valid
      expect(customer.errors[:email]).to include('is invalid')
    end

    it 'validates phone format when present' do
      customer = build(:customer, phone: 'invalid-phone')
      expect(customer).not_to be_valid
      expect(customer.errors[:phone]).to include('formato inválido')
    end

    it 'accepts valid phone formats' do
      valid_phones = ['+1234567890', '1234567890', '+123456789012345']
      valid_phones.each do |phone|
        customer = build(:customer, phone: phone)
        expect(customer).to be_valid, "#{phone} should be valid"
      end
    end

    it 'validates address length when present' do
      customer = build(:customer, address: 'Short')
      expect(customer).not_to be_valid
      
      customer = build(:customer, address: 'A' * 501)
      expect(customer).not_to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:purchases).dependent(:destroy) }
    it { should have_many(:products).through(:purchases) }
  end

  describe 'callbacks' do
    it 'normalizes email before save' do
      customer = create(:customer, email: '  TEST@EXAMPLE.COM  ')
      expect(customer.email).to eq('test@example.com')
    end
  end

  describe 'instance methods' do
    let(:customer) { create(:customer) }
    let(:admin) { create(:admin) }
    let(:product) { create(:product, admin: admin, price: 100) }

    describe '#total_spent' do
      it 'returns total amount spent by customer' do
        # Crear un producto específico para este test
        test_product = create(:product, admin: admin, price: 100, stock: 50)
        
        # Limpiar TODOS los purchases de este customer
        customer.purchases.destroy_all
        
        create(:purchase, customer: customer, product: test_product, quantity: 1, total_price: 100)
        create(:purchase, customer: customer, product: test_product, quantity: 2, total_price: 200)
        
        expect(customer.total_spent.to_f).to eq(300.0)
      end
    end
  
    describe '#purchase_count' do
      it 'returns total number of purchases' do
        create_list(:purchase, 3, customer: customer, product: product)
        expect(customer.purchase_count).to eq(3)
      end
    end

    describe '#last_purchase_date' do
      it 'returns date of last purchase' do
        first = create(:purchase, customer: customer, product: product, purchased_at: 1.day.ago)
        last = create(:purchase, customer: customer, product: product, purchased_at: Time.current)
        
        expect(customer.last_purchase_date).to be_within(1.second).of(last.purchased_at)
      end
    end

    describe '#first_purchase' do
      it 'returns the first purchase made' do
        first = create(:purchase, customer: customer, product: product, purchased_at: 1.day.ago)
        create(:purchase, customer: customer, product: product, purchased_at: Time.current)
        
        expect(customer.first_purchase).to eq(first)
      end
    end

    describe '#last_purchase' do
      it 'returns the last purchase made' do
        create(:purchase, customer: customer, product: product, purchased_at: 1.day.ago)
        last = create(:purchase, customer: customer, product: product, purchased_at: Time.current)
        
        expect(customer.last_purchase).to eq(last)
      end
    end
  end
end
