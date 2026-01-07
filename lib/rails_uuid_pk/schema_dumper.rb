module RailsUuidPk
  module SchemaDumper
    private

    def column_spec_for_primary_key(column)
      return super unless column.name == "id"

      # Check if this is a UUID column by sql_type (varchar(36) in SQLite)
      if column.sql_type =~ /varchar\(36\)/i
        # Return {} to indicate a default primary key
        # This will cause the id column to be included in the regular column loop
        # and dumped as t.string :id, limit: 36
        {}
      else
        super
      end
    end

    def column_spec(column, *args)
      # Handle UUID columns by ensuring they include limit: 36
      if column.sql_type =~ /varchar\(36\)/i
        [ column.name, :string, column_options(column).merge(limit: 36) ]
      else
        super
      end
    end
  end
end
