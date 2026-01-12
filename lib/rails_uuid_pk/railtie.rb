module RailsUuidPk
  class Railtie < ::Rails::Railtie
    initializer "rails-uuid-pk.generators" do |app|
      app.config.generators do |g|
        g.orm :active_record, primary_key_type: :uuid
      end
    end

    initializer "rails-uuid-pk.configure_type_map", after: "active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        adapter_name = ActiveRecord::Base.connection.adapter_name
        if %w[SQLite MySQL].include?(adapter_name)
          RailsUuidPk::Railtie.register_uuid_type(adapter_name.downcase.to_sym)
        end
      end
    end

    initializer "rails-uuid-pk.native_types" do
      ActiveSupport.on_load(:active_record_sqlite3adapter) do
        prepend RailsUuidPk::Sqlite3AdapterExtension
      end

      ActiveSupport.on_load(:active_record_mysql2adapter) do
        prepend RailsUuidPk::Mysql2AdapterExtension
      end
    end

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

    initializer "rails-uuid-pk.schema_format" do |app|
      app.config.active_record.schema_format ||= :ruby
    end

    initializer "rails-uuid-pk.include_concern" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.include RailsUuidPk::HasUuidv7PrimaryKey
      end
    end

    initializer "rails-uuid-pk.migration_helpers" do
      ActiveSupport.on_load(:active_record) do
        require "rails_uuid_pk/migration_helpers"

        ActiveRecord::ConnectionAdapters::TableDefinition.prepend(RailsUuidPk::MigrationHelpers::References)
        ActiveRecord::ConnectionAdapters::Table.prepend(RailsUuidPk::MigrationHelpers::References)
        ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(RailsUuidPk::MigrationHelpers::References)
      end
    end

    def self.register_uuid_type(adapter)
      ActiveRecord::Type.register(:uuid, RailsUuidPk::Type::Uuid, adapter: adapter)
    end
  end
end
