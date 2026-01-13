# frozen_string_literal: true

module RailsUuidPk
  # Custom ActiveRecord types for UUID handling.
  #
  # This module provides custom type classes that handle UUID serialization,
  # deserialization, and schema dumping with proper Rails version compatibility.
  module Type
    # Custom UUID type for ActiveRecord.
    #
    # This type extends ActiveRecord::Type::String to provide UUID-specific
    # handling with Rails version-aware schema dumping. It ensures proper
    # UUID validation and formatting while maintaining backward compatibility.
    #
    # @example Automatic type handling
    #   class User < ApplicationRecord
    #     # id column automatically uses this type
    #   end
    #
    # @see https://api.rubyonrails.org/classes/ActiveRecord/Type/String.html
    class Uuid < ActiveRecord::Type::String
      # Returns the appropriate schema type symbol for the current Rails version.
      #
      # @return [Symbol] :uuid for Rails 8.1+, :string for earlier versions
      # @note Rails 8.1+ supports native :uuid type in schema dumping
      def type
        # Rails 8.1+ supports UUID types in schema dumping
        # Earlier versions need :string to avoid "Unknown type 'uuid'" errors
        if rails_supports_uuid_in_schema?
          :uuid
        else
          :string
        end
      end

      # Deserializes a value from the database.
      #
      # @param value [Object] The raw value from the database
      # @return [String, nil] The deserialized UUID string or nil
      def deserialize(value)
        return if value.nil?
        cast(value)
      end

      # Casts a value to a UUID string.
      #
      # Accepts valid UUID strings and converts other values to strings.
      # Invalid UUIDs are allowed for backward compatibility.
      #
      # @param value [Object] The value to cast
      # @return [String, nil] The cast UUID string or nil
      def cast(value)
        return if value.nil?
        return value if value.is_a?(String) && valid?(value)

        if value.respond_to?(:to_s)
          str = value.to_s
          return str if valid?(str)
        end

        # Allow invalid UUIDs to be stored (for backward compatibility and manual id assignment)
        value.to_s
      end

      # Serializes a value for database storage.
      #
      # @param value [Object] The value to serialize
      # @return [String, nil] The serialized value or nil
      def serialize(value)
        cast(value)
      end

      # Checks if two values are different for change detection.
      #
      # @param raw_old_value [Object] The old raw value from the database
      # @param new_value [Object] The new value being compared
      # @return [Boolean] true if the values are different
      def changed_in_place?(raw_old_value, new_value)
        cast(raw_old_value) != cast(new_value)
      end

      private

      # Validates if a string is a properly formatted UUID.
      #
      # @param value [String] The string to validate
      # @return [Boolean] true if the string matches UUID format
      def valid?(value)
        value.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      end

      # Checks if the current Rails version supports UUID types in schema dumping.
      #
      # @return [Boolean] true if Rails 8.1 or later
      # @note Rails 8.1+ allows :uuid in schema files, earlier versions require :string
      def rails_supports_uuid_in_schema?
        # Rails 8.1+ supports UUID types in schema dumping
        # Earlier versions (8.0.x) need :string to avoid "Unknown type 'uuid'" errors
        rails_version = Gem::Version.new(Rails::VERSION::STRING)
        rails_version >= Gem::Version.new("8.1.0")
      end
    end
  end
end
