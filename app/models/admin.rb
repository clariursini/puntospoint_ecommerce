class Admin < ApplicationRecord
  has_secure_password
  
  # Associations
  has_many :products, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  
  # Callbacks
  before_validation :normalize_email
  
  # Método para generar JWT token
  def generate_jwt_token
    payload = {
      admin_id: id,
      email: email,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, JWT_SECRET, JWT_ALGORITHM)
  end
  
  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
