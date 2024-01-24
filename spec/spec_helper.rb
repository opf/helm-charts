require_relative 'helm_template'
require 'yaml'
require 'debug'
require 'hash_deep_merge'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
