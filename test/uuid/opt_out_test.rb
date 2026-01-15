require "test_helper"

class UuidOptOutTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  test "use_integer_primary_key class method sets opt-out flag" do
    ActiveRecord::Base.connection.create_table :opt_out_flag_models, id: :integer, force: true do |t|
      t.string :name
    end

    klass = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_flag_models"
      use_integer_primary_key
    end

    assert klass.singleton_class.instance_variable_get(:@uses_integer_primary_key),
           "use_integer_primary_key should set @uses_integer_primary_key on singleton class to true"

    ActiveRecord::Base.connection.drop_table :opt_out_flag_models, if_exists: true
  end

  test "uses_uuid_primary_key? returns correct values for opted-in/out models" do
    ActiveRecord::Base.connection.create_table :opt_out_check_models, id: :integer, force: true do |t|
      t.string :name
    end

    integer_model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_check_models"
      use_integer_primary_key
    end

    uuid_model = Class.new(ApplicationRecord) do
      self.table_name = "users"
    end

    assert_not integer_model.uses_uuid_primary_key?,
               "Integer model should not use UUID primary keys"
    assert uuid_model.uses_uuid_primary_key?,
           "UUID model should use UUID primary keys by default"

    ActiveRecord::Base.connection.drop_table :opt_out_check_models, if_exists: true
  end

  test "UUID assignment callback is skipped for opted-out models" do
    ActiveRecord::Base.connection.create_table :opt_out_callback_models, id: :integer, force: true do |t|
      t.string :name
    end

    model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_callback_models"
      use_integer_primary_key
    end

    record = model.create!(name: "Integer Test")

    assert_kind_of Integer, record.id,
                   "Opted-out model should have integer primary key"
    assert record.id > 0,
           "Integer primary key should be auto-incrementing positive number"

    ActiveRecord::Base.connection.drop_table :opt_out_callback_models, if_exists: true
  end

  test "UUID assignment works normally for opted-in models" do
    ActiveRecord::Base.connection.create_table :opt_out_uuid_models, id: :uuid, force: true do |t|
      t.string :name
    end

    model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_uuid_models"
    end

    record = model.create!(name: "UUID Test")

    assert_valid_uuid7(record.id)

    ActiveRecord::Base.connection.drop_table :opt_out_uuid_models, if_exists: true
  end

  test "opt-out models use standard Rails integer primary key behavior" do
    ActiveRecord::Base.connection.create_table :opt_out_autoinc_models, id: :integer, force: true do |t|
      t.string :name
    end

    model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_autoinc_models"
      use_integer_primary_key
    end

    record1 = model.create!(name: "Record 1")
    record2 = model.create!(name: "Record 2")
    record3 = model.create!(name: "Record 3")

    assert record2.id == record1.id + 1,
           "Integer primary keys should auto-increment"
    assert record3.id == record2.id + 1,
           "Integer primary keys should auto-increment"

    ActiveRecord::Base.connection.drop_table :opt_out_autoinc_models, if_exists: true
  end

  test "UUID generation callback condition respects opt-out flag" do
    ActiveRecord::Base.connection.create_table :opt_out_cond_uuid_models, id: :uuid, force: true do |t|
      t.string :name
    end

    ActiveRecord::Base.connection.create_table :opt_out_cond_int_models, id: :integer, force: true do |t|
      t.string :name
    end

    uuid_model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_cond_uuid_models"
    end

    integer_model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_cond_int_models"
      use_integer_primary_key
    end

    uuid_record = uuid_model.new(name: "UUID Model")
    integer_record = integer_model.new(name: "Integer Model")

    assert uuid_record.send(:id).nil?, "UUID record should have nil id initially"
    assert integer_record.send(:id).nil?, "Integer record should have nil id initially"

    uuid_record.save!
    integer_record.save!

    assert_valid_uuid7(uuid_record.id)
    assert_kind_of Integer, integer_record.id

    ActiveRecord::Base.connection.drop_table :opt_out_cond_uuid_models, if_exists: true
    ActiveRecord::Base.connection.drop_table :opt_out_cond_int_models, if_exists: true
  end

  test "opt-out flag inheritance works correctly" do
    ActiveRecord::Base.connection.create_table :opt_out_inherit_parent, id: :uuid, force: true do |t|
      t.string :name
    end

    parent = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_inherit_parent"
      use_integer_primary_key
    end

    subclass = Class.new(parent) do
      self.table_name = "opt_out_inherit_parent"
    end

    assert subclass.uses_uuid_primary_key?,
           "Subclass should NOT inherit opt-out flag from parent unless explicitly set"

    record = subclass.create!(name: "Subclass Test")
    assert_valid_uuid7(record.id)

    ActiveRecord::Base.connection.drop_table :opt_out_inherit_parent, if_exists: true
  end

  test "subclass can override parent opt-out behavior" do
    ActiveRecord::Base.connection.create_table :opt_out_override_parent, id: :uuid, force: true do |t|
      t.string :name
    end

    parent = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_override_parent"
      use_integer_primary_key
    end

    subclass = Class.new(parent) do
      self.table_name = "opt_out_override_parent"
    end

    assert subclass.uses_uuid_primary_key?,
           "Subclass without use_integer_primary_key should use UUIDs"

    record = subclass.create!(name: "Override Test")
    assert_valid_uuid7(record.id)

    ActiveRecord::Base.connection.drop_table :opt_out_override_parent, if_exists: true
  end

  test "multiple models can have different primary key types" do
    ActiveRecord::Base.connection.create_table :opt_out_multi_uuid, id: :uuid, force: true do |t|
      t.string :name
    end

    ActiveRecord::Base.connection.create_table :opt_out_multi_int, id: :integer, force: true do |t|
      t.string :name
    end

    uuid_model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_multi_uuid"
    end

    integer_model = Class.new(ApplicationRecord) do
      self.table_name = "opt_out_multi_int"
      use_integer_primary_key
    end

    uuid_record = uuid_model.create!(name: "UUID Record")
    integer_record = integer_model.create!(name: "Integer Record")

    assert_valid_uuid7(uuid_record.id)
    assert_kind_of Integer, integer_record.id

    found_uuid = uuid_model.find(uuid_record.id)
    found_integer = integer_model.find(integer_record.id)

    assert_equal uuid_record.id, found_uuid.id
    assert_equal integer_record.id, found_integer.id

    ActiveRecord::Base.connection.drop_table :opt_out_multi_uuid, if_exists: true
    ActiveRecord::Base.connection.drop_table :opt_out_multi_int, if_exists: true
  end

  private

  def assert_valid_uuid7(uuid)
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, uuid,
                 "Expected valid UUIDv7 format")
  end
end
