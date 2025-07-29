class Api::V1::ProductsController < ApplicationController
  before_action :set_product, only: [:show, :update, :destroy]
  
  # GET /api/v1/products
  def index
    cache_key = "products/index/#{params[:page]}/#{params[:per_page]}/#{Product.maximum(:updated_at)&.to_i}"
    
    cached_response = cache_api_response(cache_key, expires_in: 15.minutes) do
      @products = Product.includes(:categories, :product_images, :admin)
                       .page(params[:page])
                       .per(params[:per_page] || 20)
      
      {
        products: @products.map { |product| serialize_product(product) },
        pagination: pagination_meta(@products)
      }
    end
    
    render_success(cached_response)
  end
  
  # GET /api/v1/products/1
  def show
    cache_key = "products/show/#{@product.id}/#{@product.updated_at.to_i}"
    
    cached_response = cache_api_response(cache_key, expires_in: 30.minutes) do
      serialize_product(@product, include_details: true)
    end
    
    render_success(cached_response)
  end
  
  # POST /api/v1/products
  def create
    @product = current_admin.products.build(product_params)
    
    # Set current admin for audit trail
    Current.admin = current_admin
    Rails.logger.info "Current.admin set to: #{Current.admin&.id} (#{Current.admin&.name})"
    
    if @product.save
      # Clear cache after creating
      clear_product_caches
      render_success(serialize_product(@product), 'Product created successfully')
    else
      error_details = @product.errors.full_messages.join(', ')
      Rails.logger.error "Product creation failed: #{error_details}"
      render_error('Error while creating the product', error_details, :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found in create product: #{e.message}"
    render_error('Error while creating the product', e.message, :not_found)
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error "Unknown attribute in create product: #{e.message}"
    render_error('Error while creating the product', "Atributo no válido: #{e.message}", :unprocessable_entity)
  rescue => e
    Rails.logger.error "Exception in create product: #{e.message}"
    render_error('Error interno del servidor', e.message, :internal_server_error)
  end
  
  # PUT /api/v1/products/1
  def update
    # Set current admin for audit trail
    Current.admin = current_admin
    Rails.logger.info "Current.admin set to: #{Current.admin&.id} (#{Current.admin&.name})"

    if @product.update(product_params)
      # Clear cache after update
      clear_product_caches
      render_success(serialize_product(@product), 'Product updated successfully')
    else
      render_error('Error while updating the product', @product.errors.full_messages.join(', '), :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found in update product: #{e.message}"
    render_error('Error while updating the product', e.message, :not_found)
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error "Unknown attribute in update product: #{e.message}"
    render_error('Error while updating the product', "Atributo no válido: #{e.message}", :unprocessable_entity)
  rescue => e
    Rails.logger.error "Exception in update product: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_error('Error interno del servidor', e.message, :internal_server_error)
  end
  
  # DELETE /api/v1/products/1
  def destroy    
    # Set current admin for audit trail
    Current.admin = current_admin

    if @product.destroy
      # Clear cache after deletion
      clear_product_caches
      render_success(nil, 'Product deleted successfully')
    else
      render_error('Cannot delete the product', @product.errors.full_messages.join(', '))
    end
  end
  
  # GET /api/v1/products/most_purchased_by_category
  def most_purchased_by_category
    cache_key = "products/most_purchased/#{params[:limit]}/#{Purchase.maximum(:updated_at)&.to_i}"
    
    cached_response = cache_api_response(cache_key, expires_in: 1.hour) do
      products = Product.most_purchased_by_category(params[:limit] || 10)
      
      grouped_results = products.group_by { |r| [r.category_id, r.category_name] }
      
      grouped_results.map do |(category_id, category_name), products|
          {
          category: {
              id: category_id,
              name: category_name
          },
          products: products.map do |product|
              {
              id: product.id,
              name: product.name,
              purchase_count: product.purchase_count
              }
          end
          }
      end
    end
    
    render_success(cached_response, 'Most purchased products by category')
  end
  
  # GET /api/v1/products/top_revenue_by_category
  def top_revenue_by_category
    cache_key = "products/top_revenue/#{params[:limit]}/#{Product.maximum(:updated_at)&.to_i}"

    cached_response = cache_api_response(cache_key, expires_in: 1.hour) do
      products = Product.top_revenue_by_category

      grouped_results = products.group_by { |r| [r.category_id, r.category_name] }
    
      grouped_results.map do |(category_id, category_name), products|
        {
          category: {
            id: category_id,
            name: category_name
          },
          top_products: products.first(3).map do |product|
            {
              id: product.id,
              name: product.name,
              total_revenue: product.total_revenue.to_f
            }
          end
        }
      end
    end   
    render_success(cached_response, 'Top 3 revenue products by category')
  end
  
  private
  
  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Producto no encontrado', :not_found)
  end
      
  def product_params
    begin
      params.require(:product).permit(
        :name, :description, :price, :stock,
        category_ids: [],
        product_images_attributes: [:image_url, :caption]
      )
    rescue ActionController::ParameterMissing => e
      Rails.logger.error "Parameter missing in product_params: #{e.message}"
      raise ActionController::ParameterMissing.new(e.param, e.message)
    end
  end

  def serialize_product(product, include_details: false)
    base_data = {
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price.to_f,
      stock: product.stock,
      created_at: product.created_at,
      categories: product.categories.map { |c| { id: c.id, name: c.name } },
      images: product.product_images.map { |img| { url: img.image_url, caption: img.caption } },
      admin: {
        id: product.admin&.id,
        name: product.admin&.name
      }
    }
    
    if include_details
      base_data.merge!(
        total_purchases: product.total_purchases_count,
        total_revenue: product.total_revenue.to_f,
        first_purchase: product.first_purchase&.purchased_at,
        last_purchase: product.last_purchase&.purchased_at
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

  def clear_product_caches
    # Clear cache for all products
    Rails.cache.delete_matched('products/*')
  end
end
