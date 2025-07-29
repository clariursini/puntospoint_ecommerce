class Purchase < ApplicationRecord
  belongs_to :customer
  belongs_to :product
  
  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :total_price, presence: true, numericality: { greater_than: 0 }
  validates :purchased_at, presence: true
  validate :sufficient_stock
  
  # Callbacks
  before_validation :set_purchased_at, :calculate_total_price, on: :create
  after_create :send_first_purchase_email
  after_create :update_product_stock
  
  # Scopes
  scope :recent, -> { order(purchased_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(purchased_at: start_date..end_date) }
  scope :by_category, ->(category_id) { joins(product: :categories).where(categories: { id: category_id }) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_admin, ->(admin_id) { joins(product: :admin).where(products: { admin_id: admin_id }) }
  scope :today, -> { where(purchased_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :yesterday, -> { where(purchased_at: Date.yesterday.beginning_of_day..Date.yesterday.end_of_day) }

  # Instance methods
  def is_first_purchase?
    product.purchases.where('id < ?', id).count == 0
  end

  def is_first_purchase_of_product?
    Purchase.where(product: product).where('purchased_at < ?', purchased_at).empty?
  end

  def unit_price
    product&.price || 0
  end

  # Métodos de clase para reportes
  def self.count_by_granularity(granularity, filters = {})
    purchases = apply_filters(filters)
    
    case granularity.to_s
    when 'hour'
      result = purchases.group_by_hour(:purchased_at, format: '%Y-%m-%d %H:00').count
      result.transform_keys { |k| k.to_s }
    when 'day'
      result = purchases.group_by_day(:purchased_at, format: '%Y-%m-%d').count
      result.transform_keys { |k| k.to_s }
    when 'week'
      result = purchases.group_by_week(:purchased_at, format: '%Y-W%U').count
      result.transform_keys { |k| k.to_s }
    when 'year'
      result = purchases.group_by_year(:purchased_at, format: '%Y').count
      result.transform_keys { |k| k.to_s }
    else
      result = purchases.group_by_day(:purchased_at, format: '%Y-%m-%d').count
      result.transform_keys { |k| k.to_s }
    end
  end

  def self.apply_filters(filters)
    purchases = self.all

    # Filter by date range
    if filters[:start_date] && filters[:end_date]
      begin
        start_date = Time.parse(filters[:start_date].to_s)
        end_date = Time.parse(filters[:end_date].to_s)
        purchases = purchases.where('purchased_at BETWEEN ? AND ?', start_date, end_date)
      rescue ArgumentError
        # Fallback to Date.parse for date-only strings
        start_date = Date.parse(filters[:start_date].to_s).beginning_of_day
        end_date = Date.parse(filters[:end_date].to_s).end_of_day
        purchases = purchases.by_date_range(start_date, end_date)
      end
    elsif filters[:start_date]
      begin
        start_date = Time.parse(filters[:start_date].to_s)
        purchases = purchases.where('purchased_at >= ?', start_date)
      rescue ArgumentError
        start_date = Date.parse(filters[:start_date].to_s).beginning_of_day
        purchases = purchases.where('purchased_at >= ?', start_date)
      end
    elsif filters[:end_date]
      begin
        end_date = Time.parse(filters[:end_date].to_s)
        purchases = purchases.where('purchased_at <= ?', end_date)
      rescue ArgumentError
        end_date = Date.parse(filters[:end_date].to_s).end_of_day
        purchases = purchases.where('purchased_at <= ?', end_date)
      end
    end
    
    # Filter by category
    purchases = purchases.by_category(filters[:category_id]) if filters[:category_id]
    purchases = purchases.by_customer(filters[:customer_id]) if filters[:customer_id]
    purchases = purchases.by_admin(filters[:admin_id]) if filters[:admin_id]
    
    purchases
  end
  
  def self.daily_report(date = Date.yesterday)
    purchases = by_date_range(date.beginning_of_day, date.end_of_day)
    
    {
      date: date,
      total_purchases: purchases.count,
      total_revenue: purchases.sum(:total_price),
      products_sold: purchases.joins(:product).group('products.name').sum(:quantity),
      categories_performance: purchases.joins(product: :categories)
                                      .group('categories.name')
                                      .select('categories.name, COUNT(*) as purchase_count, SUM(purchases.total_price) as revenue')
    }
  end
  
  private
  
  def set_purchased_at
    self.purchased_at ||= Time.current
  end

  def calculate_total_price
    if quantity.present? && product.present?
      self.total_price = quantity * product.price
    elsif quantity.present? && product_id.present?
      # Try to find the product
      found_product = Product.find_by(id: product_id)
      if found_product
        self.total_price = quantity * found_product.price
      else
        errors.add(:product_id, "no existe")
      end
    end
  end

  def sufficient_stock
    if product && quantity && product.stock < quantity
      errors.add(:quantity, "excede el stock disponible (#{product.stock})")
    end
  end

  def update_product_stock
    product.reduce_stock!(quantity)
  rescue => e
    Rails.logger.error "Failed to update product stock: #{e.message}"
    errors.add(:base, "Error updating product stock: #{e.message}")
    throw(:abort)
  end

  def send_first_purchase_email
    return unless is_first_purchase?
    
    FirstPurchaseEmailJob.perform_later(self)
  rescue => e
    Rails.logger.error "Failed to send first purchase email: #{e.message}"
    # Don't fail the main transaction if email fails
  end
  
end
