require "test_helper"
require "rails/generators"
require "rails/generators/rails/model/model_generator"

class RailsUuidPkTest < ActiveSupport::TestCase
  def setup
    # Clean DB between tests
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "ar_internal_metadata" || table == "schema_migrations"
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end

  # UUID Generation Tests
  test "generates UUIDv7 primary key on create" do
    user = User.create!(name: "Alice")
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, user.id)
    # UUIDv7 should be roughly monotonic - check that the timestamp part is reasonable
    # The first 8 hex chars represent the high 32 bits of the 48-bit timestamp
    timestamp_high = user.id[0..7].to_i(16)
    # Should be a reasonable timestamp (not 0 and not in the far future)
    assert timestamp_high > 0
    assert timestamp_high < 0xFFFFFFFF
  end

  test "UUIDv7 primary keys are monotonic" do
    user1 = User.create!(name: "User1")
    sleep 0.001
    user2 = User.create!(name: "User2")
    sleep 0.001
    user3 = User.create!(name: "User3")

    # UUIDv7 should be monotonically increasing
    assert user1.id < user2.id, "UUIDv7 IDs should be in chronological order"
    assert user2.id < user3.id, "UUIDv7 IDs should be in chronological order"
  end

  test "works when id is manually set" do
    manual_uuid = SecureRandom.uuid_v7
    user = User.create!(id: manual_uuid, name: "Manual")
    assert_equal manual_uuid, user.id
  end

  test "does not assign UUID if id is already present" do
    # Even if id is set to something else, it shouldn't overwrite
    user = User.new(name: "Test", id: "some-other-id")
    user.save
    assert_equal "some-other-id", user.id
  end

  # UUIDv7 Correctness Tests
  test "UUIDv7 version and variant bits are correct (RFC 9562 compliance)" do
    user = User.create!(name: "RFC Test")
    uuid = user.id

    # UUIDv7 format: xxxxxxxx-xxxx-7xxx-8xxx-xxxxxxxxxxxx
    # Version bit (7) should be at position 12 (0-indexed)
    # Variant bits (8, 9, A, B) should be at positions 16-19

    # Extract version nibble (4 bits starting at position 12)
    version_nibble = uuid[14] # Position 14 is the version character
    assert_equal "7", version_nibble, "UUIDv7 version bit should be 7"

    # Extract variant nibbles (positions 19-21 in standard UUID format)
    # UUID format: 8-4-4-4-12, so variant starts at position 19
    variant_nibble = uuid[19]
    assert_match(/[89ab]/, variant_nibble, "UUIDv7 variant bits should be 8, 9, A, or B")
  end

  test "UUIDv7 timestamp monotonicity with high precision" do
    # Create UUIDs with minimal time gaps to test monotonicity
    uuids = []

    # Generate UUIDs with guaranteed time gaps
    5.times do |i|
      uuids << SecureRandom.uuid_v7
      sleep 0.01 # 10ms gap to ensure different timestamps
    end

    # Extract high-order timestamp bits from UUIDs and verify monotonicity
    timestamps = uuids.map do |uuid|
      # Use first 8 hex chars (32 bits) for timestamp comparison
      uuid[0..7].to_i(16)
    end

    # Verify timestamps are monotonically non-decreasing
    (1...timestamps.length).each do |i|
      assert timestamps[i] >= timestamps[i-1],
             "UUIDv7 timestamps should be monotonically non-decreasing: #{timestamps[i-1]} vs #{timestamps[i]}"
    end
  end

  test "UUIDv7 contains timestamp information" do
    # Test that UUIDv7 contains some form of timestamp information
    user = User.create!(name: "Timestamp Test")

    # Extract the first part of the UUID (should contain timestamp)
    # UUIDv7 format ensures the first segments contain time-based information
    first_segment = user.id[0..7]

    # Should be a valid hexadecimal string
    assert_match(/\A[0-9a-f]{8}\z/, first_segment, "First UUID segment should be valid hex")

    # Convert to integer and verify it's reasonable (not all zeros, not absurdly large)
    timestamp_component = first_segment.to_i(16)
    assert timestamp_component > 0, "UUID timestamp component should not be zero"
    assert timestamp_component < 2**32, "UUID timestamp component should fit in 32 bits"
  end

  test "UUIDv7 collision resistance" do
    # Generate a large number of UUIDs to test for collisions
    uuid_count = 10000
    uuids = []

    uuid_count.times do
      user = User.create!(name: "Collision Test #{SecureRandom.hex(4)}")
      uuids << user.id
    end

    # Verify all UUIDs are unique
    unique_uuids = uuids.uniq
    assert_equal uuid_count, unique_uuids.length,
                 "Generated #{uuid_count} UUIDs should all be unique"

    # Verify all follow UUIDv7 format
    uuids.each do |uuid|
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, uuid,
                   "All generated UUIDs should follow UUIDv7 format")
    end

    # Clean up test records
    User.where("name LIKE ?", "Collision Test %").delete_all
  end

  test "UUIDv7 format is consistently lowercase" do
    user = User.create!(name: "Format Test")

    # UUID should be lowercase by default (Rails standard)
    assert_match(/\A[0-9a-f]+\z/, user.id.gsub(/-/, ""),
                 "UUID should contain only lowercase hexadecimal characters")

    # Verify UUID follows standard format
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, user.id,
                 "UUID should follow standard lowercase hexadecimal format")
  end

  test "UUIDv7 edge cases and malformed UUID handling" do
    # Test various malformed UUID formats
    malformed_uuids = [
      "not-a-uuid",
      "12345678-1234-1234-1234-1234567890123", # Too long
      "12345678-1234-1234-1234-1234567890",    # Too short
      "gggggggg-gggg-gggg-gggg-gggggggggggg", # Invalid characters
      "12345678-1234-1234-1234-12345678901g",  # Invalid character at end
      "",                                       # Empty string
      nil                                       # Nil value
    ]

    malformed_uuids.each do |malformed_uuid|
      assert_raises(ActiveRecord::RecordNotFound) do
        User.find(malformed_uuid)
      end
    end

    # Test that valid UUIDv7 format is accepted
    valid_user = User.create!(name: "Valid UUID Test")
    found_user = User.find(valid_user.id)
    assert_equal valid_user.id, found_user.id,
                 "Should be able to find user with valid UUIDv7"
  end

  test "UUIDv7 randomness quality in different segments" do
    # Generate multiple UUIDs and analyze randomness distribution
    sample_size = 1000
    uuids = []

    sample_size.times do
      user = User.create!(name: "Randomness Test #{SecureRandom.hex(4)}")
      uuids << user.id
    end

    # Extract different segments of the UUID for randomness analysis
    # UUIDv7 format: timestamp (48 bits) + randomness (74 bits)
    # timestamp: first 12 hex chars (48 bits)
    # randomness: remaining 20 hex chars (80 bits)

    timestamp_segments = uuids.map { |uuid| uuid[0..11] }
    randomness_segments = uuids.map { |uuid| uuid[12..31] }

    # Verify we get some unique timestamp segments (not all identical)
    unique_timestamps = timestamp_segments.uniq.length
    assert unique_timestamps > 1,
           "Should have multiple unique timestamp segments (#{unique_timestamps}/#{sample_size})"

    # Verify randomness segments are highly unique
    unique_randomness = randomness_segments.uniq.length
    assert_equal sample_size, unique_randomness,
                 "Randomness segments should all be unique"

    # Clean up test records
    User.where("name LIKE ?", "Randomness Test %").delete_all
  end

  # Configuration Tests
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

  # Database Compatibility Tests - SQLite
  test "schema format remains default for SQLite" do
    if ActiveRecord::Base.connection.adapter_name == "SQLite"
      # Should use default :ruby format now that UUID schema dumping is supported
      assert_equal :ruby, Rails.application.config.active_record.schema_format
    end
  end

  test "UUID type mapping for SQLite" do
    if ActiveRecord::Base.connection.adapter_name == "SQLite"
      # The custom type should report as :uuid
      uuid_type = ActiveRecord::Base.connection.send(:type_map).lookup("uuid")
      assert_equal :uuid, uuid_type.type
    end
  end

  # Database Compatibility Tests - PostgreSQL
  test "UUID type mapping for PostgreSQL" do
    skip "PostgreSQL not available" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    # PostgreSQL has native UUID support
    uuid_type = ActiveRecord::Base.connection.send(:type_map).lookup("uuid")
    assert_equal :uuid, uuid_type.type
  end

  test "schema format remains default for non-SQLite adapters" do
    skip "Only runs for non-SQLite adapters" if ActiveRecord::Base.connection.adapter_name == "SQLite"
    # Should be default :ruby for other adapters like PostgreSQL
    assert_equal :ruby, Rails.application.config.active_record.schema_format
  end

  # Database Compatibility Tests - MySQL
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
    assert_equal({ name: "varchar", limit: 36 }, native_types[:uuid])
  end

  test "MySQL VARCHAR type is mapped to custom UUID type" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test that VARCHAR columns are properly mapped to our UUID type
    varchar_type = ActiveRecord::Base.connection.send(:type_map).lookup("varchar(36)")
    assert_equal :uuid, varchar_type.type
  end

  # MySQL Migration and Schema Tests
  test "MySQL create_table with id: :uuid creates VARCHAR(36) column" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test that create_table with id: :uuid creates proper VARCHAR(36) column in MySQL
    migration_content = <<~MIGRATION
      class TestMysqlUuidMigration < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :test_mysql_uuid_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(migration_content)
    TestMysqlUuidMigration.migrate(:up)

    # Check that the created table has VARCHAR(36) primary key column
    columns = ActiveRecord::Base.connection.columns(:test_mysql_uuid_models)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase, "MySQL UUID primary key should be VARCHAR(36)"
    assert_equal :uuid, id_column.type, "UUID column should be mapped to :uuid type"

    # Clean up
    TestMysqlUuidMigration.migrate(:down)
  end

  test "MySQL migration helpers detect VARCHAR(36) UUID primary keys" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Create a table with VARCHAR(36) UUID primary key
    create_mysql_uuid_table_migration = <<~MIGRATION
      class CreateMysqlUuidParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :mysql_uuid_parent_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_mysql_uuid_table_migration)
    CreateMysqlUuidParentTable.migrate(:up)

    # Create a table that references the MySQL UUID table
    create_mysql_reference_migration = <<~MIGRATION
      class CreateMysqlReferencingTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :mysql_referencing_models do |t|
            t.references :mysql_uuid_parent_model, null: false
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_mysql_reference_migration)
    CreateMysqlReferencingTable.migrate(:up)

    # Check that the foreign key column was created with VARCHAR(36) type
    columns = ActiveRecord::Base.connection.columns(:mysql_referencing_models)
    fk_column = columns.find { |c| c.name == "mysql_uuid_parent_model_id" }
    assert_equal "varchar(36)", fk_column.sql_type.downcase, "Foreign key to MySQL UUID table should be VARCHAR(36)"
    assert_equal :uuid, fk_column.type, "Foreign key should be mapped to :uuid type"

    # Clean up
    CreateMysqlReferencingTable.migrate(:down)
    CreateMysqlUuidParentTable.migrate(:down)
  end

  test "MySQL polymorphic references with UUID parents" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Create a parent table with UUID primary key
    create_mysql_parent_migration = <<~MIGRATION
      class CreateMysqlParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :mysql_parent_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_mysql_parent_migration)
    CreateMysqlParentTable.migrate(:up)

    # Create a polymorphic table that references the MySQL UUID parent
    create_mysql_polymorphic_migration = <<~MIGRATION
      class CreateMysqlPolymorphicTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :mysql_polymorphic_models do |t|
            t.string :name
            t.text :body
            t.references :record, null: false, polymorphic: true, index: false
            t.timestamps
          end
        end
      end
    MIGRATION

    eval(create_mysql_polymorphic_migration)
    CreateMysqlPolymorphicTable.migrate(:up)

    # Check that the polymorphic foreign key was created with VARCHAR(36) type
    columns = ActiveRecord::Base.connection.columns(:mysql_polymorphic_models)
    fk_column = columns.find { |c| c.name == "record_id" }
    assert_equal "varchar(36)", fk_column.sql_type.downcase, "Polymorphic foreign key should be VARCHAR(36) when UUID parents exist"
    assert_equal :uuid, fk_column.type, "Polymorphic foreign key should be mapped to :uuid type"

    # Clean up
    CreateMysqlPolymorphicTable.migrate(:down)
    CreateMysqlParentTable.migrate(:down)
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
    migration_content = <<~MIGRATION
      class TestMysqlSchemaDump < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :test_mysql_schema_models, id: :uuid do |t|
            t.string :name
            t.references :parent, type: :uuid
          end
        end
      end
    MIGRATION

    eval(migration_content)
    TestMysqlSchemaDump.migrate(:up)

    # Test schema dumping (this should not raise errors)
    schema_content = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, schema_content)
    schema_string = schema_content.string

    # Should contain the table definition
    assert_match(/create_table "test_mysql_schema_models"/, schema_string)
    # Should properly handle UUID columns (they appear as string in schema due to our type override)
    assert_match(/t\.string "id"/, schema_string)

    # Clean up
    TestMysqlSchemaDump.migrate(:down)
  end

  # MySQL Performance and Edge Case Tests
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

    migration_content = <<~MIGRATION
      class TestLongTableName < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :#{long_table_name}, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(migration_content)
    TestLongTableName.migrate(:up)

    # Verify the table was created and has UUID primary key
    columns = ActiveRecord::Base.connection.columns(long_table_name.to_sym)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase
    assert_equal :uuid, id_column.type

    # Clean up
    TestLongTableName.migrate(:down)
  end

  test "MySQL UUID edge case - special characters in table names" do
    skip "MySQL not available" unless ActiveRecord::Base.connection.adapter_name == "MySQL"
    # Test with underscores and numbers in table names
    special_table_name = "test_table_123_with_numbers"

    migration_content = <<~MIGRATION
      class TestSpecialTableName < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :#{special_table_name}, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(migration_content)
    TestSpecialTableName.migrate(:up)

    # Verify the table was created correctly
    columns = ActiveRecord::Base.connection.columns(special_table_name.to_sym)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal "varchar(36)", id_column.sql_type.downcase
    assert_equal :uuid, id_column.type

    # Clean up
    TestSpecialTableName.migrate(:down)
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



  test "create_table with id option uses uuid primary key" do
    # Test that create_table with id: :uuid creates uuid primary key
    migration_content = <<~MIGRATION
      class TestUuidMigration < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :test_uuid_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    # Evaluate the migration in the context of the dummy app
    eval(migration_content)

    # Run the migration
    TestUuidMigration.migrate(:up)

    # Check that the created table has uuid primary key
    columns = ActiveRecord::Base.connection.columns(:test_uuid_models)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal :uuid, id_column.type, "Migration with id: :uuid should create table with UUID primary key"

    # Clean up
    TestUuidMigration.migrate(:down)
  end



  # Migration Helpers Tests
  test "references automatically sets type: :uuid when referencing table with UUID primary key" do
    # First, create a table with UUID primary key
    create_uuid_table_migration = <<~MIGRATION
      class CreateUuidParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :uuid_parent_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_uuid_table_migration)
    CreateUuidParentTable.migrate(:up)

    # Now create a table that references the UUID table
    create_reference_migration = <<~MIGRATION
      class CreateReferencingTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :referencing_models do |t|
            t.references :uuid_parent_model, null: false
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_reference_migration)
    CreateReferencingTable.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:referencing_models)
    fk_column = columns.find { |c| c.name == "uuid_parent_model_id" }
    assert_equal :uuid, fk_column.type, "Foreign key should automatically be UUID type when referencing UUID primary key"

    # Clean up
    CreateReferencingTable.migrate(:down)
    CreateUuidParentTable.migrate(:down)
  end

  test "references does not set type when referencing table with non-UUID primary key" do
    # Create a table with default integer primary key
    create_int_table_migration = <<~MIGRATION
      class CreateIntParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :int_parent_models do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_int_table_migration)
    CreateIntParentTable.migrate(:up)

    # Create a table that references the integer table
    create_reference_migration = <<~MIGRATION
      class CreateReferencingIntTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :referencing_int_models do |t|
            t.references :int_parent_model, null: false
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_reference_migration)
    CreateReferencingIntTable.migrate(:up)

    # Check that the foreign key column was created with default type (should be bigint)
    columns = ActiveRecord::Base.connection.columns(:referencing_int_models)
    fk_column = columns.find { |c| c.name == "int_parent_model_id" }
    assert_equal :integer, fk_column.type, "Foreign key should not be UUID type when referencing integer primary key"

    # Clean up
    CreateReferencingIntTable.migrate(:down)
    CreateIntParentTable.migrate(:down)
  end

  # Action Text / Active Storage simulation test
  test "polymorphic references automatically set UUID type when parent models use UUID" do
    # Simulate Action Text scenario: create a parent table with UUID primary key
    create_parent_migration = <<~MIGRATION
      class CreateParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :parent_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_parent_migration)
    CreateParentTable.migrate(:up)

    # Create a polymorphic table that references the UUID parent (like Action Text does)
    create_polymorphic_migration = <<~MIGRATION
      class CreatePolymorphicTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :polymorphic_models do |t|
            t.string :name
            t.text :body
            t.references :record, null: false, polymorphic: true, index: false
            t.timestamps
          end
        end
      end
    MIGRATION

    eval(create_polymorphic_migration)
    CreatePolymorphicTable.migrate(:up)

    # Check that the polymorphic foreign key was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:polymorphic_models)
    fk_column = columns.find { |c| c.name == "record_id" }
    assert_equal :uuid, fk_column.type, "Polymorphic foreign key should automatically be UUID type when parent models use UUID primary keys"

    # Clean up
    CreatePolymorphicTable.migrate(:down)
    CreateParentTable.migrate(:down)
  end

  test "references respects explicitly set type option" do
    # Create a table with UUID primary key
    create_uuid_table_migration = <<~MIGRATION
      class CreateExplicitTypeParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :explicit_type_parent_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_uuid_table_migration)
    CreateExplicitTypeParentTable.migrate(:up)

    # Create a table that references the UUID table but explicitly sets type: :string
    create_reference_migration = <<~MIGRATION
      class CreateExplicitTypeReferencingTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :explicit_type_referencing_models do |t|
            t.references :explicit_type_parent_model, null: false, type: :text
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_reference_migration)
    CreateExplicitTypeReferencingTable.migrate(:up)

    # Check that the foreign key column was created with the explicitly set type, not UUID
    columns = ActiveRecord::Base.connection.columns(:explicit_type_referencing_models)
    fk_column = columns.find { |c| c.name == "explicit_type_parent_model_id" }
    assert_equal :text, fk_column.type, "Foreign key should respect explicitly set type option"

    # Clean up
    CreateExplicitTypeReferencingTable.migrate(:down)
    CreateExplicitTypeParentTable.migrate(:down)
  end

  test "references works with belongs_to alias" do
    # Create a table with UUID primary key
    create_uuid_table_migration = <<~MIGRATION
      class CreateBelongsToParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :belongs_to_parent_models, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_uuid_table_migration)
    CreateBelongsToParentTable.migrate(:up)

    # Create a table that uses belongs_to (aliased to references)
    create_reference_migration = <<~MIGRATION
      class CreateBelongsToReferencingTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :belongs_to_referencing_models do |t|
            t.belongs_to :belongs_to_parent_model, null: false
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_reference_migration)
    CreateBelongsToReferencingTable.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:belongs_to_referencing_models)
    fk_column = columns.find { |c| c.name == "belongs_to_parent_model_id" }
    assert_equal :uuid, fk_column.type, "belongs_to should automatically be UUID type when referencing UUID primary key"

    # Clean up
    CreateBelongsToReferencingTable.migrate(:down)
    CreateBelongsToParentTable.migrate(:down)
  end

  test "references with to_table option works correctly" do
    # Create a table with UUID primary key
    create_uuid_table_migration = <<~MIGRATION
      class CreateToTableParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :to_table_parents, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_uuid_table_migration)
    CreateToTableParentTable.migrate(:up)

    # Create a table that references using to_table option
    create_reference_migration = <<~MIGRATION
      class CreateToTableReferencingTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :to_table_referencing_models do |t|
            t.references :custom_reference, to_table: :to_table_parents, null: false
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_reference_migration)
    CreateToTableReferencingTable.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:to_table_referencing_models)
    fk_column = columns.find { |c| c.name == "custom_reference_id" }
    assert_equal :uuid, fk_column.type, "references with to_table should detect UUID primary key correctly"

    # Clean up
    CreateToTableReferencingTable.migrate(:down)
    CreateToTableParentTable.migrate(:down)
  end

  test "add_reference automatically sets type: :uuid when referencing table with UUID primary key" do
    # First, create a table with UUID primary key
    create_uuid_table_migration = <<~MIGRATION
      class CreateAddRefParentTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :add_ref_parents, id: :uuid do |t|
            t.string :name
          end
        end
      end
    MIGRATION

    eval(create_uuid_table_migration)
    CreateAddRefParentTable.migrate(:up)

    # Now create a table and THEN add a reference
    create_table_migration = <<~MIGRATION
      class CreateBaseTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :base_models do |t|
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_table_migration)
    CreateBaseTable.migrate(:up)

    add_ref_migration = <<~MIGRATION
      class AddRefToTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          add_reference :base_models, :add_ref_parent, null: false
        end
      end
    MIGRATION

    eval(add_ref_migration)
    AddRefToTable.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:base_models)
    fk_column = columns.find { |c| c.name == "add_ref_parent_id" }
    assert_equal :uuid, fk_column.type, "add_reference should automatically be UUID type when referencing UUID primary key"

    # Clean up
    AddRefToTable.migrate(:down)
    CreateBaseTable.migrate(:down)
    CreateAddRefParentTable.migrate(:down)
  end

  test "references does not set type when referenced table does not exist" do
    # Create a table that references a non-existent table
    create_reference_migration = <<~MIGRATION
      class CreateNonExistentReferencingTable < ActiveRecord::Migration[#{Rails::VERSION::STRING.to_f}]
        def change
          create_table :non_existent_referencing_models do |t|
            t.references :non_existent_table, null: false
            t.string :description
          end
        end
      end
    MIGRATION

    eval(create_reference_migration)
    CreateNonExistentReferencingTable.migrate(:up)

    # Check that the foreign key column was created with default type (not UUID)
    columns = ActiveRecord::Base.connection.columns(:non_existent_referencing_models)
    fk_column = columns.find { |c| c.name == "non_existent_table_id" }
    assert_equal :integer, fk_column.type, "Foreign key should not be UUID type when referenced table does not exist"

    # Clean up
    CreateNonExistentReferencingTable.migrate(:down)
  end
end
