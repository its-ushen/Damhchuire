ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

ActiveRecord::Encryption.configure(
  primary_key: "test-primary-key-that-is-32-bytes",
  deterministic_key: "test-deterministic-key-32-bytes!",
  key_derivation_salt: "test-key-derivation-salt"
)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
