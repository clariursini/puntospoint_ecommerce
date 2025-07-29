require 'rails_helper'

RSpec.describe Api::V1::PurchasesController, type: :controller do
  let(:admin) { create(:admin) }
  let(:customer) { create(:customer) }
  let(:product) { create(:product, admin: admin) }
  let(:purchase) { create(:purchase, customer: customer, product: product) }
  let(:valid_attributes) { attributes_for(:purchase, customer_id: customer.id, product_id: product.id) }

  before do
    # Mock JWT authentication
    allow(controller).to receive(:authenticate_admin!).and_return(true)
    allow(controller).to receive(:current_admin).and_return(admin)
  end

  describe 'GET #filtered' do
    it 'returns filtered purchases' do
      get :filtered, params: { start_date: '2024-01-01', end_date: '2024-01-31' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new purchase and clears cache' do
        expect(Rails.cache).to receive(:delete_matched).with('purchases/*')
        
        post :create, params: { purchase: valid_attributes }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET #count_by_granularity' do
    it 'returns purchases grouped by granularity' do
      get :count_by_granularity, params: { granularity: 'day' }
      expect(response).to have_http_status(:ok)
    end

    it 'returns error for invalid granularity' do
      get :count_by_granularity, params: { granularity: 'invalid' }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET #daily_report' do
    it 'returns daily report' do
      get :daily_report, params: { date: '2024-01-01' }
      expect(response).to have_http_status(:ok)
    end
  end
end 