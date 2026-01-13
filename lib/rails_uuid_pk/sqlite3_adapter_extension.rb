module RailsUuidPk
  module Sqlite3AdapterExtension
    def native_database_types
      super.merge(
        uuid: { name: "varchar", limit: 36 }
      )
    end

    def register_uuid_types(m = type_map)
      RailsUuidPk.log(:debug, "Registering UUID types on #{m.class}")
      m.register_type(/varchar\(36\)/i) { RailsUuidPk::Type::Uuid.new }
      m.register_type("uuid") { RailsUuidPk::Type::Uuid.new }
    end

    def initialize_type_map(m = type_map)
      super
      register_uuid_types(m)
    end

    def configure_connection
      super
      register_uuid_types
    end
  end
end
