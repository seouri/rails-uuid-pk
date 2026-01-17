# frozen_string_literal: true

module RailsUuidPk
  # MySQL adapter extension for UUID type support.
  #
  # This module extends ActiveRecord's MySQL2 adapter to provide native UUID
  # type support. It includes the shared UUID adapter extension functionality
  # and provides MySQL-specific connection configuration.
  #
  # @example Automatic type mapping
  #   # MySQL tables with VARCHAR(36) columns are automatically treated as UUIDs
  #   create_table :users do |t|
  #     t.column :id, :uuid  # Maps to VARCHAR(36) in MySQL
  #   end
  #
  # @see RailsUuidPk::UuidAdapterExtension
  # @see RailsUuidPk::Type::Uuid
  # @see https://dev.mysql.com/doc/refman/8.0/en/data-types.html
  module Mysql2AdapterExtension
    include UuidAdapterExtension

    # Configures the database connection with UUID type support.
    #
    # @return [void]
    def configure_connection
      super
    end
  end
end
