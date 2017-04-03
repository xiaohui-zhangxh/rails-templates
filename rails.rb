
use_jbuilder = yes?("Use jbuilder to Build JSON APIs?")
use_guard_rails = yes?("Use Guard Rails to restart Rails server?")
use_slim = yes?("Use Slim?")
use_rspec = yes?("Use rspec to test?")

comment_lines 'Gemfile', /gem 'jbuilder'/ unless use_jbuilder
comment_lines 'Gemfile', /gem 'tzinfo-data'/

gem 'slim-rails', '~> 3.1', '>= 3.1.2' if use_slim

gem_group :development do
  gem 'capistrano', '~> 3.6'
  gem 'capistrano-rails', '~> 1.2'
  gem 'capistrano-rvm'
  gem 'capistrano-bundler', '~> 1.2'
  gem 'capistrano-passenger'
  gem 'capistrano-git-with-submodules', '~> 2.0'
end

gem_group :development, :test do
  # guard
  gem 'guard', '~> 2.14', '>= 2.14.1'
  gem 'guard-rspec', '~> 4.7', '>= 4.7.3'
  gem 'guard-bundler'
  gem 'guard-livereload'
  gem 'guard-rails' if use_guard_rails

  gem 'letter_opener', '~> 1.4', '>= 1.4.1'

  gem 'pry-rails'
  gem 'rails-erd', '~> 1.5'
end

gem_group :test do
  gem 'simplecov', '~> 0.14.1'
  # test
  gem 'rspec-rails', '~> 3.5' if use_rspec
  gem 'capybara', '~> 2.13'
  gem 'factory_girl_rails', '~> 4.8'
  gem 'database_cleaner', '~> 1.5', '>= 1.5.3'
  gem 'shoulda-matchers', '~> 3.1', '>= 3.1.1'
  gem 'email_spec', '~> 2.1'
end

after_bundle do
  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"

  if use_rspec
    run "rm -rf test"
    generate 'rspec:install'
    gsub_file '.rspec', /--require (spec_helper)/, 'rails_helper'

    uncomment_lines 'spec/rails_helper.rb', "Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }}"

    insert_into_file 'spec/rails_helper.rb', <<-CODE.strip_heredoc, after: "require 'rspec/rails'\n"
    require "email_spec"
    require "email_spec/rspec"
    require 'simplecov'
    SimpleCov.start
    CODE
    run 'mkdir spec/support'

    add_file 'spec/support/factory_girl.rb', <<-CODE.strip_heredoc
    RSpec.configure do |config|
      config.include FactoryGirl::Syntax::Methods
    end
    CODE

    add_file 'spec/support/database_cleaner.rb', <<-CODE.strip_heredoc
    RSpec.configure do |config|
      config.before(:each) do
        DatabaseCleaner.strategy = :transaction
      end
      config.before(:each, type: :request) do |example|
        DatabaseCleaner.strategy = :truncation
      end
      config.before(:each) do
        DatabaseCleaner.start
      end
      config.append_after(:each) do
        DatabaseCleaner.clean
      end
    end
    CODE

    add_file 'spec/support/shoulda-matchers.rb', <<-CODE.strip_heredoc
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
    CODE

    add_file 'spec/support/api.rb', <<-CODE.strip_heredoc
    RSpec.configure do |config|
      config.include RSpec::Rails::RequestExampleGroup, type: :api
      config.before(:each, type: :api) do |example|
        host! 'api.example.com'
      end
    end
    CODE

    git add: '.'
    git commit: '-a -m "setup for test"'
  end

  application <<-CODE.strip_heredoc
    config.generators do |g|
          g.helper false
          g.stylesheets false
          g.javascripts false
          #{'g.test_framework :rspec' if use_rspec }
          #{'g.jbuilder false' unless use_jbuilder}
        end
  CODE
  git add: '.'
  git commit: '-a -m "setup generator"'

  run "gurad init"
  git add: '.'
  git commit: '-a -m "setup for guard"'

  git add: '.'
  environment 'config.action_mailer.delivery_method = :letter_opener', env: 'development'
  git commit: '-a -m "setup for letter_opener"'
end

