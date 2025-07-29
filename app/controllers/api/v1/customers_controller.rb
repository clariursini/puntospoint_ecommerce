class Api::V1::CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :update, :destroy]
  
  # GET /api/v1/customers
  def index
    @customers = Customer.includes(:purchases)
                       .page(params[:page])
                       .per(params[:per_page] || 20)
    
    render_success({
      customers: @customers.map { |customer| serialize_customer(customer) },
      pagination: pagination_meta(@customers)
    })
  end
  
  # GET /api/v1/customers/1
  def show
    render_success(serialize_customer(@customer, include_details: true))
  end
  
  # POST /api/v1/customers
  def create
    @customer = Customer.new(customer_params)
    
    if @customer.save
      render_success(serialize_customer(@customer), 'Customer created successfully')
    else
      error_details = @customer.errors.full_messages.join(', ')
      Rails.logger.error "Customer creation failed: #{error_details}"
      render_error('Error while creating the customer', error_details, :unprocessable_entity)
    end
  rescue => e
    Rails.logger.error "Exception in create customer: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_error('Error while creating the customer', e.message, :unprocessable_entity)
  end
  
  # PUT /api/v1/customers/1
  def update
    if @customer.update(customer_params)
      render_success(serialize_customer(@customer), 'Customer updated successfully')
    else
      render_error('Error while updating the customer', @customer.errors.full_messages.join(', '))
    end
  end
  
  # DELETE /api/v1/customers/1
  def destroy
    if @customer.destroy
      render_success(nil, 'Customer deleted successfully')
    else
      render_error('Cannot delete the customer', @customer.errors.full_messages.join(', '))
    end
  end
  
  private
  
  def set_customer
    @customer = Customer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Cliente no encontrado', :not_found)
  end
  
  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :address)
  end
  
  def serialize_customer(customer, include_details: false)
    base_data = {
      id: customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone,
      address: customer.address,
      created_at: customer.created_at
    }
    
    if include_details
      base_data.merge!(
        total_purchases_count: customer.purchase_count,
        total_spent: customer.total_spent.to_f,
        first_purchase: customer.first_purchase&.purchased_at,
        last_purchase: customer.last_purchase&.purchased_at,
        favorite_categories: customer.favorite_categories.map { |c| { id: c.id, name: c.name } }
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