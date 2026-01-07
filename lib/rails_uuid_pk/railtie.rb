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

          # Map varchar(36) SQL type to our custom UUID type (since that's how UUID columns are stored in SQLite)
          ActiveRecord::Base.connection.send(:type_map).register_type(/varchar\(36\)/i) do |sql_type|
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

    initializer "rails-uuid-pk.schema_dumper", after: "active_record.initialize_database" do
      require "active_record/connection_adapters/sqlite3_adapter"
      require "rails_uuid_pk/schema_dumper"
      ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.prepend(RailsUuidPk::SchemaDumper)
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
  end
end
