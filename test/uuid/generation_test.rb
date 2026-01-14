require "test_helper"

class UuidGenerationTest < ActiveSupport::TestCase
  def setup
    # Use transaction rollback for automatic cleanup
    ActiveRecord::Base.connection.begin_transaction(joinable: false) if ActiveRecord::Base.connection.open_transactions.zero?
  end

  def teardown
    # Rollback transaction to clean up test data
    ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.open_transactions > 0
  end

  # Custom assertions
  def assert_valid_uuid7(uuid)
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i, uuid,
                 "Expected valid UUIDv7 format")
  end

  def assert_uuid_timestamp_reasonable(uuid)
    # Extract timestamp component (first 8 hex chars = 32 bits)
    timestamp_high = uuid[0..7].to_i(16)
    # Should be reasonable (not 0, not in far future, not negative)
    assert timestamp_high > 0, "UUID timestamp should not be zero"
    assert timestamp_high < 0xFFFFFFFF, "UUID timestamp should fit in 32 bits"
  end

  test "generates UUIDv7 primary key on create" do
    user = User.create!(name: "Alice")
    assert_valid_uuid7(user.id)
    assert_uuid_timestamp_reasonable(user.id)
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

  test "UUIDv7 version and variant bits are correct (RFC 9562 compliance)" do
    user = User.create!(name: "RFC Test")
    uuid = user.id

    # Extract version nibble (4 bits starting at position 12)
    version_nibble = uuid[14] # Position 14 is the version character
    assert_equal "7", version_nibble, "UUIDv7 version bit should be 7"

    # Extract variant nibbles (positions 19-21 in standard UUID format)
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
    first_segment = user.id[0..7]

    # Should be a valid hexadecimal string
    assert_match(/\A[0-9a-f]{8}\z/, first_segment, "First UUID segment should be valid hex")

    # Convert to integer and verify it's reasonable (not all zeros, not absurdly large)
    timestamp_component = first_segment.to_i(16)
    assert timestamp_component > 0, "UUID timestamp component should not be zero"
    assert timestamp_component < 2**32, "UUID timestamp component should fit in 32 bits"
  end

  test "UUIDv7 collision resistance" do
    # Generate a reasonable number of UUIDs for collision testing
    # Use smaller sample for CI performance, larger for comprehensive testing
    uuid_count = ENV["PERFORMANCE_TEST"] ? 10000 : 100
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
      assert_valid_uuid7(uuid)
    end
  end

  test "UUIDv7 format is consistently lowercase" do
    user = User.create!(name: "Format Test")

    # UUID should be lowercase by default (Rails standard)
    assert_match(/\A[0-9a-f]+\z/, user.id.gsub(/-/, ""),
                 "UUID should contain only lowercase hexadecimal characters")

    # Verify UUID follows standard format
    assert_valid_uuid7(user.id)
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
      assert_raises(ActiveRecord::RecordNotFound, "Should reject malformed UUID: #{malformed_uuid}") do
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
    sample_size = ENV["PERFORMANCE_TEST"] ? 1000 : 50
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
  end

  test "UUID assignment callback only runs when id is nil" do
    user = User.new(name: "Callback Test")

    # Manually set id before save
    manual_uuid = SecureRandom.uuid_v7
    user.id = manual_uuid

    user.save!

    # Should keep the manually set UUID
    assert_equal manual_uuid, user.id
  end

  test "UUID assignment logs correctly" do
    # Capture log output
    old_logger = RailsUuidPk.logger
    log_output = StringIO.new
    RailsUuidPk.logger = Logger.new(log_output)

    user = User.create!(name: "Logging Test")

    # Should log the UUID assignment
    log_content = log_output.string
    assert_match(/Assigned UUIDv7/, log_content)
    assert_match(/#{user.id}/, log_content)

    # Restore logger
    RailsUuidPk.logger = old_logger
  end

  test "assign_uuidv7_if_needed callback only runs when id is nil" do
    # Test that the callback assigns UUID when id is nil
    user = User.new(name: "Callback Test")

    # Ensure id is nil before save
    assert_nil user.id

    # Save should trigger callback
    user.save!

    # Should have assigned a UUID
    assert_not_nil user.id
    assert_valid_uuid7(user.id)
  end

  test "assign_uuidv7_if_needed callback skips when id is present" do
    # Test that callback is skipped when id is already set
    manual_uuid = "custom-manual-uuid"
    user = User.new(name: "Skip Callback Test", id: manual_uuid)

    # Id is already present
    assert_equal manual_uuid, user.id

    # Save should not change the id
    user.save!

    # Should keep the manual UUID
    assert_equal manual_uuid, user.id
  end
end
