module RailsUuidPk
  module MigrationHelpers
    module References
      def references(*args, **options)
        ref_name = args.first
        ref_table = options.delete(:to_table) || ref_name.to_s.pluralize

        # Only set UUID type if not already explicitly set by user
        # In Rails, default type is often passed as :integer or :bigint in the options hash
        # depending on the Rails version and whether it is a migration or a table definition.
        # We want to override it to :uuid if the target table uses UUID primary keys.
        current_type = options[:type]
        if (current_type.nil? || current_type == :integer || current_type == :bigint) &&
           (uuid_primary_key?(ref_table) || (options[:polymorphic] && application_uses_uuid_primary_keys?))
          options[:type] = :uuid
        end

        super(*args, **options)
      end

      def add_reference(table_name, ref_name, **options)
        ref_table = options.delete(:to_table) || ref_name.to_s.pluralize

        current_type = options[:type]
        if (current_type.nil? || current_type == :integer || current_type == :bigint) &&
           (uuid_primary_key?(ref_table) || (options[:polymorphic] && application_uses_uuid_primary_keys?))
          options[:type] = :uuid
        end

        super(table_name, ref_name, **options)
      end

      def application_uses_uuid_primary_keys?
        # Check if the application is configured to use UUID primary keys globally
        defined?(Rails) && Rails.application.config.generators.options[:active_record]&.[](:primary_key_type) == :uuid
      end

      alias_method :belongs_to, :references
      alias_method :add_belongs_to, :add_reference

      private

      def uuid_primary_key?(table_name)
        # Cache results for the duration of the migration process to improve performance
        @uuid_pk_cache ||= {}
        return @uuid_pk_cache[table_name] if @uuid_pk_cache.key?(table_name)

        conn = @conn || @base || (respond_to?(:connection) ? connection : self)
        # Ensure we have a connection-like object that can check for table existence
        return false unless conn.respond_to?(:table_exists?) && conn.table_exists?(table_name)

        pk_column = find_primary_key_column(table_name, conn)
        @uuid_pk_cache[table_name] = !!(pk_column && pk_column.sql_type.downcase.match?(/\A(uuid|varchar\(36\))\z/))
      end

      def find_primary_key_column(table_name, conn)
        pk_name = conn.primary_key(table_name)
        return nil unless pk_name

        conn.columns(table_name).find { |c| c.name == pk_name }
      end
    end
  end
end
