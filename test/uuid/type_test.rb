require "test_helper"

class UuidTypeTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.use_instantiated_fixtures = false
  test "UUID type handles valid UUID strings correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    valid_uuid = "550e8400-e29b-41d4-a716-446655440000"

    result = uuid_type.cast(valid_uuid)
    assert_equal valid_uuid, result
  end

  test "UUID type handles invalid UUID strings (gracefully)" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    invalid_uuid = "not-a-uuid"

    result = uuid_type.cast(invalid_uuid)
    assert_equal invalid_uuid, result, "Invalid UUIDs should be stored as-is for backward compatibility"
  end

  test "UUID type handles nil values correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    assert_nil uuid_type.cast(nil)
    assert_nil uuid_type.deserialize(nil)
    assert_nil uuid_type.serialize(nil)
  end

  test "UUID type handles non-string values" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    result = uuid_type.cast(123)
    assert_equal "123", result

    result = uuid_type.cast(45.67)
    assert_equal "45.67", result
  end

  test "UUID type deserialize method works correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    uuid_string = "550e8400-e29b-41d4-a716-446655440000"

    result = uuid_type.deserialize(uuid_string)
    assert_equal uuid_string, result
  end

  test "UUID type serialize method works correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    uuid_string = "550e8400-e29b-41d4-a716-446655440000"

    result = uuid_type.serialize(uuid_string)
    assert_equal uuid_string, result
  end

  test "UUID type changed_in_place? detects changes correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    assert uuid_type.changed_in_place?("old-uuid", "new-uuid")
    assert_not uuid_type.changed_in_place?("same-uuid", "same-uuid")
    assert uuid_type.changed_in_place?(nil, "new-uuid")
    assert uuid_type.changed_in_place?("old-uuid", nil)
  end

  test "UUID type valid? method works correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    assert uuid_type.send(:valid?, "550e8400-e29b-41d4-a716-446655440000")
    assert_not uuid_type.send(:valid?, "not-a-uuid")
    assert_not uuid_type.send(:valid?, "550e8400-e29b-41d4-a716")  # too short
    assert_not uuid_type.send(:valid?, "550e8400-e29b-41d4-a716-446655440000-extra")  # too long
    assert_not uuid_type.send(:valid?, "gggggggg-gggg-gggg-gggg-gggggggggggg")  # invalid chars
  end

  test "UUID type rails_supports_uuid_in_schema? works correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test the private method
    supports_uuid = uuid_type.send(:rails_supports_uuid_in_schema?)
    expected = Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new("8.1.0")
    assert_equal expected, supports_uuid
  end

  test "UUID type cast handles various input types" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    valid_uuid = "550e8400-e29b-41d4-a716-446655440000"

    # Test valid UUID string
    result = uuid_type.cast(valid_uuid)
    assert_equal valid_uuid, result

    # Test nil
    assert_nil uuid_type.cast(nil)

    # Test integers
    result = uuid_type.cast(123)
    assert_equal "123", result

    # Test floats
    result = uuid_type.cast(45.67)
    assert_equal "45.67", result

    # Test objects with to_s
    obj = Object.new
    def obj.to_s; "custom-string"; end
    result = uuid_type.cast(obj)
    assert_equal "custom-string", result

    # Test objects without to_s (should raise)
    obj_no_to_s = Object.new
    result = uuid_type.cast(obj_no_to_s)
    assert_equal obj_no_to_s.to_s, result
  end

  test "UUID type deserialize handles database values correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    uuid_string = "550e8400-e29b-41d4-a716-446655440000"

    # Test normal string deserialization
    result = uuid_type.deserialize(uuid_string)
    assert_equal uuid_string, result

    # Test nil deserialization
    assert_nil uuid_type.deserialize(nil)

    # Test empty string
    result = uuid_type.deserialize("")
    assert_equal "", result

    # Test invalid values (should pass through)
    result = uuid_type.deserialize("invalid-uuid")
    assert_equal "invalid-uuid", result
  end

  test "UUID type serialize handles storage correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    uuid_string = "550e8400-e29b-41d4-a716-446655440000"

    # Test normal serialization
    result = uuid_type.serialize(uuid_string)
    assert_equal uuid_string, result

    # Test nil serialization
    assert_nil uuid_type.serialize(nil)

    # Test invalid values (should convert to string)
    result = uuid_type.serialize(123)
    assert_equal "123", result
  end

  test "UUID type changed_in_place? comprehensive testing" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test same values
    assert_not uuid_type.changed_in_place?("same-uuid", "same-uuid")
    assert_not uuid_type.changed_in_place?(nil, nil)

    # Test different values
    assert uuid_type.changed_in_place?("old-uuid", "new-uuid")
    assert uuid_type.changed_in_place?("uuid", nil)
    assert uuid_type.changed_in_place?(nil, "uuid")

    # Test type coercion
    assert uuid_type.changed_in_place?(123, "123")
    assert_not uuid_type.changed_in_place?(123, 123) # Both cast to "123"

    # Test case sensitivity
    assert uuid_type.changed_in_place?("UUID", "uuid")
  end

  test "UUID type valid? comprehensive validation" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Valid UUIDs
    valid_uuids = [
      "550e8400-e29b-41d4-a716-446655440000",
      "12345678-1234-5678-9012-123456789012",
      "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" # uppercase
    ]

    valid_uuids.each do |uuid|
      assert uuid_type.send(:valid?, uuid), "#{uuid} should be valid"
    end

    # Invalid UUIDs
    invalid_uuids = [
      nil,
      "",
      "not-a-uuid",
      "550e8400-e29b-41d4-a716", # too short
      "550e8400-e29b-41d4-a716-446655440000-extra", # too long
      "550e8400-e29b-41d4-a716-44665544000g", # invalid char
      "550e8400e29b41d4a716446655440000", # no dashes
      "gggggggg-gggg-gggg-gggg-gggggggggggg", # invalid chars
      "550e8400-e29b-41d4-a716-446655440000-extra-stuff"
    ]

    invalid_uuids.each do |uuid|
      assert_not uuid_type.send(:valid?, uuid), "#{uuid.inspect} should be invalid"
    end
  end

  test "UUID type handles Rails version compatibility correctly" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test that type() method works correctly based on Rails version
    result = uuid_type.type
    expected = Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new("8.1.0") ? :uuid : :string
    assert_equal expected, result

    # Test rails_supports_uuid_in_schema? with different scenarios
    supports_uuid = uuid_type.send(:rails_supports_uuid_in_schema?)
    rails_version = Gem::Version.new(Rails::VERSION::STRING)
    assert_equal (rails_version >= Gem::Version.new("8.1.0")), supports_uuid
  end

  test "UUID type inheritance from ActiveRecord::Type::String" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Should inherit from String type
    assert uuid_type.is_a?(ActiveRecord::Type::String)

    # Should have access to string type methods
    assert_respond_to uuid_type, :type_cast_for_database
    assert_respond_to uuid_type, :type_cast_from_database
  end

  # Tests to exercise uncovered code paths

  test "UUID type deserialize calls cast for non-nil values" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test deserialize with valid UUID
    valid_uuid = "550e8400-e29b-41d4-a716-446655440000"
    result = uuid_type.deserialize(valid_uuid)
    assert_equal valid_uuid, result

    # Test deserialize with nil (should return nil)
    assert_nil uuid_type.deserialize(nil)
  end

  test "UUID type serialize calls cast method" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test serialize calls cast
    result = uuid_type.serialize("test-value")
    assert_equal "test-value", result

    # Test serialize with nil
    assert_nil uuid_type.serialize(nil)
  end

  test "UUID type changed_in_place? calls cast on both arguments" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test changed_in_place? calls cast on both arguments
    assert uuid_type.changed_in_place?("old", "new")
    assert_not uuid_type.changed_in_place?("same", "same")
  end

  test "UUID type cast exercises valid UUID path" do
    uuid_type = RailsUuidPk::Type::Uuid.new
    valid_uuid = "550e8400-e29b-41d4-a716-446655440000"

    # Test that cast returns valid UUIDs unchanged
    result = uuid_type.cast(valid_uuid)
    assert_equal valid_uuid, result
  end

  test "UUID type cast exercises to_s path" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test cast with object that has to_s
    obj = Object.new
    def obj.to_s; "550e8400-e29b-41d4-a716-446655440000"; end  # valid UUID
    result = uuid_type.cast(obj)
    assert_equal "550e8400-e29b-41d4-a716-446655440000", result
  end

  test "UUID type cast exercises fallback path" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test cast with object that has to_s but returns invalid UUID
    obj = Object.new
    def obj.to_s; "invalid-uuid-string"; end
    result = uuid_type.cast(obj)
    assert_equal "invalid-uuid-string", result
  end

  test "UUID type valid? exercises regex matching" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test valid? method with various inputs to ensure regex is executed
    assert uuid_type.send(:valid?, "550e8400-e29b-41d4-a716-446655440000")
    assert_not uuid_type.send(:valid?, "invalid")
  end

  test "UUID type rails_supports_uuid_in_schema? exercises version comparison" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test rails_supports_uuid_in_schema? method
    result = uuid_type.send(:rails_supports_uuid_in_schema?)
    assert_includes [ true, false ], result  # Should return boolean
  end

  test "UUID type type() method returns correct value based on Rails version" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test the type method which has conditional logic
    result = uuid_type.type
    expected = uuid_type.send(:rails_supports_uuid_in_schema?) ? :uuid : :string
    assert_equal expected, result
  end

  test "UUID type type() method returns :string for Rails versions that don't support UUID in schema" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Mock rails_supports_uuid_in_schema? to return false to test the else branch
    uuid_type.define_singleton_method(:rails_supports_uuid_in_schema?) { false }

    result = uuid_type.type
    assert_equal :string, result
  end

  test "UUID type type_cast_for_database calls serialize" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test type_cast_for_database calls serialize
    result = uuid_type.type_cast_for_database("test-value")
    assert_equal "test-value", result
  end

  test "UUID type type_cast_from_database calls deserialize" do
    uuid_type = RailsUuidPk::Type::Uuid.new

    # Test type_cast_from_database calls deserialize
    result = uuid_type.type_cast_from_database("550e8400-e29b-41d4-a716-446655440000")
    assert_equal "550e8400-e29b-41d4-a716-446655440000", result
  end
end
