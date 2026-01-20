require "test_helper"

class TrilogyAdapterTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "UUID type mapping for Trilogy" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Trilogy stores UUIDs as VARCHAR(36)
    uuid_type = ActiveRecord::Base.connection.send(:type_map).lookup("uuid")
    assert_equal :uuid, uuid_type.type
  end

  test "Trilogy native database types include UUID mapping" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Check that the adapter extension is properly loaded
    native_types = ActiveRecord::Base.connection.native_database_types
    assert native_types.key?(:uuid), "Trilogy adapter should include UUID in native types"
    assert_equal({ name: "varchar", limit: 36 }, native_types[:uuid])
  end

  test "Trilogy VARCHAR type is mapped to custom UUID type" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test that VARCHAR columns are properly mapped to our UUID type
    varchar_type = ActiveRecord::Base.connection.send(:type_map).lookup("varchar(36)")
    assert_equal :uuid, varchar_type.type
  end

  test "Trilogy create_table with id: :uuid creates VARCHAR(36) column" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test that create_table with id: :uuid creates proper VARCHAR(36) column in Trilogy

    # Use proper migration testing pattern instead of eval
    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_trilogy_uuid_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    migration.migrate(:up)

    # Check that the created table has VARCHAR(36) primary key column
    columns = ActiveRecord::Base.connection.columns(:test_trilogy_uuid_models)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase, "Trilogy UUID primary key should be VARCHAR(36)"
    assert_equal :uuid, id_column.type, "UUID column should be mapped to :uuid type"

    # Clean up
    migration.migrate(:down)
  end

  test "Trilogy migration helpers detect VARCHAR(36) UUID primary keys" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Create a table with VARCHAR(36) UUID primary key

    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :trilogy_uuid_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    migration.migrate(:up)

    # Create a table that references the Trilogy UUID table
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :trilogy_referencing_models do |t|
          t.references :trilogy_uuid_parent_model, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with VARCHAR(36) type
    columns = ActiveRecord::Base.connection.columns(:trilogy_referencing_models)
    fk_column = columns.find { |c| c.name == "trilogy_uuid_parent_model_id" }
    assert_equal "varchar(36)", fk_column.sql_type.downcase, "Foreign key to Trilogy UUID table should be VARCHAR(36)"
    assert_equal :uuid, fk_column.type, "Foreign key should be mapped to :uuid type"

    # Clean up
    ref_migration.migrate(:down)
    migration.migrate(:down)
  end

  test "Trilogy polymorphic references with UUID parents" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Create a parent table with UUID primary key

    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :trilogy_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a polymorphic table that references the Trilogy UUID parent
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :trilogy_polymorphic_models do |t|
          t.string :name
          t.text :body
          t.references :record, null: false, polymorphic: true, index: false
          t.timestamps
        end
      end
    end

    poly_migration.migrate(:up)

    # Check that the polymorphic foreign key was created with VARCHAR(36) type
    columns = ActiveRecord::Base.connection.columns(:trilogy_polymorphic_models)
    fk_column = columns.find { |c| c.name == "record_id" }
    assert_equal "varchar(36)", fk_column.sql_type.downcase, "Polymorphic foreign key should be VARCHAR(36) when UUID parents exist"
    assert_equal :uuid, fk_column.type, "Polymorphic foreign key should be mapped to :uuid type"

    # Clean up
    poly_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "Trilogy UUID generation and storage" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test that UUIDs are properly generated and stored in Trilogy
    user = User.create!(name: "Trilogy User")
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, user.id)

    # Verify the UUID is actually stored and retrievable
    found_user = User.find(user.id)
    assert_equal user.id, found_user.id
    assert_equal "Trilogy User", found_user.name
  end

  test "Trilogy schema dumping with UUID types" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test that schema dumping works correctly with Trilogy UUID columns

    schema_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_trilogy_schema_models, id: :uuid do |t|
          t.string :name
          t.uuid :other_id
        end
      end
    end

    schema_migration.migrate(:up)

    begin
      # Test schema dumping (this should not raise errors)
      schema_content = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, schema_content)
      schema_string = schema_content.string

      # Should contain the table definition
      assert_match(/create_table "test_trilogy_schema_models", id: :uuid/, schema_string)
      # Should properly handle UUID columns
      assert_match(/t\.uuid "other_id"/, schema_string)
    ensure
      # Clean up
      schema_migration.migrate(:down)
    end
  end

  test "Trilogy UUID performance - bulk insertion" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test performance with bulk UUID insertions
    start_time = Time.now

    # Create 100 records with UUID primary keys
    users = []
    100.times do |i|
      users << User.new(name: "Bulk Trilogy User #{i}")
    end

    User.insert_all!(users.map { |u| { name: u.name } })

    end_time = Time.now
    duration = end_time - start_time

    # Should complete within reasonable time (less than 1 second for 100 records)
    assert duration < 1.0, "Bulk insertion should complete within 1 second, took #{duration}s"

    # Verify all records were created with valid UUIDs
    created_users = User.where("name LIKE ?", "Bulk Trilogy User%").order(:name)
    assert_equal 100, created_users.count

    created_users.each do |user|
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, user.id)
    end
  end

  test "Trilogy UUID edge case - very long table names" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test with a very long table name to ensure no issues
    long_table_name = "very_long_table_name_that_exceeds_normal_limits_and_tests_edge_cases_in_trilogy_compatibility"

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

  test "Trilogy UUID edge case - special characters in table names" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
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

  test "Trilogy UUID concurrent access simulation" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Simulate concurrent access by creating multiple connections/transactions
    threads = []
    uuids = []
    errors = []

    # Create 10 threads, each creating a user
    10.times do |i|
      threads << Thread.new do
        begin
          user = User.create!(name: "Concurrent Trilogy User #{i}")
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
    created_users = User.where("name LIKE ?", "Concurrent Trilogy User%")
    assert_equal 10, created_users.count
  end

  test "Trilogy UUID memory efficiency - large dataset" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"
    # Test memory efficiency with larger dataset
    initial_memory = `ps -o rss= -p #{Process.pid}`.to_i

    # Create 1000 records
    users_data = []
    1000.times do |i|
      users_data << { name: "Trilogy Memory Test User #{i}" }
    end

    User.insert_all!(users_data)

    # Check memory usage after insertion
    final_memory = `ps -o rss= -p #{Process.pid}`.to_i
    memory_increase = final_memory - initial_memory

    # Memory increase should be reasonable (less than 50MB)
    assert memory_increase < 50_000, "Memory increase should be less than 50MB, was #{memory_increase}KB"

    # Verify all records were created
    count = User.where("name LIKE ?", "Trilogy Memory Test User%").count
    assert_equal 1000, count

    # Clean up created records
    User.where("name LIKE ?", "Trilogy Memory Test User%").delete_all
  end

  test "Trilogy adapter handles VARCHAR(36) to UUID mapping" do
    skip "Trilogy not available" unless ActiveRecord::Base.connection.adapter_name == "Trilogy"

    # Test that VARCHAR(36) columns are properly mapped to our UUID type
    varchar_mapping_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :varchar36_trilogy_test_models do |t|
          t.column :uuid_field, "VARCHAR(36)"
          t.string :name
        end
      end
    end

    varchar_mapping_migration.migrate(:up)

    columns = ActiveRecord::Base.connection.columns(:varchar36_trilogy_test_models)
    uuid_column = columns.find { |c| c.name == "uuid_field" }
    assert_equal :uuid, uuid_column.type, "VARCHAR(36) should be mapped to UUID type in Trilogy"

    # Clean up
    varchar_mapping_migration.migrate(:down)
  end

  test "trilogy adapter extension configure_connection" do
    parent_class = Class.new do
      def configure_connection; @super_called = true; end
      attr_reader :super_called
    end

    test_class = Class.new(parent_class) do
      include RailsUuidPk::TrilogyAdapterExtension
      def register_uuid_types; @register_called = true; end
      attr_reader :register_called
    end

    instance = test_class.new
    instance.configure_connection

    assert instance.super_called
    assert instance.register_called
  end
end
