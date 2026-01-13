require "rails_uuid_pk/version"
require "rails_uuid_pk/concern"
require "rails_uuid_pk/type"
require "rails_uuid_pk/sqlite3_adapter_extension"
require "rails_uuid_pk/mysql2_adapter_extension"
require "rails_uuid_pk/railtie"

module RailsUuidPk
  LOG_PREFIX = "[RailsUuidPk]"

  def self.logger
    @logger ||= defined?(Rails.logger) ? Rails.logger : Logger.new($stdout)
  end

  def self.log(level, message)
    logger.send(level, "#{LOG_PREFIX} #{message}")
  end
end
