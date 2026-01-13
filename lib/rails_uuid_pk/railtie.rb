# frozen_string_literal: true

module RailsUuidPk
  # Rails integration for automatic UUIDv7 primary key generation.
  #
  # This Railtie automatically configures Rails applications to use UUID primary keys
  # by including the HasUuidv7PrimaryKey concern in all ActiveRecord models and setting
  # up proper database type mappings and migration helpers.
  #
  # The railtie performs the following integrations:
  # - Configures Rails generators to use UUID primary keys
  # - Registers UUID types for SQLite and MySQL adapters
  # - Includes UUIDv7 generation concern in all models
  # - Adds smart migration helpers for foreign key type detection
  # - Sets appropriate schema format for UUID compatibility
  #
  # @example Automatic configuration
  #   # No configuration needed - everything works automatically
  #   class User < ApplicationRecord
  #     # Primary key is automatically UUIDv7
  #   end
  #
  # @see RailsUuidPk::HasUuidv7PrimaryKey
  # @see RailsUuidPk::MigrationHelpers
  class Railtie < ::Rails::Railtie
    # Configures Rails generators to use UUID primary keys by default.
    #
    # This initializer sets the default primary_key_type to :uuid for all
    # newly generated models and migrations.
    initializer "rails-uuid-pk.generators" do |app|
      app.config.generators do |g|
        g.orm :active_record, primary_key_type: :uuid
      end
    end

    # Configures type mappings for SQLite and MySQL adapters.
    #
    # Registers the custom UUID type for adapters that don't have native UUID support.
    initializer "rails-uuid-pk.configure_type_map", after: "active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        adapter_name = ActiveRecord::Base.connection.adapter_name
        if %w[SQLite MySQL].include?(adapter_name)
          RailsUuidPk::Railtie.register_uuid_type(adapter_name.downcase.to_sym)
        end
      end
    end

    # Extends database adapters with UUID type support.
    #
    # Prepends adapter-specific extensions to add native UUID type definitions
    # and type registration methods.
    initializer "rails-uuid-pk.native_types" do
      ActiveSupport.on_load(:active_record_sqlite3adapter) do
        prepend RailsUuidPk::Sqlite3AdapterExtension
      end

      ActiveSupport.on_load(:active_record_mysql2adapter) do
        prepend RailsUuidPk::Mysql2AdapterExtension
      end
    end

    # Ensures UUID types are registered on all database connections.
    #
    # This runs after Rails initialization to register UUID types on any
    # existing or future database connections.
    config.after_initialize do
      ActiveSupport.on_load(:active_record) do
        if ActiveRecord::Base.connected?
          ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
            connections = if pool.respond_to?(:connections)
                            pool.connections
            else
                            # Fallback or older rails
                            [ pool.connection ] rescue []
            end

            connections.each do |conn|
              if conn.respond_to?(:register_uuid_types)
                conn.register_uuid_types
              end
            end
          end
        end
      end
    end

    # Sets the schema format to Ruby for UUID compatibility.
    #
    # Ruby schema format is required for proper UUID type handling across
    # different database adapters and Rails versions.
    initializer "rails-uuid-pk.schema_format" do |app|
      app.config.active_record.schema_format ||= :ruby
    end

    # Includes the UUIDv7 generation concern in all ActiveRecord models.
    #
    # This automatically adds UUIDv7 primary key generation to all models
    # without requiring any changes to existing code.
    initializer "rails-uuid-pk.include_concern" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.include RailsUuidPk::HasUuidv7PrimaryKey
      end
    end

    # Adds smart migration helpers for automatic foreign key type detection.
    #
    # Prepends the References module to ActiveRecord migration classes to
    # automatically detect when foreign keys should use UUID types.
    initializer "rails-uuid-pk.migration_helpers" do
      ActiveSupport.on_load(:active_record) do
        require "rails_uuid_pk/migration_helpers"

        ActiveRecord::ConnectionAdapters::TableDefinition.prepend(RailsUuidPk::MigrationHelpers::References)
        ActiveRecord::ConnectionAdapters::Table.prepend(RailsUuidPk::MigrationHelpers::References)
        ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(RailsUuidPk::MigrationHelpers::References)
      end
    end

    # Registers the custom UUID type with ActiveRecord's type registry.
    #
    # @param adapter [Symbol] The database adapter (:sqlite, :mysql)
    # @return [void]
    def self.register_uuid_type(adapter)
      ActiveRecord::Type.register(:uuid, RailsUuidPk::Type::Uuid, adapter: adapter)
    end
  end
end
