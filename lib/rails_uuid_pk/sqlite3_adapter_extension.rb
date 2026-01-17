# frozen_string_literal: true

module RailsUuidPk
  # SQLite adapter extension for UUID type support.
  #
  # This module extends ActiveRecord's SQLite3 adapter to provide native UUID
  # type support. It includes the shared UUID adapter extension functionality
  # and provides SQLite-specific connection configuration, including transaction-aware
  # connection setup.
  #
  # @example Automatic type mapping
  #   # SQLite tables with VARCHAR(36) columns are automatically treated as UUIDs
  #   create_table :users do |t|
  #     t.column :id, :uuid  # Maps to VARCHAR(36) in SQLite
  #   end
  #
  # @see RailsUuidPk::UuidAdapterExtension
  # @see RailsUuidPk::Type::Uuid
  # @see https://www.sqlite.org/datatype3.html
  module Sqlite3AdapterExtension
    include UuidAdapterExtension

    # Configures the database connection with UUID type support.
    #
    # SQLite-specific implementation that avoids calling super inside transactions,
    # as PRAGMA statements cannot be executed inside transactions in SQLite.
    #
    # @return [void]
    def configure_connection
      # Only call super if not inside a transaction, as PRAGMA statements
      # cannot be executed inside transactions in SQLite
      super unless open_transactions > 0
    end
  end
end
