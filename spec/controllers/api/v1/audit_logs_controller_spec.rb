require 'rails_helper'

RSpec.describe Api::V1::AuditLogsController, type: :controller do
  let(:admin) { create(:admin) }
  let(:product) { create(:product, admin: admin) }
  let(:category) { create(:category, admin: admin) }
  let!(:audit_log) { create(:audit_log, admin: admin, auditable: product, action: 'created') }

  before do
    # Mock JWT authentication
    allow(controller).to receive(:authenticate_admin!).and_return(true)
    allow(controller).to receive(:current_admin).and_return(admin)
    allow(controller).to receive(:render_success).and_return(true)
    allow(controller).to receive(:render_error).and_return(true)
  end

  describe 'GET #index' do
    it 'returns a list of audit logs' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #recent' do
    it 'returns recent audit logs' do
      get :recent
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #by_entity' do
    it 'returns audit logs for a specific product' do
      get :by_entity, params: { entity_type: 'Product', entity_id: product.id }
      expect(response).to have_http_status(:ok)
    end

    it 'returns audit logs for a specific category' do
      get :by_entity, params: { entity_type: 'Category', entity_id: category.id }
      expect(response).to have_http_status(:ok)
    end
  end
end