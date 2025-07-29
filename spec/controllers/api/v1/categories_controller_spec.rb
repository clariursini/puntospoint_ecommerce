require 'rails_helper'

RSpec.describe Api::V1::CategoriesController, type: :controller do
  let(:admin) { create(:admin) }
  let(:category) { create(:category, admin: admin) }
  let(:valid_attributes) { attributes_for(:category) }
  let(:update_attributes) { { name: 'Updated Category', description: 'Updated description that is long enough' } }

  before do
    # Mock JWT authentication
    allow(controller).to receive(:authenticate_admin!).and_return(true)
    allow(controller).to receive(:current_admin).and_return(admin)
    # Set Current.admin for audit logs - this gets reset after each test
    Current.admin = admin
  end

  after do
    # Clean up Current state after each test
    Current.reset
  end

  describe 'GET #index' do
    let!(:categories) { create_list(:category, 3, admin: admin) }

    it 'returns a list of categories' do
      get :index
      expect(response).to have_http_status(:ok)
      # Test the actual response instead of internal variables
      expect(response.body).to include('categories')
    end

    it 'returns categories with pagination' do
      get :index, params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)
      # Test that pagination is working by checking response
      expect(response.body).to include('pagination')
    end

    it 'includes all categories in response' do
      get :index
      expect(response).to have_http_status(:ok)
      # Verify categories are included (if using JSON responses)
      categories.each do |cat|
        expect(response.body).to include(cat.name)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a single category' do
      get :show, params: { id: category.id }
      expect(response).to have_http_status(:ok)
      # Test response content instead of internal variables
      expect(response.body).to include(category.name)
    end

    it 'returns 404 for non-existent category' do
      get :show, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
      # ApplicationController handles this with rescue_from and renders JSON
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('error')
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new category' do
        expect {
          post :create, params: { category: valid_attributes }
        }.to change(Category, :count).by(1)
        
        expect(response).to have_http_status(:ok)
        # Test that category was created successfully
        created_category = Category.last
        expect(created_category.admin).to eq(admin)
        expect(created_category.name).to eq(valid_attributes[:name])
      end

      it 'creates audit log for category creation' do
        expect {
          post :create, params: { category: valid_attributes }
        }.to change(AuditLog, :count).by(1)
        
        audit_log = AuditLog.last
        expect(audit_log.action).to eq('created')
        expect(audit_log.admin).to eq(admin)
        expect(audit_log.auditable_type).to eq('Category')
      end

      it 'sets Current.admin for audit trail' do
        post :create, params: { category: valid_attributes }
        # Current.admin is set in the controller action
        # We can verify by checking the audit log was created with correct admin
        audit_log = AuditLog.last
        expect(audit_log.admin).to eq(admin)
      end
    end

    context 'with invalid params' do
      it 'returns error for missing name' do
        post :create, params: { category: { name: '', description: 'Valid description here' } }
        expect(response).to have_http_status(:unprocessable_entity)
        # Verify no category was created
        expect(Category.count).to eq(0)
      end

      it 'returns error for short description' do
        post :create, params: { category: { name: 'Valid Name', description: 'Short' } }
        expect(response).to have_http_status(:unprocessable_entity)
        # Verify no category was created
        expect(Category.count).to eq(0)
      end

      it 'does not create category with invalid data' do
        expect {
          post :create, params: { category: { name: '' } }
        }.not_to change(Category, :count)
      end
    end

    context 'with missing parameters' do
      it 'returns bad request for missing category parameter' do
        post :create, params: {}
        expect(response).to have_http_status(:bad_request)
        # ApplicationController handles this with rescue_from
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('error')
        expect(json_response['message']).to include('Parámetros faltantes')
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      it 'updates the category' do
        put :update, params: { id: category.id, category: update_attributes }
        expect(response).to have_http_status(:ok)
        
        category.reload
        expect(category.name).to eq('Updated Category')
        expect(category.description).to eq('Updated description that is long enough')
      end

      it 'creates audit log for category update' do
        # Count audit logs of type "updated" before the update
        updated_logs_before = AuditLog.where(action: 'updated').count
        
        put :update, params: { id: category.id, category: update_attributes }
        
        # Verify that a new audit log was created for the update
        expect(AuditLog.where(action: 'updated').count).to eq(updated_logs_before + 1)
        
        audit_log = AuditLog.where(action: 'updated').last
        expect(audit_log.admin).to eq(admin)
        expect(audit_log.auditable).to eq(category)
      end

      it 'sets Current.admin for audit trail' do
        put :update, params: { id: category.id, category: update_attributes }
        # Verify by checking the audit log was created with correct admin
        audit_log = AuditLog.where(action: 'updated').last
        expect(audit_log.admin).to eq(admin)
      end
    end

    context 'with invalid params' do
      it 'returns error for invalid name' do
        put :update, params: { id: category.id, category: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        
        category.reload
        expect(category.name).not_to eq('')
      end

      it 'returns error for invalid description' do
        put :update, params: { id: category.id, category: { description: 'Short' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not update category with invalid data' do
        original_name = category.name
        put :update, params: { id: category.id, category: { name: '' } }
        
        category.reload
        expect(category.name).to eq(original_name)
      end
    end

    context 'with non-existent category' do
      it 'returns not found error' do
        put :update, params: { id: 99999, category: update_attributes }
        expect(response).to have_http_status(:not_found)
        # ApplicationController handles this with rescue_from
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('error')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the category' do
      category_to_delete = create(:category, admin: admin)
      
      expect {
        delete :destroy, params: { id: category_to_delete.id }
      }.to change(Category, :count).by(-1)
      
      expect(response).to have_http_status(:ok)
    end

    it 'creates audit log for category deletion' do
      category_to_delete = create(:category, admin: admin)
      
      # Count audit logs of type "deleted" before the deletion
      deleted_logs_before = AuditLog.where(action: 'deleted').count
      
      delete :destroy, params: { id: category_to_delete.id }
      
      # Verify that a new audit log was created for the deletion
      expect(AuditLog.where(action: 'deleted').count).to eq(deleted_logs_before + 1)
      
      audit_log = AuditLog.where(action: 'deleted').last
      expect(audit_log.admin).to eq(admin)
    end

    it 'sets Current.admin for audit trail' do
      delete :destroy, params: { id: category.id }
      # Verify by checking the audit log was created with correct admin
      audit_log = AuditLog.where(action: 'deleted').last
      expect(audit_log.admin).to eq(admin)
    end

    context 'with non-existent category' do
      it 'returns not found error' do
        delete :destroy, params: { id: 99999 }
        expect(response).to have_http_status(:not_found)
        # ApplicationController handles this with rescue_from
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('error')
      end
    end

    context 'when category cannot be deleted' do
      it 'returns error when deletion fails' do
        # Create a fresh category for this test
        category_to_delete = create(:category, admin: admin)
        
        # Mock destroy to return false
        allow_any_instance_of(Category).to receive(:destroy).and_return(false)
        allow_any_instance_of(Category).to receive(:errors).and_return(
          double(full_messages: ['Cannot delete category'])
        )
        
        delete :destroy, params: { id: category_to_delete.id }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'private methods' do
    describe '#category_params' do
      it 'permits only allowed parameters' do
        params = ActionController::Parameters.new(
          category: {
            name: 'Test Category',
            description: 'Test description',
            unauthorized_param: 'Should not be permitted'
          }
        )
        
        controller.params = params
        permitted_params = controller.send(:category_params)
        
        expect(permitted_params).to include(:name, :description)
        expect(permitted_params).not_to include(:unauthorized_param)
      end

      it 'raises parameter missing error when category is missing' do
        controller.params = ActionController::Parameters.new({})
        
        expect {
          controller.send(:category_params)
        }.to raise_error(ActionController::ParameterMissing)
      end
    end

    describe '#serialize_category' do
      it 'serializes category with basic data' do
        serialized = controller.send(:serialize_category, category)
        
        expect(serialized).to include(
          :id, :name, :description, :created_at, :admin
        )
        expect(serialized[:admin]).to include(:id, :name)
      end

      it 'includes details when requested' do
        # Create some products for this category
        products = create_list(:product, 2, admin: admin, categories: [category])
        
        serialized = controller.send(:serialize_category, category, include_details: true)
        
        expect(serialized).to include(
          :products_count, :total_purchases, :total_revenue, :products
        )
      end
    end

    describe '#pagination_meta' do
      it 'returns pagination metadata' do
        categories = create_list(:category, 5, admin: admin)
        paginated = Category.page(1).per(3)
        
        meta = controller.send(:pagination_meta, paginated)
        
        expect(meta).to include(
          :current_page, :next_page, :prev_page, :total_pages, :total_count
        )
        expect(meta[:current_page]).to eq(1)
        expect(meta[:total_count]).to eq(5)
      end
    end
  end

  describe 'error handling' do
    context 'when an exception occurs during creation' do
      it 'handles general exceptions' do
        allow_any_instance_of(Category).to receive(:save).and_raise(StandardError, 'Database error')
        
        post :create, params: { category: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'authentication' do
    context 'when admin is not authenticated' do
      before do
        # Remove the authentication mock to test real behavior
        allow(controller).to receive(:authenticate_admin!).and_call_original
        allow(controller).to receive(:current_admin).and_return(nil)
      end

      it 'returns unauthorized when no token provided' do
        request.headers['Authorization'] = nil
        get :index
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('error')
        expect(json_response['message']).to eq('Token is required')
      end

      it 'returns unauthorized when invalid token provided' do
        request.headers['Authorization'] = 'Bearer invalid_token'
        get :index
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('error')
      end
    end
  end
end