class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  
  # Método helper para logging de cambios
  def self.with_audit_log(admin, &block)
    Current.set(admin: admin, &block)
  end
end
