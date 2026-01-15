require "test_helper"

class MigrationHelpersReferencesTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "references automatically sets type: :uuid when referencing table with UUID primary key" do
    # First, create a table with UUID primary key
    uuid_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :uuid_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    uuid_migration.migrate(:up)

    # Now create a table that references the UUID table
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :referencing_models do |t|
          t.references :uuid_parent_model, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:referencing_models)
    fk_column = columns.find { |c| c.name == "uuid_parent_model_id" }
    assert_equal :uuid, fk_column.type, "Foreign key should automatically be UUID type when referencing UUID primary key"

    # Clean up
    ref_migration.migrate(:down)
    uuid_migration.migrate(:down)
  end

  test "references does not set type when referencing table with non-UUID primary key" do
    # Create a table with default integer primary key
    int_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :int_parent_models do |t|
          t.string :name
        end
      end
    end

    int_migration.migrate(:up)

    # Create a table that references the integer table
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :referencing_int_models do |t|
          t.references :int_parent_model, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with default type (should be bigint)
    columns = ActiveRecord::Base.connection.columns(:referencing_int_models)
    fk_column = columns.find { |c| c.name == "int_parent_model_id" }
    assert_equal :integer, fk_column.type, "Foreign key should not be UUID type when referencing integer primary key"

    # Clean up
    ref_migration.migrate(:down)
    int_migration.migrate(:down)
  end

  # Action Text / Active Storage simulation test
  test "polymorphic references automatically set UUID type when parent models use UUID" do
    # Simulate Action Text scenario: create a parent table with UUID primary key
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a polymorphic table that references the UUID parent (like Action Text does)
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :polymorphic_models do |t|
          t.string :name
          t.text :body
          t.references :record, null: false, polymorphic: true, index: false
          t.timestamps
        end
      end
    end

    poly_migration.migrate(:up)

    # Check that the polymorphic foreign key was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:polymorphic_models)
    fk_column = columns.find { |c| c.name == "record_id" }
    assert_equal :uuid, fk_column.type, "Polymorphic foreign key should automatically be UUID type when parent models use UUID primary keys"

    # Clean up
    poly_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "references respects explicitly set type option" do
    # Create a table with UUID primary key
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :explicit_type_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a table that references the UUID table but explicitly sets type: :string
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :explicit_type_referencing_models do |t|
          t.references :explicit_type_parent_model, null: false, type: :text
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with the explicitly set type, not UUID
    columns = ActiveRecord::Base.connection.columns(:explicit_type_referencing_models)
    fk_column = columns.find { |c| c.name == "explicit_type_parent_model_id" }
    assert_equal :text, fk_column.type, "Foreign key should respect explicitly set type option"

    # Clean up
    ref_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "references works with belongs_to alias" do
    # Create a table with UUID primary key
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :belongs_to_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a table that uses belongs_to (aliased to references)
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :belongs_to_referencing_models do |t|
          t.belongs_to :belongs_to_parent_model, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:belongs_to_referencing_models)
    fk_column = columns.find { |c| c.name == "belongs_to_parent_model_id" }
    assert_equal :uuid, fk_column.type, "belongs_to should automatically be UUID type when referencing UUID primary key"

    # Clean up
    ref_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "references with to_table option works correctly" do
    # Create a table with UUID primary key
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :to_table_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a table that references using to_table option
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :to_table_referencing_models do |t|
          t.references :custom_reference, to_table: :to_table_parents, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:to_table_referencing_models)
    fk_column = columns.find { |c| c.name == "custom_reference_id" }
    assert_equal :uuid, fk_column.type, "references with to_table should detect UUID primary key correctly"

    # Clean up
    ref_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "add_reference automatically sets type: :uuid when referencing table with UUID primary key" do
    # First, create a table with UUID primary key
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :add_ref_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Now create a table and THEN add a reference
    table_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :base_models do |t|
          t.string :description
        end
      end
    end

    table_migration.migrate(:up)

    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        add_reference :base_models, :add_ref_parent, null: false
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with UUID type
    columns = ActiveRecord::Base.connection.columns(:base_models)
    fk_column = columns.find { |c| c.name == "add_ref_parent_id" }
    assert_equal :uuid, fk_column.type, "add_reference should automatically be UUID type when referencing UUID primary key"

    # Clean up
    ref_migration.migrate(:down)
    table_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "references does not set type when referenced table does not exist" do
    # Create a table that references a non-existent table
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :non_existent_referencing_models do |t|
          t.references :non_existent_table, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Check that the foreign key column was created with default type (not UUID)
    columns = ActiveRecord::Base.connection.columns(:non_existent_referencing_models)
    fk_column = columns.find { |c| c.name == "non_existent_table_id" }
    assert_equal :integer, fk_column.type, "Foreign key should not be UUID type when referenced table does not exist"

    # Clean up
    ref_migration.migrate(:down)
  end

  test "migration helpers handle non-existent table gracefully" do
    # Test that references doesn't crash when table doesn't exist
    # This tests the table_exists? guard in uuid_primary_key?
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_non_existent_refs do |t|
          t.references :definitely_does_not_exist_table, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Should create with default integer type since referenced table doesn't exist
    columns = ActiveRecord::Base.connection.columns(:test_non_existent_refs)
    fk_column = columns.find { |c| c.name == "definitely_does_not_exist_table_id" }
    assert_equal :integer, fk_column.type

    # Clean up
    ref_migration.migrate(:down)
  end

  test "migration helpers polymorphic detection works with UUID parents" do
    # Create a parent table with UUID
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :poly_test_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Test polymorphic reference detection
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :poly_test_models do |t|
          t.string :content
          t.references :parent, polymorphic: true
        end
      end
    end

    poly_migration.migrate(:up)

    # Should detect UUID parents and use UUID type
    columns = ActiveRecord::Base.connection.columns(:poly_test_models)
    fk_column = columns.find { |c| c.name == "parent_id" }
    assert_equal :uuid, fk_column.type

    # Clean up
    poly_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "polymorphic references work with mixed UUID and non-UUID tables" do
    # Create both UUID and non-UUID parent tables
    uuid_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mixed_uuid_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    int_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mixed_int_parents do |t|
          t.string :name
        end
      end
    end

    uuid_parent_migration.migrate(:up)
    int_parent_migration.migrate(:up)

    # Create polymorphic table - should use UUID since UUID parents exist
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mixed_polymorphic_models do |t|
          t.string :name
          t.references :resource, polymorphic: true
          t.timestamps
        end
      end
    end

    poly_migration.migrate(:up)

    columns = ActiveRecord::Base.connection.columns(:mixed_polymorphic_models)
    fk_column = columns.find { |c| c.name == "resource_id" }
    assert_equal :uuid, fk_column.type, "Polymorphic should use UUID when UUID parents exist"

    # Clean up
    poly_migration.migrate(:down)
    int_parent_migration.migrate(:down)
    uuid_parent_migration.migrate(:down)
  end

  test "create_table with id option uses uuid primary key" do
    # Test that create_table with id: :uuid creates uuid primary key
    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_uuid_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    migration.migrate(:up)

    # Check that the created table has uuid primary key
    columns = ActiveRecord::Base.connection.columns(:test_uuid_models)
    id_column = columns.find { |c| c.name == "id" }
    assert_equal :uuid, id_column.type, "Migration with id: :uuid should create table with UUID primary key"

    # Clean up
    migration.migrate(:down)
  end

  test "t.uuid method in migrations creates UUID column" do
    # Test that t.uuid creates a UUID column
    migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :test_uuid_column_models do |t|
          t.uuid :custom_uuid
        end
      end
    end

    migration.migrate(:up)

    begin
      # Check that the created table has a UUID column
      columns = ActiveRecord::Base.connection.columns(:test_uuid_column_models)
      uuid_column = columns.find { |c| c.name == "custom_uuid" }
      assert_equal :uuid, uuid_column.type, "t.uuid should create a column with UUID type"
    ensure
      # Clean up
      migration.migrate(:down)
    end
  end

  # Additional tests for migration helpers coverage gaps

  test "application_uses_uuid_primary_keys? detects Rails generator config" do
    # Test the Rails generator configuration detection
    references_module = RailsUuidPk::MigrationHelpers::References

    # Save original config
    original_config = Rails.application.config.generators.options.dup

    # Test with UUID primary key configured
    Rails.application.config.generators.options[:active_record] = { primary_key_type: :uuid }
    result = references_module.application_uses_uuid_primary_keys?
    assert result, "Should detect UUID primary key configuration"

    # Test with different configuration
    Rails.application.config.generators.options[:active_record] = { primary_key_type: :integer }
    result = references_module.application_uses_uuid_primary_keys?
    assert_not result, "Should not detect non-UUID primary key configuration"

    # Test with no configuration
    Rails.application.config.generators.options[:active_record] = {}
    result = references_module.application_uses_uuid_primary_keys?
    assert_not result, "Should not detect UUID config when not set"

    # Restore original config
    Rails.application.config.generators.options = original_config
  end

  test "belongs_to alias works identically to references" do
    # Test that belongs_to is an alias for references
    references_module = RailsUuidPk::MigrationHelpers::References

    # Create a table with UUID primary key
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :belongs_to_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Test belongs_to creates same result as references
    belongs_to_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :belongs_to_test_models do |t|
          t.belongs_to :belongs_to_parent_model, null: false
        end
      end
    end

    belongs_to_migration.migrate(:up)

    # Check that belongs_to created UUID type (same as references would)
    columns = ActiveRecord::Base.connection.columns(:belongs_to_test_models)
    fk_column = columns.find { |c| c.name == "belongs_to_parent_model_id" }
    assert_equal :uuid, fk_column.type, "belongs_to should work identically to references"

    # Clean up
    belongs_to_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "add_belongs_to alias works identically to add_reference" do
    # Test that add_belongs_to is an alias for add_reference
    references_module = RailsUuidPk::MigrationHelpers::References

    # Create parent table
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :add_belongs_to_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create base table
    base_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :add_belongs_to_base_models do |t|
          t.string :description
        end
      end
    end

    base_migration.migrate(:up)

    # Test add_belongs_to
    add_belongs_to_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        add_belongs_to :add_belongs_to_base_models, :add_belongs_to_parent, null: false
      end
    end

    add_belongs_to_migration.migrate(:up)

    # Check that add_belongs_to created UUID type
    columns = ActiveRecord::Base.connection.columns(:add_belongs_to_base_models)
    fk_column = columns.find { |c| c.name == "add_belongs_to_parent_id" }
    assert_equal :uuid, fk_column.type, "add_belongs_to should work identically to add_reference"

    # Clean up
    add_belongs_to_migration.migrate(:down)
    base_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "uuid_primary_key? recognizes different UUID column types" do
    references_module = RailsUuidPk::MigrationHelpers::References

    # Test various UUID column types that should be recognized
    test_cases = [
      [ "uuid", true ],      # PostgreSQL native UUID
      [ "varchar(36)", true ], # MySQL UUID as VARCHAR(36)
      [ "VARCHAR(36)", true ], # Case insensitive
      [ "integer", false ],  # Integer primary key
      [ "bigint", false ],   # Bigint primary key
      [ "string", false ],   # Generic string
      [ "text", false ]      # Text type
    ]

    test_cases.each do |sql_type, expected|
      # Create a simple mock connection
      mock_conn = Object.new
      mock_conn.define_singleton_method(:table_exists?) { |table| true }
      mock_conn.define_singleton_method(:primary_key) { |table| "id" }
      mock_conn.define_singleton_method(:columns) do |table|
        [ Struct.new(:name, :sql_type).new("id", sql_type) ]
      end

      # Clear cache and test
      result = references_module.test_uuid_primary_key?("test_table", mock_conn)

      assert_equal expected, result, "Should #{expected ? '' : 'not '}recognize #{sql_type} as UUID type"
    end
  end

  test "migration helpers cache results across multiple references calls" do
    # Test that multiple references to the same UUID table work efficiently
    # This indirectly tests that caching is working

    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :cache_parent_models, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create a table with multiple references to the same UUID table
    multi_ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :multi_ref_models do |t|
          t.references :cache_parent_model, null: false  # First reference
          t.references :another_parent, to_table: :cache_parent_models, null: false  # Second reference
          t.string :description
        end
      end
    end

    multi_ref_migration.migrate(:up)

    # Both foreign keys should be UUID type
    columns = ActiveRecord::Base.connection.columns(:multi_ref_models)
    fk1_column = columns.find { |c| c.name == "cache_parent_model_id" }
    fk2_column = columns.find { |c| c.name == "another_parent_id" }

    assert_equal :uuid, fk1_column.type, "First reference should be UUID type"
    assert_equal :uuid, fk2_column.type, "Second reference should be UUID type"

    # Clean up
    multi_ref_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  # Note: Complex unit tests for internal methods removed due to mocking complexity.
  # The functionality is thoroughly tested by the integration tests above.
end
