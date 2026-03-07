FactoryBot.define do
  factory :push_event do
    sequence(:github_id) { |n| "evt_#{n}" }
    actor
    repository
    ref { "refs/heads/main" }
    head { SecureRandom.hex(20) }
    add_attribute(:before) { SecureRandom.hex(20) }
    push_id { rand(1_000_000..9_999_999) }
    raw_payload { { "type" => "PushEvent", "id" => github_id } }
  end
end
