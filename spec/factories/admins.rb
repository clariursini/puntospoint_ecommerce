FactoryBot.define do
  factory :admin do
    sequence(:email) { |n| "admin#{n}@example.com" }
    sequence(:name) { |n| "Admin #{n}" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
