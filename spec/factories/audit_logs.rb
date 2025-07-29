FactoryBot.define do
  factory :audit_log do
    association :admin
    association :auditable, factory: :product
    action { "created" }
    changes_data { "{}" }
  end
end
