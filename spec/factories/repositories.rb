FactoryBot.define do
  factory :repository do
    transient do
      owner { Faker::Internet.username }
    end

    sequence(:github_id) { |n| 2000 + n }
    name { Faker::App.name.parameterize }
    full_name { "#{owner}/#{name}" }
    url { "https://api.github.com/repos/#{full_name}" }
  end
end
