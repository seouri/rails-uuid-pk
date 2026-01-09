module RailsUuidPk
  module MigrationHelpers
    module References
      def references(*args, **options)
        ref_name = args.first
        ref_table = options.delete(:to_table) || ref_name.to_s.pluralize

        # Only set UUID type if not already explicitly set by user
        # Rails sets type: :integer by default, so we override that
        # But if user explicitly set a different type, we respect it
        if (uuid_primary_key?(ref_table) || (options[:polymorphic] && application_uses_uuid_primary_keys?)) && options[:type] == :integer
          options[:type] = :uuid
        end

        super
      end

      def application_uses_uuid_primary_keys?
        # Check if the application is configured to use UUID primary keys globally
        Rails.application.config.generators.options[:active_record]&.[](:primary_key_type) == :uuid
      end

      alias_method :belongs_to, :references

      private

      def uuid_primary_key?(table_name)
        conn = @conn || @base || (respond_to?(:connection) ? connection : nil)
        return false unless conn&.table_exists?(table_name)

        pk_column = find_primary_key_column(table_name, conn)
        return false unless pk_column

        pk_column.sql_type.downcase.match?(/\A(uuid|varchar\(36\))\z/)
      end

      def find_primary_key_column(table_name, conn)
        pk_name = conn.primary_key(table_name)
        return nil unless pk_name

        conn.columns(table_name).find { |c| c.name == pk_name }
      end
    end
  end
end
