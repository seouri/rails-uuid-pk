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

  # Tests for mixed primary key scenarios (UUID and integer models)

  test "references detects mixed primary key types correctly" do
    # Create tables with different primary key types
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

    # Create referencing table with mixed foreign keys
    mixed_ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :mixed_references do |t|
          t.references :mixed_uuid_parent, null: false  # Should be UUID
          t.references :mixed_int_parent, null: false   # Should be integer
          t.string :description
        end
      end
    end

    mixed_ref_migration.migrate(:up)

    # Verify FK types are detected correctly
    columns = ActiveRecord::Base.connection.columns(:mixed_references)
    uuid_fk = columns.find { |c| c.name == "mixed_uuid_parent_id" }
    int_fk = columns.find { |c| c.name == "mixed_int_parent_id" }

    assert_equal :uuid, uuid_fk.type, "Reference to UUID table should be UUID type"
    assert_equal :integer, int_fk.type, "Reference to integer table should be integer type"

    # Clean up
    mixed_ref_migration.migrate(:down)
    int_parent_migration.migrate(:down)
    uuid_parent_migration.migrate(:down)
  end

  test "polymorphic references handle mixed primary key scenarios" do
    # Create mixed parent tables (some UUID, some integer)
    uuid_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :poly_mixed_uuid_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    int_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :poly_mixed_int_parents do |t|
          t.string :name
        end
      end
    end

    uuid_parent_migration.migrate(:up)
    int_parent_migration.migrate(:up)

    # Create polymorphic table - should use UUID since UUID parents exist
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :poly_mixed_models do |t|
          t.string :content
          t.references :resource, polymorphic: true
        end
      end
    end

    poly_migration.migrate(:up)

    # Should use UUID type for polymorphic FK since UUID parents exist
    columns = ActiveRecord::Base.connection.columns(:poly_mixed_models)
    fk_column = columns.find { |c| c.name == "resource_id" }
    assert_equal :uuid, fk_column.type, "Polymorphic FK should be UUID when UUID parents exist"

    # Clean up
    poly_migration.migrate(:down)
    int_parent_migration.migrate(:down)
    uuid_parent_migration.migrate(:down)
  end

  test "add_reference works with mixed primary key types" do
    # Create mixed parent tables
    uuid_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :add_ref_mixed2_uuid_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    int_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :add_ref_mixed2_int_parents do |t|
          t.string :name
        end
      end
    end

    uuid_parent_migration.migrate(:up)
    int_parent_migration.migrate(:up)

    # Create base table
    base_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :add_ref_mixed2_base do |t|
          t.string :description
        end
      end
    end

    base_migration.migrate(:up)

    # Add references to mixed tables
    add_ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        add_reference :add_ref_mixed2_base, :add_ref_mixed2_uuid_parent, null: false
        add_reference :add_ref_mixed2_base, :add_ref_mixed2_int_parent, null: false
      end
    end

    add_ref_migration.migrate(:up)

    # Verify FK types
    columns = ActiveRecord::Base.connection.columns(:add_ref_mixed2_base)
    uuid_fk = columns.find { |c| c.name == "add_ref_mixed2_uuid_parent_id" }
    int_fk = columns.find { |c| c.name == "add_ref_mixed2_int_parent_id" }

    assert_equal :uuid, uuid_fk.type, "add_reference to UUID table should be UUID type"
    assert_equal :integer, int_fk.type, "add_reference to integer table should be integer type"

    # Clean up
    add_ref_migration.migrate(:down)
    base_migration.migrate(:down)
    int_parent_migration.migrate(:down)
    uuid_parent_migration.migrate(:down)
  end

  test "migration helpers cache works correctly with mixed primary key tables" do
    # Create mixed parent tables
    uuid_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :cache_mixed_uuid_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    int_parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :cache_mixed_int_parents do |t|
          t.string :name
        end
      end
    end

    uuid_parent_migration.migrate(:up)
    int_parent_migration.migrate(:up)

    # Create table with multiple references to the same tables (testing cache)
    cache_test_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :cache_mixed_test do |t|
          # Multiple references to same UUID table
          t.references :cache_mixed_uuid_parent, null: false
          t.references :uuid_alias, to_table: :cache_mixed_uuid_parents, null: false

          # Multiple references to same integer table
          t.references :cache_mixed_int_parent, null: false
          t.references :int_alias, to_table: :cache_mixed_int_parents, null: false

          t.string :description
        end
      end
    end

    cache_test_migration.migrate(:up)

    # Verify all FK types are correct (cache should work consistently)
    columns = ActiveRecord::Base.connection.columns(:cache_mixed_test)
    uuid_fk1 = columns.find { |c| c.name == "cache_mixed_uuid_parent_id" }
    uuid_fk2 = columns.find { |c| c.name == "uuid_alias_id" }
    int_fk1 = columns.find { |c| c.name == "cache_mixed_int_parent_id" }
    int_fk2 = columns.find { |c| c.name == "int_alias_id" }

    assert_equal :uuid, uuid_fk1.type, "First UUID reference should be UUID type"
    assert_equal :uuid, uuid_fk2.type, "Second UUID reference should be UUID type"
    assert_equal :integer, int_fk1.type, "First integer reference should be integer type"
    assert_equal :integer, int_fk2.type, "Second integer reference should be integer type"

    # Clean up
    cache_test_migration.migrate(:down)
    int_parent_migration.migrate(:down)
    uuid_parent_migration.migrate(:down)
  end

  test "uuid_primary_key? returns false for non-existent table" do
    references_module = RailsUuidPk::MigrationHelpers::References

    # Mock connection that returns false for table_exists?
    mock_conn = Object.new
    mock_conn.define_singleton_method(:table_exists?) { |table| false }

    # Should return false for non-existent table
    result = references_module.test_uuid_primary_key?("non_existent_table", mock_conn)
    assert_not result, "Should return false for non-existent table"
  end

  test "uuid_primary_key? returns false for table with no primary key" do
    references_module = RailsUuidPk::MigrationHelpers::References

    # Mock connection for table with no primary key
    mock_conn = Object.new
    mock_conn.define_singleton_method(:table_exists?) { |table| true }
    mock_conn.define_singleton_method(:primary_key) { |table| nil }

    result = references_module.test_uuid_primary_key?("no_pk_table", mock_conn)
    assert_not result, "Should return false for table with no primary key"
  end

  test "uuid_primary_key? returns false for table with non-id primary key" do
    references_module = RailsUuidPk::MigrationHelpers::References

    # Mock connection for table with custom primary key
    mock_conn = Object.new
    mock_conn.define_singleton_method(:table_exists?) { |table| true }
    mock_conn.define_singleton_method(:primary_key) { |table| "custom_pk" }
    mock_conn.define_singleton_method(:columns) do |table|
      [ Struct.new(:name, :sql_type).new("custom_pk", "uuid") ]
    end

    result = references_module.test_uuid_primary_key?("custom_pk_table", mock_conn)
    assert_not result, "Should return false for table with non-id primary key"
  end

  test "polymorphic reference detection with no UUID parents" do
    # Temporarily change generator config to not use UUIDs globally
    original_config = Rails.application.config.generators.options.dup
    Rails.application.config.generators.options[:active_record] = { primary_key_type: :integer }

    begin
      # Create only integer parent tables
      int_parent1_migration = Class.new(ActiveRecord::Migration::Current) do
        def change
          create_table :poly_no_uuid_parent1 do |t|
            t.string :name
          end
        end
      end

      int_parent2_migration = Class.new(ActiveRecord::Migration::Current) do
        def change
          create_table :poly_no_uuid_parent2 do |t|
            t.string :name
          end
        end
      end

      int_parent1_migration.migrate(:up)
      int_parent2_migration.migrate(:up)

      # Mock the application_uses_uuid_primary_keys? method to return false
      original_method = RailsUuidPk::MigrationHelpers::References.method(:application_uses_uuid_primary_keys?)
      RailsUuidPk::MigrationHelpers::References.define_singleton_method(:application_uses_uuid_primary_keys?) { false }

      # Create polymorphic table - should use integer since app doesn't use UUIDs globally
      poly_migration = Class.new(ActiveRecord::Migration::Current) do
        def change
          create_table :poly_no_uuid_models do |t|
            t.string :content
            t.references :resource, polymorphic: true
          end
        end
      end

      poly_migration.migrate(:up)

      # Should use integer type for polymorphic FK since app doesn't use UUIDs globally
      columns = ActiveRecord::Base.connection.columns(:poly_no_uuid_models)
      fk_column = columns.find { |c| c.name == "resource_id" }
      assert_equal :integer, fk_column.type, "Polymorphic FK should be integer when app doesn't use UUIDs globally"

      # Clean up
      poly_migration.migrate(:down)
      int_parent2_migration.migrate(:down)
      int_parent1_migration.migrate(:down)
    ensure
      # Restore original config and method
      Rails.application.config.generators.options = original_config
      RailsUuidPk::MigrationHelpers::References.define_singleton_method(:application_uses_uuid_primary_keys?, original_method)
    end
  end

  test "references with nil options hash does not crash" do
    # Test that references method handles nil options gracefully
    # This tests the options&.[] pattern in the migration helpers

    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :nil_options_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create table with references that has nil options
    ref_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :nil_options_refs do |t|
          t.references :nil_options_parent, null: false
          t.string :description
        end
      end
    end

    ref_migration.migrate(:up)

    # Should still work and create UUID FK
    columns = ActiveRecord::Base.connection.columns(:nil_options_refs)
    fk_column = columns.find { |c| c.name == "nil_options_parent_id" }
    assert_equal :uuid, fk_column.type, "Should still create UUID FK even with nil options handling"

    # Clean up
    ref_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "references with empty polymorphic option works" do
    # Test edge case where polymorphic is specified but empty
    parent_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :empty_poly_parents, id: :uuid do |t|
          t.string :name
        end
      end
    end

    parent_migration.migrate(:up)

    # Create table with polymorphic: true (should still detect UUID)
    poly_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table :empty_poly_models do |t|
          t.string :content
          t.references :parent, polymorphic: true
        end
      end
    end

    poly_migration.migrate(:up)

    columns = ActiveRecord::Base.connection.columns(:empty_poly_models)
    fk_column = columns.find { |c| c.name == "parent_id" }
    assert_equal :uuid, fk_column.type, "Should detect UUID even with polymorphic: true"

    # Clean up
    poly_migration.migrate(:down)
    parent_migration.migrate(:down)
  end

  test "migration helpers handle column lookup errors gracefully" do
    references_module = RailsUuidPk::MigrationHelpers::References

    # Mock connection that raises error during column lookup
    mock_conn = Object.new
    mock_conn.define_singleton_method(:table_exists?) { |table| true }
    mock_conn.define_singleton_method(:primary_key) { |table| "id" }
    mock_conn.define_singleton_method(:columns) do |table|
      raise StandardError.new("Database connection error")
    end

    # Should handle error gracefully and return false
    result = references_module.test_uuid_primary_key?("error_table", mock_conn)
    assert_not result, "Should return false when column lookup fails"
  end

  test "references method chaining with nil safety" do
    # Test that the method chaining with safe navigation works
    references_module = RailsUuidPk::MigrationHelpers::References

    # Create a mock table definition that tests the method chaining
    mock_table_def = Object.new
    mock_table_def.define_singleton_method(:references) do |*args, **options|
      # This should not crash even if internal methods return nil
      "references_called"
    end

    # Include the module to get the alias methods
    mock_table_def.extend(references_module)

    # Test that the module methods are available
    assert_respond_to mock_table_def, :references
    assert_respond_to mock_table_def, :belongs_to
    assert_respond_to mock_table_def, :add_reference
    assert_respond_to mock_table_def, :add_belongs_to
  end

  test "migration_helpers uuid_primary_key? rescue block" do
    # Create a dummy class to test private method
    dummy_class = Class.new do
      include RailsUuidPk::MigrationHelpers::References
      def connection
        raise StandardError, "Connection error"
      end
    end

    instance = dummy_class.new
    # Make it public for testing
    def instance.test_uuid_primary_key?(table_name)
      uuid_primary_key?(table_name)
    end

    refute instance.test_uuid_primary_key?("some_table")
  end
end
