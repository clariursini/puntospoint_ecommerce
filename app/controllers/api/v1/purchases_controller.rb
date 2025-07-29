class Api::V1::PurchasesController < ApplicationController 

   # GET /api/v1/purchases/filtered
   def filtered
    filters = {
        start_date: params[:start_date],
        end_date: params[:end_date],
        category_id: params[:category_id],
        customer_id: params[:customer_id],
        admin_id: params[:admin_id]
      }.compact

    # Apply filters
    @purchases = Purchase.apply_filters(filters)
                         .includes(:customer, :product, product: [:categories, :admin])
                         .page(params[:page])
                         .per(params[:per_page] || 20)
    
    render_success({
      purchases: @purchases.map { |purchase| serialize_purchase(purchase) },
      pagination: pagination_meta(@purchases),
      filters_applied: filters
    }, 'Purchases filtered')
  end

  # POST /api/v1/purchases
  def create
    @purchase = Purchase.new(purchase_params)

    if @purchase.save
      # Clear purchase caches after creating
      clear_purchase_caches
      render_success(serialize_purchase(@purchase), 'Purchase created successfully')
    else
      error_details = @purchase.errors.full_messages.join(', ')
      Rails.logger.error "Purchase errors: #{@purchase.errors.inspect}"
      render_error('Error while creating the purchase', error_details, :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found in create purchase: #{e.message}"
    render_error('Error while creating the purchase', e.message, :not_found)
  rescue => e
    Rails.logger.error "Exception in create purchase: #{e.message}"
    render_error('Error while creating the purchase', e.message, :unprocessable_entity)
  end

  # GET /api/v1/purchases/count_by_granularity
  def count_by_granularity
    granularity = params[:granularity] || 'day'

    unless %w[hour day week year].include?(granularity)
      return render_error('Invalid granularity. Must be: hour, day, week, year', nil, :bad_request)
    end

    # Apply filters
    filters = {
        start_date: params[:start_date],
        end_date: params[:end_date],
        category_id: params[:category_id],
        client_id: params[:client_id],
        administrator_id: params[:administrator_id]
      }.compact
      
    # Usar el método del modelo
    grouped_data = Purchase.count_by_granularity(granularity, filters)

    # Format for frontend/graphs
    formatted_data = grouped_data.transform_keys(&:to_s)

    response_data = {
      grouped_data: formatted_data,
      total_purchases: grouped_data.values.sum,
      filters_applied: params.except(:granularity, :controller, :action)
    }

    render_success(response_data, "Purchases grouped by #{granularity}")
  end

  # GET /api/v1/purchases/daily_report
  def daily_report
    date = params[:date] ? Date.parse(params[:date]) : Date.yesterday
    report = Purchase.daily_report(date)
    render_success(report, "Daily report for #{date}")
  end
  
  private
      
  def purchase_params
    begin
      params.require(:purchase).permit(:customer_id, :product_id, :quantity, :purchased_at)
    rescue ActionController::ParameterMissing => e
      Rails.logger.error "Parameter missing in purchase_params: #{e.message}"
      raise ActionController::ParameterMissing.new(e.param, e.message)
    end
  end

  def serialize_purchase(purchase)
    {
      id: purchase.id,
      quantity: purchase.quantity,
      total_price: purchase.total_price.to_f,
      unit_price: purchase.unit_price.to_f,
      purchased_at: purchase.purchased_at,
      customer: {
        id: purchase.customer.id,
        name: purchase.customer.name,
        email: purchase.customer.email
      },
      product: {
        id: purchase.product.id,
        name: purchase.product.name,
        price: purchase.product.price.to_f,
        categories: purchase.product.categories.map { |c| { id: c.id, name: c.name } },
        admin: {
          id: purchase.product.admin.id,
          name: purchase.product.admin.name
        }
      }
    }
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

  def clear_purchase_caches
    # Clear cache for all purchases
    Rails.cache.delete_matched('purchases/*')
  end
end
