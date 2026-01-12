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
      ActiveSupport.on_load(:active_record) do
        case ActiveRecord::Base.connection.adapter_name
        when "SQLite"
          require "active_record/connection_adapters/sqlite3_adapter"
          ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(RailsUuidPk::Sqlite3AdapterExtension)
        when "MySQL"
          begin
            require "active_record/connection_adapters/mysql2_adapter"
            ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(RailsUuidPk::Mysql2AdapterExtension)
          rescue LoadError
            # MySQL adapter not available
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

      # Get the connection-specific type map
      type_map = ActiveRecord::Base.connection.send(:type_map)
      # Map varchar(36) or varchar SQL type to our custom UUID type
      type_map.register_type(/varchar/i) { RailsUuidPk::Type::Uuid.new }
      # Also map "uuid" SQL type for direct lookups
      type_map.register_type("uuid") { RailsUuidPk::Type::Uuid.new }
    end
  end
end
