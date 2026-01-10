module RailsUuidPk
  class Railtie < ::Rails::Railtie
    initializer "rails-uuid-pk.generators" do |app|
      app.config.generators do |g|
        g.orm :active_record, primary_key_type: :uuid
      end
    end

    initializer "rails-uuid-pk.configure_type_map", after: "active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        if ActiveRecord::Base.connection.adapter_name == "SQLite"
          # Register the UUID type with ActiveRecord
          ActiveRecord::Type.register(:uuid, RailsUuidPk::Type::Uuid, adapter: :sqlite3)

          # Map varchar SQL type to our custom UUID type (since that's how UUID columns are stored in SQLite)
          ActiveRecord::Base.connection.send(:type_map).register_type(/varchar/i) do |sql_type|
            RailsUuidPk::Type::Uuid.new
          end

          # Also map "uuid" SQL type to our custom UUID type for direct lookups
          ActiveRecord::Base.connection.send(:type_map).register_type "uuid" do |sql_type|
            RailsUuidPk::Type::Uuid.new
          end
        elsif ActiveRecord::Base.connection.adapter_name == "MySQL"
          # Register the UUID type with ActiveRecord for MySQL
          ActiveRecord::Type.register(:uuid, RailsUuidPk::Type::Uuid, adapter: :mysql2)

          # Map varchar SQL type to our custom UUID type (since that's how UUID columns are stored in MySQL)
          ActiveRecord::Base.connection.send(:type_map).register_type(/varchar/i) do |sql_type|
            RailsUuidPk::Type::Uuid.new
          end

          # Also map "uuid" SQL type to our custom UUID type for direct lookups
          ActiveRecord::Base.connection.send(:type_map).register_type "uuid" do |sql_type|
            RailsUuidPk::Type::Uuid.new
          end
        end
      end
    end

    initializer "rails-uuid-pk.native_types" do
      require "active_record/connection_adapters/sqlite3_adapter"
      ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(RailsUuidPk::Sqlite3AdapterExtension)
    end

    initializer "rails-uuid-pk.mysql_native_types" do
      begin
        require "active_record/connection_adapters/mysql2_adapter"
        ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(RailsUuidPk::Mysql2AdapterExtension)
      rescue LoadError
        # MySQL adapter not available, skip MySQL-specific initialization
      end
    end



    initializer "rails-uuid-pk.schema_format" do |app|
      # Ensure schema_format is set to :ruby for SQLite (default in Rails)
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

        # Include migration helpers for all database adapters
        ActiveRecord::ConnectionAdapters::TableDefinition.prepend(RailsUuidPk::MigrationHelpers::References)
        ActiveRecord::ConnectionAdapters::Table.prepend(RailsUuidPk::MigrationHelpers::References)
      end
    end
  end
end
