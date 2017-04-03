# rails-templates

A set of templates for generating new Rails app

### rails.rb

`rails new my_app -m https://raw.githubusercontent.com/xiaohui-zhangxh/rails-templates/master/rails.rb`

will setup most popular gems to start up:

- Dev tools:
  - guard
  - guard-rspec
  - guard-bundler
  - guard-livereload
  - guard-rails
  - rails-erd
  - pry-rails
  - letter_opener
- Test:
  - simplecov
  - rspec-rails
  - capybara
  - factory_girl_rails
  - database_cleaner
  - shoulda-matchers
  - email_spec
- Configuration:
  - Disable generators:
    - helper
    - stylesheets
    - javascripts
    - jbuilder
  
