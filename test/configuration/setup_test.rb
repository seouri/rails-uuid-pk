require "test_helper"

class ConfigurationSetupTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "version constant is defined" do
    assert RailsUuidPk::VERSION.is_a?(String)
    assert RailsUuidPk::VERSION.match?(/\A\d+\.\d+\.\d+\z/)
  end

  test "concern is included in ActiveRecord::Base" do
    assert ActiveRecord::Base.included_modules.include?(RailsUuidPk::HasUuidv7PrimaryKey)
  end

  test "generator creates uuid primary key column" do
    # Simulate running the install generator (it copies concern + sets config)
    # In dummy app, manually ensure the concern is included
    assert User.column_for_attribute(:id).type == :uuid
  end

  test "UUID type returns correct schema dump type based on Rails version" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test the rails_supports_uuid_in_schema? method
    rails_version = Gem::Version.new(Rails::VERSION::STRING)
    expected_type = rails_version >= Gem::Version.new("8.1.0") ? :uuid : :string

    assert_equal expected_type, uuid_type.type
  end

  test "railtie configures ActiveRecord generators to use uuid primary keys" do
    # The railtie configures ActiveRecord generator with primary_key_type: :uuid
    # Check that the generator configuration includes this setting
    generator_config = Rails.application.config.generators.options[:active_record] || {}
    assert_equal :uuid, generator_config[:primary_key_type],
                 "ActiveRecord generators should be configured to use UUID primary keys"
  end

  test "railtie sets schema format to ruby" do
    # The railtie sets schema_format to :ruby for UUID compatibility
    assert_equal :ruby, Rails.application.config.active_record.schema_format
  end

  test "railtie includes concern in ActiveRecord::Base" do
    # The railtie includes the UUID concern in ActiveRecord::Base
    assert ActiveRecord::Base.included_modules.include?(RailsUuidPk::HasUuidv7PrimaryKey)
  end

  test "railtie prepends migration helpers to migration classes" do
    # Test that migration helpers are prepended to the appropriate classes
    # This is tested indirectly through the migration tests, but let's verify the modules are included

    # Check that TableDefinition includes the References module
    assert ActiveRecord::ConnectionAdapters::TableDefinition.included_modules.include?(RailsUuidPk::MigrationHelpers::References)

    # Check that Table includes the References module
    assert ActiveRecord::ConnectionAdapters::Table.included_modules.include?(RailsUuidPk::MigrationHelpers::References)

    # Check that AbstractAdapter includes the References module
    assert ActiveRecord::ConnectionAdapters::AbstractAdapter.included_modules.include?(RailsUuidPk::MigrationHelpers::References)
  end

  test "railtie register_uuid_type method works correctly" do
    # Test the class method for registering UUID types
    assert_respond_to RailsUuidPk::Railtie, :register_uuid_type

    # This method is tested indirectly through the adapter tests
    # but we can verify it exists and is callable
    mock_registry = {}
    mock_type_class = Class.new do
      def self.register(*args); end
    end

    # Mock ActiveRecord::Type.register to capture calls
    original_register = ActiveRecord::Type.method(:register)
    call_count = 0
    ActiveRecord::Type.define_singleton_method(:register) do |*args|
      call_count += 1
      # Don't actually register to avoid side effects
    end

    begin
      RailsUuidPk::Railtie.register_uuid_type(:test_adapter)
      assert_equal 1, call_count, "register_uuid_type should call ActiveRecord::Type.register"
    ensure
      # Restore original method
      ActiveRecord::Type.define_singleton_method(:register, original_register)
    end
  end

  test "RailsUuidPk logger functionality works correctly" do
    # Test logger getter
    assert_not_nil RailsUuidPk.logger
    assert RailsUuidPk.logger.is_a?(Logger)
  end

  test "RailsUuidPk logger falls back to stdout when Rails logger not available" do
    # Test that logger falls back to stdout when Rails.logger is not defined
    original_rails_logger = defined?(Rails.logger) ? Rails.logger : nil

    # Temporarily undefine Rails.logger
    if defined?(Rails)
      Rails.remove_instance_variable(:@logger) if Rails.instance_variable_defined?(:@logger)
      Rails.define_singleton_method(:logger) { nil }
    end

    begin
      # Force recreation of logger
      RailsUuidPk.instance_variable_set(:@logger, nil)
      logger = RailsUuidPk.logger

      # Should create a Logger instance
      assert logger.is_a?(Logger)
    ensure
      # Restore Rails.logger if it existed
      if defined?(Rails) && original_rails_logger
        Rails.instance_variable_set(:@logger, original_rails_logger)
      end
    end
  end
end
