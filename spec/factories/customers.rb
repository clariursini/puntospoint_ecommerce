FactoryBot.define do
  factory :customer do
    sequence(:email) { |n| "customer#{n}@example.com" }
    sequence(:name) { |n| "Customer #{n}" }
    phone { "+1#{rand(100000000..999999999)}" }
    address { Faker::Address.full_address }
  end
end
