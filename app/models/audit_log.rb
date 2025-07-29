class AuditLog < ApplicationRecord
  belongs_to :admin
  belongs_to :auditable, polymorphic: true
  
  # Enum para acciones comunes
  ACTIONS = %w[created updated deleted category_associated category_disassociated].freeze
  
  # Validations
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :changes_data, presence: true
  
  # Scopes
  scope :by_action, ->(action) { where(action: action) }
  scope :by_auditable_type, ->(type) { where(auditable_type: type) }
  scope :by_admin, ->(admin_id) { where(admin_id: admin_id) }
  scope :recent, -> { order(created_at: :desc) }
    
  # Instance methods
  def changes_hash
    return {} if changes_data.blank?
    
    parsed = JSON.parse(changes_data) rescue {}
    return {} if parsed.nil?
    
    parsed
  end

  def formatted_changes
    return "" if changes_hash.empty?
    
    changes_hash.map do |key, value|
      if value.is_a?(Array) && value.length == 2
        "#{key}: [\"#{value[0]}\", \"#{value[1]}\"]"
      else
        "#{key}: #{value}"
      end
    end.join(', ')
  end
end
