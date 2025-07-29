class Customer < ApplicationRecord
  # Associations
  has_many :purchases, dependent: :destroy
  has_many :products, through: :purchases

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :address, length: { minimum: 10, maximum: 500 }, allow_blank: true
  validates :phone, format: { with: /\A[\+]?[0-9]{8,15}\z/, message: "formato inválido" }, allow_blank: true
  
  # Callbacks
  before_validation :normalize_email

  # Scopes
  scope :with_purchases, -> { includes(:purchases) }
  
  # Instance methods
  def total_spent
    purchases.sum(:total_price)
  end
  
  def purchase_count
    purchases.count
  end
  
  def last_purchase_date
    purchases.maximum(:purchased_at)
  end

  def first_purchase
    purchases.order(:purchased_at).first
  end
  
  def last_purchase
    purchases.order(:purchased_at).last
  end
  
  def favorite_categories
    Category.joins(products: :purchases)
            .where(purchases: { customer: self })
            .group('categories.id', 'categories.name')
            .order('COUNT(purchases.id) DESC')
            .limit(5)
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
end
