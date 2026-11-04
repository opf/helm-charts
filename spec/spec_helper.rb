require_relative 'helm_template'
require 'yaml'
require 'debug'
require 'hash_deep_merge'

RSpec.configure do |config|
  # Integration specs need a cluster (see integration_helper.rb); run them with `--tag integration`.
  config.filter_run_excluding :integration

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
