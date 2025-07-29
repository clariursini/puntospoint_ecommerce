class ProductCategory < ApplicationRecord
  belongs_to :product
  belongs_to :category
  
  # Validations
  validates :product_id, uniqueness: { scope: :category_id }

  # Callbacks
  after_create :log_association
  after_destroy :log_disassociation

  private

  def log_association
    AuditLog.create!(
      admin: product.admin,
      auditable: self,
      action: 'category_associated',
      changes_data: { category_id: category_id, category_name: category.name }.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for category association: #{e.message}"
    # Don't fail the main transaction if audit log fails
  end

  def log_disassociation
    AuditLog.create!(
      admin: product.admin,
      auditable: self,
      action: 'category_disassociated',
      changes_data: { category_id: category_id, category_name: category.name }.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create audit log for category disassociation: #{e.message}"
    # Don't fail the main transaction if audit log fails
  end
end
