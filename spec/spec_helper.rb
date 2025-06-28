ENV["RAILS_ENV"] = "test"

require "byebug"
require "veri"
require "database_cleaner/active_record"
require "action_controller/railtie"
require "rspec/rails"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expose_dsl_globally = true

  config.include ActiveSupport::Testing::TimeHelpers

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    Veri::Configuration.reset_config

    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

if ENV["UUID_TESTS"]
  load "#{File.dirname(__FILE__)}/support/uuid_schema.rb"
else
  load "#{File.dirname(__FILE__)}/support/id_schema.rb"
end

require "#{File.dirname(__FILE__)}/support/models"
require "#{File.dirname(__FILE__)}/support/application"
require "#{File.dirname(__FILE__)}/support/configuration"
require "#{File.dirname(__FILE__)}/support/controllers"

if ENV["UUID_TESTS"]
  require "securerandom"

  ActiveSupport.on_load(:active_record) do
    [Veri::Session, User, Client].each do |model_class|
      model_class.before_create do
        self.id = SecureRandom.uuid if id.blank?
      end
    end
  end
end
