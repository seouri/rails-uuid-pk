require "test_helper"

class PostgresqlAdapterTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "UUID type mapping for PostgreSQL" do
    skip "PostgreSQL not available" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    # PostgreSQL has native UUID support
    uuid_type = ActiveRecord::Base.connection.send(:type_map).lookup("uuid")
    assert_equal :uuid, uuid_type.type
  end

  test "schema format remains default for PostgreSQL" do
    skip "Only runs on PostgreSQL" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    # Should be default :ruby for PostgreSQL
    assert_equal :ruby, Rails.application.config.active_record.schema_format
  end
end
