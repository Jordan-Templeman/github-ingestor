source 'https://rubygems.org'

ruby '3.2.10'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.1.6'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use HTTP client for GitHub API
gem 'httparty'

# Use JSON:API serializer
gem 'jsonapi-serializer'

# Background job processing
gem 'connection_pool', '~> 2.4'
gem 'sidekiq', '~> 7.0'

# Recurring job scheduling
gem 'sidekiq-scheduler', '~> 5.0'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows]

  # Linting and style enforcement
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false

  # RSpec testing framework
  gem 'rspec'
  gem 'rspec-rails'

  # Factory bot for test data
  gem 'factory_bot_rails'

  # Faker for generating test data
  gem 'faker'

  # WebMock for stubbing HTTP requests
  gem 'webmock'
end

group :test do
  # Shoulda matchers for testing Rails functionality
  gem 'shoulda-matchers'

  # Timecop for time-based testing
  gem 'timecop'
end
