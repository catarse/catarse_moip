FactoryGirl.define do
  sequence :key do |n|
    "#{n}"
  end

  sequence :payment_id do |n|
    "#{n}"
  end

  factory :contribution, class: PaymentEngines do
    skip_create

    key
    payment_id
    gateway_id '000.000.12.31'
    value 100
  end
end
