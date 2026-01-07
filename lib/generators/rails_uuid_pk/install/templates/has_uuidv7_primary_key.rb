# app/models/concerns/has_uuidv7_primary_key.rb
# (this file is copied by the generator - you can modify it later if needed)

module HasUuidv7PrimaryKey
  extend ActiveSupport::Concern

  included do
    before_create :assign_uuidv7_if_needed, if: -> { id.nil? }
  end

  private

  def assign_uuidv7_if_needed
    return if id.present?
    self.id = SecureRandom.uuid_v7
  end
end
