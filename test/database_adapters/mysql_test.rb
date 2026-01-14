require "test_helper"

class MysqlAdapterTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "UUID type mapping for MySQL" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # MySQL stores UUIDs as VARCHAR(36)
    uuid_type = ActiveRecord::Base.connection.send(:type_map).lookup("uuid")
    assert_equal :uuid, uuid_type.type
  end

  test "MySQL native database types include UUID mapping" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Check that the adapter extension is properly loaded
    native_types = ActiveRecord::Base.connection.native_database_types
    assert native_types.key?(:uuid), "MySQL adapter should include UUID in native types"
    assert_equal({ name: "varchar", limit: 36 }, native_types[:uuid])
  end

  test "MySQL VARCHAR type is mapped to custom UUID type" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test that VARCHAR columns are properly mapped to our UUID type
    varchar_type = ActiveRecord::Base.connection.send(:type_map).lookup("varchar(36)")
    assert_equal :uuid, varchar_type.type
  end

  test "MySQL create_table with id: :uuid creates VARCHAR(36) column" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test that create_table with id: :uuid creates proper VARCHAR(36) column in MySQL

    # Use proper migration testing pattern instead of eval
    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_mysql_uuid_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    migration.migrate(:up)

    # Check that the created table has VARCHAR(36) primary key column
    columns = ActiveRecord::Base.connection.columns(:test_mysql_uuid_models)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase, "MySQL UUID primary key should be VARCHAR(36)"
    assert_equal :uuid, id_column.type, "UUID column should be mapped to :uuid type"

    # Clean up
    migration.migrate(:down)
  end

  test "MySQL migration helpers detect VARCHAR(36) UUID primary keys" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Create a table with VARCHAR(36) UUID primary key

    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mysql_uuid_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    migration.migrate(:up)

    # Create a table that references the MySQL UUID table
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mysql_referencing_models do |t|
          t.references :mysql_uuid_parent_model, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with VARCHAR(36) type
    columns = ActiveRecord::Base.connection.columns(:mysql_referencing_models)
    fk_column = columns.find { |c| c.name == "mysql_uuid_parent_model_id" }
    assert_equal "varchar(36)", fk_column.sql_type.downcase, "Foreign key to MySQL UUID table should be VARCHAR(36)"
    assert_equal :uuid, fk_column.type, "Foreign key should be mapped to :uuid type"

    # Clean up
    ref_migration.migrate(:down)
    migration.migrate(:down)
  end

  test "MySQL polymorphic references with UUID parents" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Create a parent table with UUID primary key

    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mysql_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a polymorphic table that references the MySQL UUID parent
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mysql_polymorphic_models do |t|
          t.string :name
          t.text :body
          t.references :record, null: false, polymorphic: true, index: false
          t.timestamps
        end
      end
    end

    poly_migration.migrate(:up)

    # Check that the polymorphic foreign key was created with VARCHAR(36) type
    columns = ActiveRecord::Base.connection.columns(:mysql_polymorphic_models)
    fk_column = columns.find { |c| c.name == "record_id" }
    assert_equal "varchar(36)", fk_column.sql_type.downcase, "Polymorphic foreign key should be VARCHAR(36) when UUID parents exist"
    assert_equal :uuid, fk_column.type, "Polymorphic foreign key should be mapped to :uuid type"

    # Clean up
    poly_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "MySQL UUID generation and storage" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test that UUIDs are properly generated and stored in MySQL
    user = User.create!(name: "MySQL User")
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, user.id)

    # Verify the UUID is actually stored and retrievable
    found_user = User.find(user.id)
    assert_equal user.id, found_user.id
    assert_equal "MySQL User", found_user.name
  end

  test "MySQL schema dumping with UUID types" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test that schema dumping works correctly with MySQL UUID columns

    schema_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_mysql_schema_models, id: :uuid do |t|
          t.string :name
          t.references :parent, type: :uuid
        end
      end
    end

    schema_migration.migrate(:up)

    # Test schema dumping (this should not raise errors)
    schema_content = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, schema_content)
    schema_string = schema_content.string

    # Should contain the table definition
    assert_match(/create_table "test_mysql_schema_models"/, schema_string)
    # Should properly handle UUID columns (they appear as string in schema due to our type override)
    assert_match(/t\.string "id"/, schema_string)

    # Clean up
    schema_migration.migrate(:down)
  end

  test "MySQL UUID performance - bulk insertion" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test performance with bulk UUID insertions
    start_time = Time.now

    # Create 100 records with UUID primary keys
    users = []
    100.times do |i|
      users << User.new(name: "Bulk User #{i}")
    end

    User.insert_all!(users.map { |u| { name: u.name } })

    end_time = Time.now
    duration = end_time - start_time

    # Should complete within reasonable time (less than 1 second for 100 records)
    assert duration < 1.0, "Bulk insertion should complete within 1 second, took #{duration}s"

    # Verify all records were created with valid UUIDs
    created_users = User.where("name LIKE ?", "Bulk User%").order(:name)
    assert_equal 100, created_users.count

    created_users.each do |user|
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, user.id)
    end
  end

  test "MySQL UUID edge case - very long table names" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test with a very long table name to ensure no issues
    long_table_name = "very_long_table_name_that_exceeds_normal_limits_and_tests_edge_cases_in_mysql_compatibility"

    long_name_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table long_table_name.to_sym, id: :uuid do |t|
          t.string :name
        end
      end
    end

    long_name_migration.migrate(:up)

    # Verify the table was created and has UUID primary key
    columns = ActiveRecord::Base.connection.columns(long_table_name.to_sym)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase
    assert_equal :uuid, id_column.type

    # Clean up
    long_name_migration.migrate(:down)
  end

  test "MySQL UUID edge case - special characters in table names" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test with underscores and numbers in table names
    special_table_name = "test_table_123_with_numbers"

    special_name_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table special_table_name.to_sym, id: :uuid do |t|
          t.string :name
        end
      end
    end

    special_name_migration.migrate(:up)

    # Verify the table was created correctly
    columns = ActiveRecord::Base.connection.columns(special_table_name.to_sym)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase
    assert_equal :uuid, id_column.type

    # Clean up
    special_name_migration.migrate(:down)
  end

  test "MySQL UUID concurrent access simulation" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Simulate concurrent access by creating multiple connections/transactions
    threads = []
    uuids = []
    errors = []

    # Create 10 threads, each creating a user
    10.times do |i|
      threads << Thread.new do
        begin
          user = User.create!(name: "Concurrent User #{i}")
          uuids << user.id
        rescue => e
          errors << e
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    # Should have no errors
    assert_empty errors, "Concurrent UUID creation should not produce errors: #{errors.join(', ')}"

    # Should have created 10 unique UUIDs
    assert_equal 10, uuids.uniq.count, "All UUIDs should be unique"

    # All UUIDs should be valid UUIDv7
    uuids.each do |uuid|
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, uuid)
    end

    # Verify records exist in database
    created_users = User.where("name LIKE ?", "Concurrent User%")
    assert_equal 10, created_users.count
  end

  test "MySQL UUID memory efficiency - large dataset" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test memory efficiency with larger dataset
    initial_memory = `ps -o rss= -p #{Process.pid}`.to_i

    # Create 1000 records
    users_data = []
    1000.times do |i|
      users_data << { name: "Memory Test User #{i}" }
    end

    User.insert_all!(users_data)

    # Check memory usage after insertion
    final_memory = `ps -o rss= -p #{Process.pid}`.to_i
    memory_increase = final_memory - initial_memory

    # Memory increase should be reasonable (less than 50MB)
    assert memory_increase < 50_000, "Memory increase should be less than 50MB, was #{memory_increase}KB"

    # Verify all records were created
    count = User.where("name LIKE ?", "Memory Test User%").count
    assert_equal 1000, count

    # Clean up created records
    User.where("name LIKE ?", "Memory Test User%").delete_all
  end

  test "MySQL adapter handles VARCHAR(36) to UUID mapping" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

    # Test that VARCHAR(36) columns are properly mapped to our UUID type
    varchar_mapping_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :varchar36_test_models do |t|
          t.column :uuid_field, "VARCHAR(36)"
          t.string :name
        end
      end
    end

    varchar_mapping_migration.migrate(:up)

    columns = ActiveRecord::Base.connection.columns(:varchar36_test_models)
    uuid_column = columns.find { |c| c.name == "uuid_field" }
    assert_equal :uuid, uuid_column.type, "VARCHAR(36) should be mapped to UUID type in MySQL"

    # Clean up
    varchar_mapping_migration.migrate(:down)
  end

  test "MySQL adapter native types include UUID mapping" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

    # Check that the native_database_types includes our UUID mapping
    native_types = ActiveRecord::Base.connection.native_database_types
    assert native_types.key?(:uuid), "MySQL adapter should include UUID in native types"
    assert_equal({ name: "varchar", limit: 36 }, native_types[:uuid])
  end

  # Additional tests to cover missing methods in MySQL adapter extension

  test "MySQL adapter initialize_type_map calls register_uuid_types" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

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

  test "MySQL adapter configure_connection calls register_uuid_types" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

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

  test "MySQL register_uuid_types adds type mappings to type map" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"

    adapter = ActiveRecord::Base.connection
    type_map = adapter.send(:type_map)

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
end
