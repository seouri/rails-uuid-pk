module RailsUuidPk
  module Type
    class Uuid < ActiveRecord::Type::String
      def type
        # Rails 8.1+ supports UUID types in schema dumping
        # Earlier versions need :string to avoid "Unknown type 'uuid'" errors
        if rails_supports_uuid_in_schema?
          :uuid
        else
          :string
        end
      end

      def deserialize(value)
        return if value.nil?
        cast(value)
      end

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

      def serialize(value)
        cast(value)
      end

      def changed_in_place?(raw_old_value, new_value)
        cast(raw_old_value) != cast(new_value)
      end

      private

      def valid?(value)
        value.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      end

      def rails_supports_uuid_in_schema?
        # Rails 8.1+ supports UUID types in schema dumping
        # Earlier versions (8.0.x) need :string to avoid "Unknown type 'uuid'" errors
        rails_version = Gem::Version.new(Rails::VERSION::STRING)
        rails_version >= Gem::Version.new("8.1.0")
      end
    end
  end
end
