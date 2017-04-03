
as_model = yes?("Create Rails app as data model only?")

use_jbuilder = false
use_guard_rails = false
use_slim = false

unless as_model
  use_jbuilder = yes?("Use jbuilder to Build JSON APIs?")
  use_guard_rails = yes?("Use Guard Rails to restart Rails server?")
  use_slim = yes?("Use Slim?")
end

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
end unless as_model

gem_group :development do
  gem 'rails-i18n-generator'
end

gem_group :development, :test do
  # guard
  gem 'guard', '~> 2.14', '>= 2.14.1'
  gem 'guard-rspec', '~> 4.7', '>= 4.7.3'
  gem 'guard-bundler'
  gem 'guard-livereload' unless as_model
  gem 'guard-rails' if use_guard_rails

  gem 'letter_opener', '~> 1.4', '>= 1.4.1' unless as_model

  gem 'pry-rails'
  gem 'rails-erd', '~> 1.5'
end

gem_group :test do
  gem 'simplecov', '~> 0.14.1'
  # test
  gem 'rspec-rails', '~> 3.5' if use_rspec
  gem 'capybara', '~> 2.13' unless as_model
  gem 'factory_girl_rails', '~> 4.8'
  gem 'database_cleaner', '~> 1.5', '>= 1.5.3'
  gem 'shoulda-matchers', '~> 3.1', '>= 3.1.1'
  gem 'email_spec', '~> 2.1' unless as_model
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

    unless as_model
      add_file 'spec/support/api.rb', <<-CODE.strip_heredoc
      RSpec.configure do |config|
        config.include RSpec::Rails::RequestExampleGroup, type: :api
        config.before(:each, type: :api) do |example|
          host! 'api.example.com'
        end
      end
      CODE
    end

    git add: '.'
    git commit: '-a -m "setup for test"'
  end

  application <<-CODE.strip_heredoc
    config.generators do |g|
          g.scaffold_stylesheet false # don't generate app/assets/stylesheets/scaffolds.scss
          #{'
          g.helper false
          g.stylesheets false
          g.javascripts false
          ' if as_model}
          #{'g.test_framework :rspec' if use_rspec }
          #{'g.jbuilder false' unless use_jbuilder}
        end
        I18n.config.enforce_available_locales = false

        config.i18n.available_locales = ["en", "zh-CN"]
        config.i18n.default_locale = "en".to_sym

        paths['config/locales'].unshift File.expand_path('../config/locales', __dir__)
        initializer do
          config.i18n.railties_load_path.unshift app.config.paths["config/locales"]
        end
  CODE
  git add: '.'
  git commit: '-a -m "setup generator"'

  run "gurad init"
  git add: '.'
  git commit: '-a -m "setup for guard"'

  unless as_model
    git add: '.'
    environment 'config.action_mailer.delivery_method = :letter_opener', env: 'development'
    git commit: '-a -m "setup for letter_opener"'
  end

  if as_model

    remove_dir 'app/assets'
    remove_dir 'app/channels'
    remove_dir 'app/controllers'
    remove_dir 'app/helpers'
    remove_dir 'app/jobs'
    remove_dir 'app/mailers'
    remove_dir 'app/views'
    remove_dir 'vendor'

    add_file "#{app_name}.gemspec", <<-CODE.strip_heredoc
    $:.push File.expand_path("../lib", __FILE__)

    # Describe your gem and declare its dependencies:
    Gem::Specification.new do |s|
      s.name        = "#{app_name}"
      s.version     = '0.0.1'
      s.authors     = ["author"]
      s.email       = ["author@example.net"]
      s.homepage    = ""
      s.summary     = "Summary of Account."
      s.description = "Description of Account."
      s.license     = "MIT"

      s.files = Dir[
        "app/models/**/*",
        "config/locales/**/*",
        "db/migrate/**/*",
        "db/seeds.rb",
        "lib/#{app_name}/**/*",
        "MIT-LICENSE", "Rakefile", "README.md"]

      s.add_runtime_dependency "rails", "~> 5.0.0"
    end
    CODE

    add_file "lib/#{app_name}/railtie.rb", <<-CODE.strip_heredoc
    module #{app_name.classify}
      class Railtie < Rails::Railtie

        initializer '#{app_name}.set_paths', before: :bootstrap_hook do |app|
          ActiveSupport::Dependencies.autoload_paths.unshift(File.expand_path('../../app/models', __dir__))
          $LOAD_PATH.unshift File.expand_path('../../app/models', __dir__)
          $LOAD_PATH.unshift File.expand_path('../../app/models/concerns', __dir__)

          app.config.paths['db/migrate'].unshift File.expand_path('../../db/migrate', __dir__)
          app.config.paths['db/seeds.rb'].unshift File.expand_path('../../db/seeds.rb', __dir__)
          app.config.paths['config/locales'].unshift File.expand_path('../../config/locales', __dir__)
        end

        initializer '#{app_name}.add_locales' do |app|
          app.config.i18n.railties_load_path.unshift app.config.paths["config/locales"]
        end
      end
    end
    CODE

    append_file 'README.md', <<-README.strip_heredoc

    ## Include this project as a Model lib

    Go to your destination project directory, add this into \`Gemfile\`

      gem '#{app_name}', path: '../#{app_name}'

    or

      gem '#{app_name}', git: 'http://your.git-repo.com/#{app_name}.git'

    add this into \`config/application.rb\`

      require '#{app_name}/railtie'

    Now, you can call #{app_name}'s models from your destination project

    README

    git add: '.'
    git commit: '-a -m "setup for model project"'
  end
end

