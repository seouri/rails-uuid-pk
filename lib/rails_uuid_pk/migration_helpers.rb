# frozen_string_literal: true

module RailsUuidPk
  # Migration helpers for automatic foreign key type detection.
  #
  # This module provides smart migration helpers that automatically detect when
  # foreign key columns should use UUID types based on the referenced table's
  # primary key type. It extends ActiveRecord's migration DSL to provide seamless
  # UUID foreign key support.
  #
  # @example Automatic UUID foreign key detection
  #   create_table :posts do |t|
  #     t.references :user  # Automatically uses :uuid type if users.id is UUID
  #     t.string :title
  #   end
  #
  # @example Polymorphic associations
  #   create_table :comments do |t|
  #     t.references :commentable, polymorphic: true  # Uses :uuid if app uses UUIDs
  #   end
  #
  # @example Explicit type override (respects user choice)
  #   create_table :posts do |t|
  #     t.references :user, type: :integer  # Uses :integer even if users.id is UUID
  #   end
  #
  # @see RailsUuidPk::Railtie
  module MigrationHelpers
    # Migration helper methods for references and foreign keys.
    #
    # This module extends ActiveRecord's migration classes to automatically
    # determine appropriate foreign key types based on the referenced table's
    # primary key type.
    module References
      # Creates a reference column with automatic type detection.
      #
      # Automatically sets the column type to :uuid if the referenced table
      # uses UUID primary keys, unless the type is explicitly specified.
      #
      # @param args [Array<String, Symbol>] Arguments passed to the original references method
      # @param options [Hash] Options hash for the reference column
      # @option options [String, Symbol] :to_table The table being referenced (defaults to pluralized ref_name)
      # @option options [Symbol] :type The column type (:integer, :bigint, :uuid)
      # @option options [Boolean] :polymorphic Whether this is a polymorphic association
      # @return [void]
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
          RailsUuidPk.log(:debug, "Setting foreign key #{ref_name} to UUID type (referencing #{ref_table})")
          options[:type] = :uuid
        end

        super(*args, **options)
      end

      # Adds a reference column to an existing table with automatic type detection.
      #
      # @param table_name [String, Symbol] The name of the table to add the reference to
      # @param ref_name [String, Symbol] The name of the reference column
      # @param options [Hash] Options hash for the reference column
      # @option options [String, Symbol] :to_table The table being referenced (defaults to pluralized ref_name)
      # @option options [Symbol] :type The column type (:integer, :bigint, :uuid)
      # @option options [Boolean] :polymorphic Whether this is a polymorphic association
      # @return [void]
      def add_reference(table_name, ref_name, **options)
        ref_table = options.delete(:to_table) || ref_name.to_s.pluralize

        current_type = options[:type]
        if (current_type.nil? || current_type == :integer || current_type == :bigint) &&
           (uuid_primary_key?(ref_table) || (options[:polymorphic] && application_uses_uuid_primary_keys?))
          RailsUuidPk.log(:debug, "Setting foreign key #{ref_name} to UUID type (referencing #{ref_table})")
          options[:type] = :uuid
        end

        super(table_name, ref_name, **options)
      end

      # Checks if the application is configured to use UUID primary keys globally.
      #
      # @return [Boolean] true if the application uses UUID primary keys by default
      # @note This checks Rails generator configuration for primary_key_type
      def application_uses_uuid_primary_keys?
        # Check if the application is configured to use UUID primary keys globally
        defined?(Rails) && Rails.application.config.generators.options[:active_record]&.[](:primary_key_type) == :uuid
      end

      # Alias for references method (ActiveRecord compatibility)
      alias_method :belongs_to, :references

      # Alias for add_reference method (ActiveRecord compatibility)
      alias_method :add_belongs_to, :add_reference

      private

      # Checks if a table uses UUID primary keys.
      #
      # @param table_name [String, Symbol] The name of the table to check
      # @return [Boolean] true if the table's primary key is a UUID type
      # @note Results are cached during migration execution for performance
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

      # Finds the primary key column for a given table.
      #
      # @param table_name [String, Symbol] The name of the table
      # @param conn [ActiveRecord::ConnectionAdapters::AbstractAdapter] The database connection
      # @return [ActiveRecord::ConnectionAdapters::Column, nil] The primary key column or nil
      def find_primary_key_column(table_name, conn)
        pk_name = conn.primary_key(table_name)
        return nil unless pk_name

        conn.columns(table_name).find { |c| c.name == pk_name }
      end
    end
  end
end
