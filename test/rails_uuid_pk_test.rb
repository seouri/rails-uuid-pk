require "test_helper"
require "rails/generators"
require "rails/generators/rails/model/model_generator"
require "generators/rails_uuid_pk/install/install_generator"

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

  # Generator Integration Tests
  test "install generator copies concern file correctly" do
    # Use a temporary directory to avoid conflicts with existing files
    temp_dir = Rails.root.join("tmp", "test_generator")
    FileUtils.mkdir_p(temp_dir)

    begin
      # Test that the install generator copies the file to the right location
      generator = RailsUuidPk::Generators::InstallGenerator.new
      generator.destination_root = temp_dir
      generator.add_concern_file

      concern_path = temp_dir.join("app/models/concerns/has_uuidv7_primary_key.rb")
      assert File.exist?(concern_path), "Concern file should be copied by install generator"

      # Verify the content matches the template
      expected_content = File.read(File.join(generator.class.source_root, "has_uuidv7_primary_key.rb"))
      actual_content = File.read(concern_path)
      assert_equal expected_content, actual_content, "Concern file content should match template"
    ensure
      # Clean up
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    end
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

  test "install generator shows appropriate warnings and instructions" do
    generator = RailsUuidPk::Generators::InstallGenerator.new

    # Capture output
    output = StringIO.new
    $stdout = output

    begin
      generator.show_next_steps

      output_content = output.string
      assert_match(/rails-uuid-pk was successfully installed/, output_content)
      assert_match(/Action Text & Active Storage compatibility/, output_content)
      assert_match(/Migration helpers now automatically handle foreign key types/, output_content)
      assert_match(/rails g model User name:string/, output_content)
    ensure
      $stdout = STDOUT
    end
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
