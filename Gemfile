source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

# Rails core
gem "rails", "~> 7.2.2", ">= 7.2.2.1"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", ">= 1.4.4", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# API specific
gem "jbuilder"
gem "jwt"
gem "bcrypt", "~> 3.1.7"
gem "rack-cors"

# Background jobs
gem "sidekiq"
gem "redis", ">= 4.0.1"
gem "sidekiq-scheduler"
gem 'chronic'


# Image processing
gem "image_processing", "~> 1.2"

# Data generation and utilities
gem "faker"

# Time-based grouping for queries
gem "groupdate"

# Pagination
gem "kaminari"

group :development, :test do
  # Testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  
  # Debugging and development tools
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "pry-rails"
  
  # Security and code quality
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Development tools
  gem "web-console"
  gem "listen", "~> 3.3"
  gem "spring"
  gem "annotate"
  gem "bullet" # Para detectar N+1 queries
end

group :test do
  # Testing utilities
  gem "webmock"
  gem "vcr"
  gem "timecop"
end


