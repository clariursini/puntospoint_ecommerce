FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    description { Faker::Lorem.paragraph }
    price { Faker::Commerce.price(range: 10..1000) }
    stock { Faker::Number.between(from: 1, to: 100) }
    association :admin

    trait :with_images do
      after(:create) do |product|
        create_list(:product_image, 2, product: product)
      end
    end

    trait :with_categories do
      after(:create) do |product|
        categories = create_list(:category, 2, admin: product.admin)
        product.categories << categories
      end
    end
  end
end
