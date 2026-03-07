FactoryBot.define do
  factory :actor do
    sequence(:github_id) { |n| 1000 + n }
    login { Faker::Internet.username }
    display_login { login }
    avatar_url { Faker::Internet.url }
    url { "https://api.github.com/users/#{login}" }
  end
end
