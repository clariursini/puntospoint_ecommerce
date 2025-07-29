require 'rails_helper'

RSpec.describe Api::V1::ProductsController, type: :controller do
  let(:admin) { create(:admin) }
  let(:category) { create(:category, admin: admin) }
  let(:product) { create(:product, admin: admin) }
  let(:valid_attributes) { attributes_for(:product, admin_id: admin.id) }
  let(:update_attributes) { { name: 'Updated Product', description: 'Updated description', price: 999.99, stock: 50 } }

  before do
    # Mock JWT authentication
    allow(controller).to receive(:authenticate_admin!).and_return(true)
    allow(controller).to receive(:current_admin).and_return(admin)
    # Mock Current.admin for audit logs
    allow(Current).to receive(:admin=).and_return(admin)
  end

  describe 'GET #index' do
    it 'returns a list of products with caching' do
      expect(Rails.cache).to receive(:fetch).with(/#{Regexp.escape('products/index/')}/, expires_in: 15.minutes)
      
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #show' do
    it 'returns a single product with caching' do
      expect(Rails.cache).to receive(:fetch).with(/#{Regexp.escape("products/show/#{product.id}")}/, expires_in: 30.minutes)
      
      get :show, params: { id: product.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new product and clears cache' do
        expect(Rails.cache).to receive(:delete_matched).with('products/*')
        
        post :create, params: { product: valid_attributes }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'returns error for invalid product data' do
        post :create, params: { product: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      it 'updates the product and clears cache' do
        expect(Rails.cache).to receive(:delete_matched).with('products/*')
        
        put :update, params: { id: product.id, product: update_attributes }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'returns error for invalid update data' do
        put :update, params: { id: product.id, product: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the product and clears cache' do
      expect(Rails.cache).to receive(:delete_matched).with('products/*')
      
      delete :destroy, params: { id: product.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #most_purchased_by_category' do
    it 'returns most purchased products with caching' do
      expect(Rails.cache).to receive(:fetch).with(/#{Regexp.escape('products/most_purchased/')}/, expires_in: 1.hour)
      
      get :most_purchased_by_category
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #top_revenue_by_category' do
    it 'returns top revenue products with caching' do
      expect(Rails.cache).to receive(:fetch).with(/#{Regexp.escape('products/top_revenue/')}/, expires_in: 1.hour)
      
      get :top_revenue_by_category
      expect(response).to have_http_status(:ok)
    end
  end
end 