FactoryBot.define do
  factory :repository do
    sequence(:github_id) { |n| 2000 + n }
    name { Faker::App.name.parameterize }
    full_name { "#{Faker::Internet.username}/#{name}" }
    url { "https://api.github.com/repos/#{full_name}" }
  end
end
