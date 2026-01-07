module RailsUuidPk
  class Railtie < ::Rails::Railtie
    initializer "rails-uuid-pk.generators" do |app|
      app.config.generators do |g|
        g.orm :active_record, primary_key_type: :uuid
      end
    end

    initializer "rails-uuid-pk.configure_database" do |app|
      # For SQLite, use SQL schema format since schema.rb has issues with UUID types
      if app.config.database_configuration&.dig(Rails.env, "adapter") == "sqlite3"
        app.config.active_record.schema_format = :sql
      end
    end

    initializer "rails-uuid-pk.include_concern" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.include RailsUuidPk::HasUuidv7PrimaryKey
      end
    end

    initializer "rails-uuid-pk.configure_type_map" do
      ActiveSupport.on_load(:active_record) do
        if ActiveRecord::Base.connection.adapter_name == "SQLite"
          # Define a custom UUID type for SQLite that reports as :uuid
          uuid_type = Class.new(ActiveRecord::Type::String) do
            def type
              :uuid
            end
          end.new

          # Map 'uuid' SQL type to our custom UUID type
          ActiveRecord::Base.connection.send(:type_map).register_type "uuid" do |sql_type|
            uuid_type
          end
        end
      end
    end
  end
end
