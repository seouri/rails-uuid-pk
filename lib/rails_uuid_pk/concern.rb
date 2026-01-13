# frozen_string_literal: true

module RailsUuidPk
  # Provides automatic UUIDv7 primary key generation for ActiveRecord models.
  #
  # This concern is automatically included in all ActiveRecord::Base models
  # via the Railtie, requiring no manual configuration. It uses a before_create
  # callback to assign UUIDv7 values to the primary key when the id is nil.
  #
  # @example
  #   class User < ApplicationRecord
  #     # Automatically gets UUIDv7 id on create
  #     # No additional code needed!
  #   end
  #
  # @example Manual ID assignment (overrides automatic generation)
  #   user = User.new(id: "custom-uuid")
  #   user.save # Uses the custom UUID, not auto-generated
  #
  # @see RailsUuidPk::Railtie
  # @see https://www.rfc-editor.org/rfc/rfc9562.html RFC 9562 (UUIDv7)
  module HasUuidv7PrimaryKey
    extend ActiveSupport::Concern

    included do
      before_create :assign_uuidv7_if_needed, if: -> { id.nil? }
    end

    private

    # Assigns a UUIDv7 to the primary key if not already set.
    #
    # This method is called automatically before creating a record if the id is nil.
    # It uses Ruby 3.3+'s SecureRandom.uuid_v7 for cryptographically secure UUID generation.
    #
    # @return [void]
    # @note This method is private and should not be called directly
    def assign_uuidv7_if_needed
      # Skip if id was already set (manual set, bulk insert with ids, etc)
      return if id.present?

      uuid = SecureRandom.uuid_v7
      RailsUuidPk.log(:debug, "Assigned UUIDv7 #{uuid} to #{self.class.name}")
      self.id = uuid
    end
  end
end
