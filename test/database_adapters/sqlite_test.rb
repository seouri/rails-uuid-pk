require "test_helper"

class SqliteAdapterTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "schema format remains default for SQLite" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    # Should use default :ruby format now that UUID schema dumping is supported
    assert_equal :ruby, Rails.application.config.active_record.schema_format
  end

  test "UUID type mapping for SQLite" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    # The custom type should report as :uuid
    uuid_type = ActiveRecord::Base.connection.send(:type_map).lookup("uuid")
    assert_equal :uuid, uuid_type.type
  end

  test "Standard string columns are not hijacked as UUID type" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    # Create a table with a standard string column (implicitly varchar/varchar(255))
    migration_content = <<~MIGRATION
      class TestStringColumn < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :test_string_models do |t|
            t.string :name
            t.string :email, limit: 100
          end
        end
      end
    MIGRATION

    eval(migration_content)
    TestStringColumn.migrate(:up)

    columns = ActiveRecord::Base.connection.columns(:test_string_models)

    name_column = columns.find { |c| c.name == "name" }
    assert_equal :string, name_column.type, "Standard string column should be :string type"
    assert_not_equal :uuid, name_column.type, "Standard string column should NOT be :uuid type"

    email_column = columns.find { |c| c.name == "email" }
    assert_equal :string, email_column.type, "VARCHAR(100) column should be :string type"

    # Clean up
    TestStringColumn.migrate(:down)
  end

  # Additional tests to cover missing methods in SQLite adapter extension

  test "SQLite adapter initialize_type_map calls register_uuid_types" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    # Test that initialize_type_map calls register_uuid_types
    # This is tested indirectly through normal operation, but let's verify the method exists and works
    adapter = ActiveRecord::Base.connection

    # Should respond to initialize_type_map
    assert_respond_to adapter, :initialize_type_map

    # Should respond to register_uuid_types
    assert_respond_to adapter, :register_uuid_types

    # Should respond to configure_connection
    assert_respond_to adapter, :configure_connection

    # Type map should have UUID registrations
    type_map = adapter.send(:type_map)
    assert_not_nil type_map

    # Should be able to lookup UUID types
    uuid_type = type_map.lookup("uuid")
    assert_not_nil uuid_type
    assert_equal :uuid, uuid_type.type
  end

  test "SQLite adapter configure_connection calls register_uuid_types" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    # Test that configure_connection calls register_uuid_types
    adapter = ActiveRecord::Base.connection

    # configure_connection should be callable without error
    assert_nothing_raised do
      adapter.configure_connection
    end

    # After configure_connection, type map should still have UUID types
    type_map = adapter.send(:type_map)
    uuid_type = type_map.lookup("uuid")
    assert_not_nil uuid_type
    assert_equal :uuid, uuid_type.type
  end

  test "SQLite native_database_types includes UUID mapping" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    adapter = ActiveRecord::Base.connection

    # Should have native_database_types method
    assert_respond_to adapter, :native_database_types

    types = adapter.native_database_types

    # Should include UUID mapping
    assert types.key?(:uuid), "SQLite adapter should include UUID in native types"
    assert_equal({ name: "varchar", limit: 36 }, types[:uuid])
  end

  test "SQLite register_uuid_types adds type mappings to type map" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    adapter = ActiveRecord::Base.connection
    type_map = adapter.send(:type_map)

    # Before explicit registration, types should already be registered via initialize_type_map
    # But let's test the method directly
    assert_respond_to adapter, :register_uuid_types

    # Call register_uuid_types again (should be idempotent)
    assert_nothing_raised do
      adapter.register_uuid_types(type_map)
    end

    # Verify UUID types are registered
    varchar36_type = type_map.lookup("varchar(36)")
    assert_not_nil varchar36_type
    assert_equal :uuid, varchar36_type.type

    uuid_type = type_map.lookup("uuid")
    assert_not_nil uuid_type
    assert_equal :uuid, uuid_type.type
  end

  test "SQLite adapter valid_type? recognized :uuid" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    assert ActiveRecord::Base.connection.valid_type?(:uuid)
  end

  test "SQLite adapter type_to_dump returns :uuid for UUID columns" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_sqlite_dump_models, id: :uuid do |t|
          t.uuid :other_uuid
        end
      end
    end

    migration.migrate(:up)

    begin
      columns = ActiveRecord::Base.connection.columns(:test_sqlite_dump_models)
      id_column = columns.find { |c| c.name == "id" }
      other_column = columns.find { |c| c.name == "other_uuid" }

      assert_equal [ :uuid, {} ], ActiveRecord::Base.connection.type_to_dump(id_column)
      assert_equal [ :uuid, {} ], ActiveRecord::Base.connection.type_to_dump(other_column)
    ensure
      migration.migrate(:down)
    end
  end

  test "SQLite schema dumping uses :uuid type" do
    skip "Only runs on SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"

    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_sqlite_schema_models, id: :uuid do |t|
          t.uuid :some_id
        end
      end
    end

    migration.migrate(:up)

    begin
      schema_content = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, schema_content)
      schema_string = schema_content.string

      assert_match(/create_table "test_sqlite_schema_models", id: :uuid/, schema_string)
      assert_match(/t\.uuid "some_id"/, schema_string)
    ensure
      migration.migrate(:down)
    end
  end
end
