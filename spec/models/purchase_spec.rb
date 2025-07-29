require 'rails_helper'

RSpec.describe Purchase, type: :model do
  let(:admin) { create(:admin) }
  let(:customer) { create(:customer) }
  let(:product) { create(:product, admin: admin, price: 100, stock: 10) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      purchase = build(:purchase, customer: customer, product: product)
      expect(purchase).to be_valid
    end

    it 'requires quantity to be greater than 0' do
      purchase = build(:purchase, quantity: 0, customer: customer, product: product)
      expect(purchase).not_to be_valid
      expect(purchase.errors[:quantity]).to include('must be greater than 0')
    end

    it 'requires total_price to be greater than 0' do
      # Usar skip_callback para evitar que se calcule automáticamente
      Purchase.skip_callback(:validation, :before, :calculate_total_price)
      
      purchase = build(:purchase, quantity: 2, customer: customer, product: product)
      purchase.total_price = 0  # Setear explícitamente a 0
      purchase.purchased_at = Time.current
      
      expect(purchase).not_to be_valid
      expect(purchase.errors[:total_price]).to include('must be greater than 0')
      
      # Restaurar callback
      Purchase.set_callback(:validation, :before, :calculate_total_price)
    end

    it 'requires purchased_at to be present' do
      # Usar skip_callback para evitar que se setee automáticamente
      Purchase.skip_callback(:validation, :before, :set_purchased_at)
      
      purchase = build(:purchase, quantity: 1, customer: customer, product: product)
      purchase.total_price = 100
      purchase.purchased_at = nil
      
      expect(purchase).not_to be_valid
      expect(purchase.errors[:purchased_at]).to include("can't be blank")
      
      # Restaurar callback
      Purchase.set_callback(:validation, :before, :set_purchased_at)
    end

    it 'validates sufficient stock' do
      purchase = build(:purchase, quantity: 15, customer: customer, product: product)
      expect(purchase).not_to be_valid
      expect(purchase.errors[:quantity]).to include(/excede el stock disponible/)
    end
  end

  describe 'associations' do
    it 'belongs to customer' do
      purchase = create(:purchase, customer: customer, product: product)
      expect(purchase.customer).to eq(customer)
    end

    it 'belongs to product' do
      purchase = create(:purchase, customer: customer, product: product)
      expect(purchase.product).to eq(product)
    end
   end

  describe 'callbacks' do
    it 'sets purchased_at before validation on create' do
      purchase = build(:purchase, purchased_at: nil, customer: customer, product: product)
      purchase.valid?
      expect(purchase.purchased_at).to be_present
    end

    it 'calculates total_price before validation on create' do
      purchase = build(:purchase, quantity: 2, total_price: nil, customer: customer, product: product)
      purchase.valid?
      expect(purchase.total_price).to eq(200) # 2 * 100
    end

    it 'updates product stock after create' do
      expect {
        create(:purchase, quantity: 3, customer: customer, product: product)
      }.to change { product.reload.stock }.from(10).to(7)
    end
  end

  describe 'scopes' do
    let!(:recent_purchase) { create(:purchase, customer: customer, product: product, purchased_at: 1.hour.ago) }
    let!(:old_purchase) { create(:purchase, customer: customer, product: product, purchased_at: 1.week.ago) }

    describe '.recent' do
      it 'orders purchases by purchased_at desc' do
        expect(Purchase.recent.first).to eq(recent_purchase)
      end
    end

    describe '.by_date_range' do
      it 'returns purchases within date range' do
        start_date = 2.days.ago
        end_date = Time.current
        
        purchases = Purchase.by_date_range(start_date, end_date)
        expect(purchases).to include(recent_purchase)
        expect(purchases).not_to include(old_purchase)
      end
    end

    describe '.today' do
      it 'returns purchases from today' do
        today_purchase = create(:purchase, customer: customer, product: product, purchased_at: Time.current)
        
        expect(Purchase.today).to include(today_purchase)
        expect(Purchase.today).not_to include(old_purchase)
      end
    end
  end

  describe 'instance methods' do
    let(:purchase) { create(:purchase, customer: customer, product: product, quantity: 2) }

    describe '#unit_price' do
      it 'returns the product price' do
        expect(purchase.unit_price).to eq(100)
      end
    end

    describe '#is_first_purchase?' do
      it 'returns true if this is the first purchase of the product' do
        first_purchase = create(:purchase, customer: customer, product: product)
        expect(first_purchase.is_first_purchase?).to be true
        
        second_purchase = create(:purchase, customer: customer, product: product)
        expect(second_purchase.is_first_purchase?).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.daily_report' do
      let(:date) { Date.yesterday }
      let(:report_product) { create(:product, admin: admin, price: 100, stock: 50) }
      
      before do
        # Limpiar todos los purchases para este test
        Purchase.destroy_all
        
        create(:purchase, customer: customer, product: report_product, quantity: 1, total_price: 100, purchased_at: date.noon)
        create(:purchase, customer: customer, product: report_product, quantity: 2, total_price: 200, purchased_at: date.noon)
      end

      it 'returns daily report for given date' do
        report = Purchase.daily_report(date)
        
        expect(report[:date]).to eq(date)
        expect(report[:total_purchases]).to eq(2)
        expect(report[:total_revenue].to_f).to eq(300.0)
      end
    end
  end
end
