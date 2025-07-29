FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    description { Faker::Lorem.sentence }
    association :admin
  end
end
