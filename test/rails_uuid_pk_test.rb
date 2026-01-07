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
      assert_match(/t\.references :record.*type: :uuid/, output_content)
      assert_match(/rails g model User name:string/, output_content)
    ensure
      $stdout = STDOUT
    end
  end
end
