class Api::V1::CategoriesController < ApplicationController
  before_action :set_category, only: [:show, :update, :destroy]
  
  # GET /api/v1/categories
  def index
    @categories = Category.includes(:products, :admin)
                        .page(params[:page])
                        .per(params[:per_page] || 20)
    
    render_success({
      categories: @categories.map { |category| serialize_category(category) },
      pagination: pagination_meta(@categories)
    })
  end
  
  # GET /api/v1/categories/1
  def show
    render_success(serialize_category(@category, include_details: true))
  end
  
  # POST /api/v1/categories
  def create
    @category = current_admin.categories.build(category_params)
    
    # Set current admin for audit trail
    Current.admin = current_admin
    
    if @category.save
      render_success(serialize_category(@category), 'Category created successfully')
    else
      error_details = @category.errors.full_messages.join(', ')
      render_error('Error while creating the category', error_details, :unprocessable_entity)
    end
  rescue ActionController::ParameterMissing => e
    render_error('Parámetros faltantes', e.message, :bad_request)
  rescue StandardError => e
    Rails.logger.error "Exception in create category: #{e.message}"
    render_error('Error while creating the category', e.message, :unprocessable_entity)
  end
  
  # PUT /api/v1/categories/1
  def update    
    # Set current admin for audit trail
    Current.admin = current_admin
    
    if @category.update(category_params)
      render_success(serialize_category(@category), 'Category updated successfully')
    else
      render_error('Error while updating the category', @category.errors.full_messages.join(', '))
    end
  rescue ActionController::ParameterMissing => e
    render_error('Parámetros faltantes', e.message, :bad_request)
  rescue StandardError => e
    Rails.logger.error "Exception in update category: #{e.message}"
    render_error('Error while updating the category', e.message, :unprocessable_entity)
  end
  
  # DELETE /api/v1/categories/1
  def destroy    
    # Set current admin for audit trail
    Current.admin = current_admin
    
    if @category.destroy
      render_success(nil, 'Category deleted successfully')
    else
      render_error('Cannot delete the category', @category.errors.full_messages.join(', '))
    end
  rescue StandardError => e
    Rails.logger.error "Exception in destroy category: #{e.message}"
    render_error('Error while deleting the category', e.message, :unprocessable_entity)
  end
  
  private
  
  def set_category
    @category = Category.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Category not found', nil, :not_found)
  end
    
  def category_params
    params.require(:category).permit(:name, :description)
  end
  
  def serialize_category(category, include_details: false)
    base_data = {
      id: category.id,
      name: category.name,
      description: category.description,
      created_at: category.created_at,
      admin: {
        id: category.admin.id,
        name: category.admin.name
      }
    }
    
    if include_details
      base_data.merge!(
        products_count: category.products.count,
        total_purchases: category.total_purchases,
        total_revenue: category.total_revenue.to_f,
        products: category.products.in_stock.limit(10).map do |product|
          {
            id: product.id,
            name: product.name,
            price: product.price.to_f
          }
        end
      )
    end
    
    base_data
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end
end 