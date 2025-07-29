class Category < ApplicationRecord
  belongs_to :admin
  
  # Many-to-many with products
  has_many :product_categories, dependent: :destroy
  has_many :products, through: :product_categories
  has_many :audit_logs, as: :auditable, dependent: :destroy
  
  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :name, length: { minimum: 2, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 500 }
  
  # Scopes
  scope :with_products, -> { includes(:products) }
  
  # Callbacks
  after_create :log_creation
  after_update :log_changes
  after_destroy :log_deletion

  # Métodos de instancia
  def total_purchases
    products.joins(:purchases).count
  end
  
  def total_revenue
    products.joins(:purchases).sum('purchases.total_price')
  end
  
  # Obtener productos más comprados en esta categoría
  def most_purchased_products(limit = 10)
    products.joins(:purchases)
            .group('products.id')
            .order('COUNT(purchases.id) DESC')
            .limit(limit)
            .select('products.*, COUNT(purchases.id) as purchase_count')
  end
  
  # Obtener productos que más han recaudado en esta categoría
  def top_revenue_products(limit = 3)
    products.joins(:purchases)
            .group('products.id')
            .order('SUM(purchases.total_price) DESC')
            .limit(limit)
            .select('products.*, SUM(purchases.total_price) as total_revenue')
  end
  
  private
  
  def log_creation
    AuditLog.create!(
      admin: Current.admin || admin,
      auditable: self,
      action: 'created',
      changes_data: attributes.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for category: #{e.message}"
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
    Rails.logger.error "Failed to create audit log for category changes: #{e.message}"
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
    Rails.logger.error "Failed to create audit log for category deletion: #{e.message}"
    # Don't fail the main transaction if audit log fails
  end
end
