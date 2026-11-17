require 'simplecov'
require 'undercover/simplecov_formatter'

SimpleCov.start do
  minimum_coverage 95
  coverage(:line) { minimum 70, per: :file }
  formatter SimpleCov::Formatter::MultiFormatter.new([ SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::Undercover ])
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end
