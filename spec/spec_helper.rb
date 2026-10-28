require 'simplecov'
require 'undercover/simplecov_formatter'

SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 95
  minimum_coverage_by_file 70
  formatter SimpleCov::Formatter::MultiFormatter.new([ SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::Undercover ])
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end
