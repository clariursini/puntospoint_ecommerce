FactoryBot.define do
  factory :product_image do
    image_url { Faker::Internet.url(host: 'example.com', path: '/images') }
    caption { Faker::Lorem.sentence }
    association :product
  end
end
