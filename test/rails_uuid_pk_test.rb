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
