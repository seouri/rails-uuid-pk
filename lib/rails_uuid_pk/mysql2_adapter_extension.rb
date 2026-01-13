# frozen_string_literal: true

module RailsUuidPk
  # MySQL adapter extension for UUID type support.
  #
  # This module extends ActiveRecord's MySQL2 adapter to provide native UUID
  # type support. Since MySQL doesn't have a native UUID type, it maps UUIDs
  # to VARCHAR(36) columns and registers the custom UUID type handlers.
  #
  # @example Automatic type mapping
  #   # MySQL tables with VARCHAR(36) columns are automatically treated as UUIDs
  #   create_table :users do |t|
  #     t.column :id, :uuid  # Maps to VARCHAR(36) in MySQL
  #   end
  #
  # @see RailsUuidPk::Type::Uuid
  # @see https://dev.mysql.com/doc/refman/8.0/en/data-types.html
  module Mysql2AdapterExtension
    # Defines native database types for MySQL UUID support.
    #
    # @return [Hash] Database type definitions including UUID mapping
    def native_database_types
      super.merge(
        uuid: { name: "varchar", limit: 36 }
      )
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
    # @return [void]
    def configure_connection
      super
      register_uuid_types
    end
  end
end
