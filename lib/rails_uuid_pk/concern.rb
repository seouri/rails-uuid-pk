module RailsUuidPk
  module HasUuidv7PrimaryKey
    extend ActiveSupport::Concern

    included do
      before_create :assign_uuidv7_if_needed, if: -> { id.nil? }
    end

    private

    def assign_uuidv7_if_needed
      # Skip if id was already set (manual set, bulk insert with ids, etc)
      return if id.present?

      uuid = SecureRandom.uuid_v7
      RailsUuidPk.log(:debug, "Assigned UUIDv7 #{uuid} to #{self.class.name}")
      self.id = uuid
    end
  end
end
