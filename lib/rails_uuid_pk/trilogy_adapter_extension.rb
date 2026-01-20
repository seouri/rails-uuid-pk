# frozen_string_literal: true

module RailsUuidPk
  # Trilogy adapter extension for UUID type support.
  #
  # This module extends ActiveRecord's Trilogy adapter to provide native UUID
  # type support. It includes the shared UUID adapter extension functionality
  # and provides Trilogy-specific connection configuration.
  #
  # Trilogy is GitHub's high-performance MySQL adapter that offers significant
  # performance improvements over the standard mysql2 adapter, particularly for
  # high-traffic Rails applications.
  #
  # @example UUID primary key and foreign key references
  #   # Primary key uses UUID type
  #   create_table :users, id: :uuid do |t|
  #     t.string :name
  #   end
  #
  #   # Foreign key automatically detects and uses UUID type
  #   create_table :posts do |t|
  #     t.references :user  # Automatically uses :uuid type
  #     t.string :title
  #   end
  #
  # @see RailsUuidPk::UuidAdapterExtension
  # @see RailsUuidPk::Type::Uuid
  # @see https://github.com/trilogy-libraries/trilogy
  module TrilogyAdapterExtension
    include RailsUuidPk::UuidAdapterExtension

    # Configures the database connection with UUID type support.
    #
    # @return [void]
    def configure_connection
      super
    end
  end
end
