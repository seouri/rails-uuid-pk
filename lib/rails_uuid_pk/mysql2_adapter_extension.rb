module RailsUuidPk
  module Mysql2AdapterExtension
    def native_database_types
      super.merge(
        uuid: { name: "varchar", limit: 36 }
      )
    end
  end
end
