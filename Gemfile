source 'https://rubygems.org'

gemspec

rails_version = ENV.fetch('RAILS_VERSION', '~> 8.1.0')
gem 'railties', rails_version
gem 'actionpack', rails_version
# activesupport 7.2.3 and 8.0.5.1 pass quirks_mode:, which json 3.0+ rejects.
gem 'json', '< 3' if rails_version.match?(/7\.2|8\.0/)

gem 'rake'
gem 'rspec-rails'
gem 'rubocop-rails-omakase', require: false
