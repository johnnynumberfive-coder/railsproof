ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [
  File.expand_path("../test/dummy/db/migrate", __dir__)
]
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [
    File.expand_path("fixtures", __dir__)
  ]
  ActionDispatch::IntegrationTest.fixture_paths =
    ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path =
    File.expand_path("fixtures", __dir__) + "/"
end

class RailsProof::TestAiClient
  attr_accessor :suggestions
  attr_reader :contexts

  def initialize(suggestions: [])
    @suggestions = suggestions
    @contexts = []
  end

  def suggest_tests(context:)
    @contexts << context
    suggestions
  end
end

RailsProof.ai_client = RailsProof::TestAiClient.new
