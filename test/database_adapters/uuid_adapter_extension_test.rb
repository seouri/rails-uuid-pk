require "test_helper"

class UuidAdapterExtensionTest < ActiveSupport::TestCase
  # Test the shared UuidAdapterExtension module and its integration
  # This ensures the refactoring maintains functionality and proper integration

  test "UuidAdapterExtension module exists and defines required methods" do
    # Verify the module exists
    assert defined?(RailsUuidPk::UuidAdapterExtension)
    assert_kind_of Module, RailsUuidPk::UuidAdapterExtension

    # Verify the module defines the expected instance methods
    extension_methods = RailsUuidPk::UuidAdapterExtension.instance_methods(false)
    expected_methods = [ :native_database_types, :valid_type?, :register_uuid_types,
                       :initialize_type_map, :configure_connection, :type_to_dump ]

    expected_methods.each do |method|
      assert_includes extension_methods, method,
                     "UuidAdapterExtension should define #{method} method"
    end
  end

  test "UuidAdapterExtension is included in MySQL adapter" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

    adapter_class = ActiveRecord::Base.connection.class

    # Verify the adapter class includes the shared extension
    assert adapter_class.include?(RailsUuidPk::UuidAdapterExtension),
           "MySQL adapter should include UuidAdapterExtension"

    # Verify all extension methods are available
    adapter = ActiveRecord::Base.connection
    extension_methods = [ :native_database_types, :valid_type?, :register_uuid_types,
                        :initialize_type_map, :configure_connection, :type_to_dump ]

    extension_methods.each do |method|
      assert_respond_to adapter, method,
                       "MySQL adapter should respond to #{method} from UuidAdapterExtension"
    end
  end

  test "UuidAdapterExtension is included in SQLite adapter" do
    skip "SQLite not available" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    adapter_class = ActiveRecord::Base.connection.class

    # Verify the adapter class includes the shared extension
    assert adapter_class.include?(RailsUuidPk::UuidAdapterExtension),
           "SQLite adapter should include UuidAdapterExtension"

    # Verify all extension methods are available
    adapter = ActiveRecord::Base.connection
    extension_methods = [ :native_database_types, :valid_type?, :register_uuid_types,
                        :initialize_type_map, :configure_connection, :type_to_dump ]

    extension_methods.each do |method|
      assert_respond_to adapter, method,
                       "SQLite adapter should respond to #{method} from UuidAdapterExtension"
    end
  end

  test "UuidAdapterExtension maintains MySQL-specific behavior" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

    adapter = ActiveRecord::Base.connection

    # Test that MySQL adapter has UUID support
    assert adapter.valid_type?(:uuid), "MySQL adapter should recognize :uuid type"
    types = adapter.native_database_types
    assert_equal({ name: "varchar", limit: 36 }, types[:uuid])

    # Test type_to_dump functionality
    mock_column = Struct.new(:type).new(:uuid)
    result = adapter.type_to_dump(mock_column)
    assert_equal [ :uuid, {} ], result

    # Test that configure_connection works (MySQL version calls super)
    assert_nothing_raised do
      adapter.configure_connection
    end
  end

  test "UuidAdapterExtension maintains SQLite-specific behavior" do
    skip "SQLite not available" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    adapter = ActiveRecord::Base.connection

    # Test that SQLite adapter has UUID support
    assert adapter.valid_type?(:uuid), "SQLite adapter should recognize :uuid type"
    types = adapter.native_database_types
    assert_equal({ name: "varchar", limit: 36 }, types[:uuid])

    # Test type_to_dump functionality
    mock_column = Struct.new(:type).new(:uuid)
    result = adapter.type_to_dump(mock_column)
    assert_equal [ :uuid, {} ], result

    # Test that configure_connection works (SQLite version has transaction check)
    assert_nothing_raised do
      adapter.configure_connection
    end
  end

  test "UuidAdapterExtension preserves existing adapter functionality" do
    # This test ensures that the refactoring didn't break any existing functionality
    # by running a subset of the comprehensive adapter tests

    adapter = ActiveRecord::Base.connection

    # Test basic UUID functionality through the shared extension
    assert adapter.valid_type?(:uuid)

    # Test that we can call the extension methods without error
    assert_nothing_raised { adapter.register_uuid_types }
    assert_nothing_raised { adapter.configure_connection }

    # Test native types include UUID
    types = adapter.native_database_types
    assert types.key?(:uuid)
    assert_equal 36, types[:uuid][:limit]
  end

  test "UuidAdapterExtension integration doesn't break existing tests" do
    # This is a meta-test to ensure our refactoring doesn't break the existing
    # comprehensive test suite. Since the existing adapter tests are extensive,
    # we just verify that the basic integration works.

    adapter = ActiveRecord::Base.connection
    adapter_name = adapter.adapter_name

    # Ensure we're testing a supported adapter
    assert_includes [ "MySQL", "SQLite" ], adapter_name,
                   "Test should run on MySQL or SQLite adapters"

    # Basic smoke test that UUID functionality works
    assert adapter.valid_type?(:uuid), "#{adapter_name} should support UUID type"

    # Test that type mappings are properly registered
    types = adapter.native_database_types
    assert types.key?(:uuid), "#{adapter_name} should have UUID in native types"
  end

  test "uuid adapter extension type_to_dump" do
    mock_adapter = Object.new
    mock_adapter.extend(RailsUuidPk::UuidAdapterExtension)

    # Mock column
    column = Object.new
    def column.type; :uuid; end

    result = mock_adapter.type_to_dump(column)
    assert_equal [ :uuid, {} ], result

    # Test non-uuid column - it should call super
    # We need a class that has a super method
    parent_class = Class.new do
      def type_to_dump(column)
        [ :integer, {} ]
      end
    end

    test_class = Class.new(parent_class) do
      include RailsUuidPk::UuidAdapterExtension
    end

    instance = test_class.new
    integer_column = Object.new
    def integer_column.type; :integer; end

    assert_equal [ :integer, {} ], instance.type_to_dump(integer_column)
  end

  test "uuid adapter extension register_uuid_types" do
    mock_adapter = Object.new
    mock_adapter.extend(RailsUuidPk::UuidAdapterExtension)

    # Mock type map
    mock_type_map = Object.new
    mock_type_map.instance_variable_set(:@registered_patterns, [])

    def mock_type_map.register_type(pattern, &block)
      @registered_patterns << pattern
    end

    def mock_type_map.registered_patterns; @registered_patterns; end

    mock_adapter.register_uuid_types(mock_type_map)

    assert_includes mock_type_map.registered_patterns, /varchar\(36\)/i
    assert_includes mock_type_map.registered_patterns, "uuid"
  end
end
