FactoryBot.define do
  factory :purchase do
    quantity { 1 }  # Siempre usar 1 para evitar problemas de stock
    purchased_at { Faker::Time.between(from: 30.days.ago, to: Time.current) }
    association :customer
    association :product

    # Trait para cantidad específica
    trait :with_quantity do
      transient do
        qty { 1 }
      end
      quantity { qty }
    end

    # Trait para total_price específico
    trait :with_total_price do
      transient do
        price { 100 }
      end
      total_price { price }
    end
  end
end