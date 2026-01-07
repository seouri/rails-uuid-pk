module RailsUuidPk
  module Type
    class Uuid < ActiveRecord::Type::String
      def type
        # Return :string during schema dumping to avoid "Unknown type 'uuid'" errors
        # Return :uuid for normal operation and tests
        if caller.any? { |c| c.include?("schema_dumper") }
          :string
        else
          :uuid
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
    end
  end
end
