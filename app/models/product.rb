class Product < ApplicationRecord
  belongs_to :admin
  
  # Many-to-many with categories
  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories
  
  # One-to-many with images
  has_many :product_images, dependent: :destroy
  accepts_nested_attributes_for :product_images, allow_destroy: true
  
  # One-to-many with purchases
  has_many :purchases, dependent: :destroy

  # One-to-many with audit logs
  has_many :audit_logs, as: :auditable, dependent: :destroy
    
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :must_have_at_least_one_image
  
  # Scopes
  scope :in_stock, -> { where('stock > 0') }
  scope :out_of_stock, -> { where(stock: 0) }
  scope :by_category, ->(category_id) { joins(:categories).where(categories: { id: category_id }) }
  scope :by_price_range, ->(min_price, max_price) { where(price: min_price..max_price) }
  
  # Callbacks
  after_create :log_creation
  after_update :log_changes
  before_destroy  :log_deletion
  
  # Add validation logging
  after_validation :log_validation_errors

  # Instance methods
  def total_purchases_count
    purchases.count
  end
  
  def total_revenue
    purchases.sum(:total_price)
  end
  
  def first_purchase
    purchases.order(:purchased_at).first
  end
  
  def last_purchase
    purchases.order(:purchased_at).last
  end

  def first_purchase?
    purchases.count == 1
  end
  
  def total_sold
    purchases.sum(:quantity)
  end

  # Reduce stock después de una compra
  def reduce_stock!(quantity)
    if stock >= quantity
      update!(stock: stock - quantity)
    else
      raise StandardError, "Stock insuficiente. Stock actual: #{stock}"
    end
  end

  # Métodos de clase
  def self.most_purchased_by_category(limit = 10)
    joins(:purchases, :categories)
      .group('categories.id', 'categories.name', 'products.id', 'products.name')
      .order('categories.name', 'COUNT(purchases.id) DESC')
      .limit(limit)
      .select('categories.id as category_id, 
               categories.name as category_name, 
               products.id, 
               products.name, 
               COUNT(purchases.id) as purchase_count
              ')
  end
  
  def self.top_revenue_by_category
    # Get categories with their total revenue, ordered by revenue descending
    top_categories = Category.joins(products: :purchases)
      .group('categories.id', 'categories.name')
      .order('SUM(purchases.total_price) DESC')
      .limit(3)
      .select('categories.id, categories.name, SUM(purchases.total_price) as category_total_revenue')
    
    # For each top category, get the top 3 products
    result = []
    top_categories.each do |category|
      category_products = joins(:purchases, :categories)
        .where(categories: { id: category.id })
        .group('categories.id', 'categories.name', 'products.id', 'products.name')
        .order('SUM(purchases.total_price) DESC')
        .limit(3)
        .select('categories.id as category_id, 
                 categories.name as category_name,
                 products.id, 
                 products.name, 
                 SUM(purchases.total_price) as total_revenue
                ')
      
      result.concat(category_products)
    end
    
    result
  end
  
  private

  def log_validation_errors
    if errors.any?
      Rails.logger.error "Product validation errors: #{errors.full_messages.join(', ')}"
      Rails.logger.error "Product attributes: #{attributes.except('created_at', 'updated_at')}"
    end
  end

  def must_have_at_least_one_image
    # Solo validar si el producto ya tiene ID (ya fue guardado) y no tiene imágenes
    # Pero no validar si estamos en el proceso de creación con nested attributes
    if persisted? && product_images.empty? && !respond_to?(:product_images_attributes=)
      errors.add(:product_images, 'debe tener al menos una imagen')
    end
  end
    
  def log_creation
    AuditLog.create!(
      admin: Current.admin || admin,
      auditable: self,
      action: 'created',
      changes_data: attributes.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for product: #{e.message}"
    # Don't fail the main transaction if audit log fails
  end
  
  def log_changes
    return unless saved_changes.any?
    
    AuditLog.create!(
      admin: Current.admin || admin,
      auditable: self,
      action: 'updated',
      changes_data: saved_changes.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for product changes: #{e.message}"
    # Don't fail the main transaction if audit log fails
  end

  def log_deletion
    AuditLog.create!(
      admin: Current.admin || admin,
      auditable: self,
      action: 'deleted',
      changes_data: attributes.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for product deletion: #{e.message}"
    # Don't fail the main transaction if audit log fails
  end
end
