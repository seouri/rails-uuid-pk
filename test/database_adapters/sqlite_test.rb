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
