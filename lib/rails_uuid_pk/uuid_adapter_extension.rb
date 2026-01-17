# frozen_string_literal: true

module RailsUuidPk
  # Shared UUID adapter extension for database adapters.
  #
  # This module provides common UUID type support functionality that can be
  # included by specific database adapter extensions (MySQL, SQLite, etc.).
  # Since most databases don't have native UUID types, it maps UUIDs to
  # VARCHAR(36) columns and registers the custom UUID type handlers.
  #
  # @example Automatic type mapping
  #   # Database tables with VARCHAR(36) columns are automatically treated as UUIDs
  #   create_table :users do |t|
  #     t.column :id, :uuid  # Maps to VARCHAR(36) in supported databases
  #   end
  #
  # @see RailsUuidPk::Type::Uuid
  module UuidAdapterExtension
    # Defines native database types for UUID support.
    #
    # @return [Hash] Database type definitions including UUID mapping
    def native_database_types
      super.merge(
        uuid: { name: "varchar", limit: 36 }
      )
    end

    # Checks if a type is valid for this adapter.
    #
    # Overrides ActiveRecord's valid_type? to recognize the custom UUID type.
    #
    # @param type [Symbol] The type to check
    # @return [Boolean] true if the type is valid
    def valid_type?(type)
      return true if type == :uuid
      super
    end

    # Registers UUID type handlers in the adapter's type map.
    #
    # @param m [ActiveRecord::ConnectionAdapters::AbstractAdapter::TypeMap] The type map to register with
    # @return [void]
    def register_uuid_types(m = type_map)
      RailsUuidPk.log(:debug, "Registering UUID types on #{m.class}")
      m.register_type(/varchar\(36\)/i) { RailsUuidPk::Type::Uuid.new }
      m.register_type("uuid") { RailsUuidPk::Type::Uuid.new }
    end

    # Initializes the type map with UUID type registrations.
    #
    # @param m [ActiveRecord::ConnectionAdapters::AbstractAdapter::TypeMap] The type map to initialize
    # @return [void]
    def initialize_type_map(m = type_map)
      super
      register_uuid_types(m)
    end

    # Configures the database connection with UUID type support.
    #
    # This method should be overridden by including adapters to handle
    # database-specific connection configuration requirements.
    #
    # @return [void]
    def configure_connection
      super
      register_uuid_types
    end

    # Overrides type dumping to properly handle UUID columns.
    #
    # @param column [ActiveRecord::ConnectionAdapters::Column] The column to dump
    # @return [Array] The type and options for the schema dump
    def type_to_dump(column)
      if column.type == :uuid
        return [ :uuid, {} ]
      end
      super
    end
  end
end
