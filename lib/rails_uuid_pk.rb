# frozen_string_literal: true

require "rails_uuid_pk/version"
require "rails_uuid_pk/concern"
require "rails_uuid_pk/type"
require "rails_uuid_pk/uuid_adapter_extension"
require "rails_uuid_pk/sqlite3_adapter_extension"
require "rails_uuid_pk/mysql2_adapter_extension"
require "rails_uuid_pk/trilogy_adapter_extension"
require "rails_uuid_pk/railtie"

# Load generators
require "generators/rails_uuid_pk/add_opt_outs_generator" if defined?(Rails::Generators)

# Rails UUID Primary Key
#
# A Rails gem that automatically uses UUIDv7 for all primary keys in Rails applications.
# This gem provides seamless integration with Rails generators, automatic UUIDv7 generation,
# and support for PostgreSQL, MySQL, and SQLite databases.
#
# @example Installation
#   # Add to Gemfile
#   gem 'rails-uuid-pk'
#
#   # All models automatically get UUIDv7 primary keys
#   class User < ApplicationRecord
#     # id will be automatically assigned a UUIDv7 on create
#   end
#
# @example Migration with foreign keys
#   # Foreign key types are automatically detected
#   create_table :posts do |t|
#     t.references :user, null: false  # Automatically uses :uuid type
#     t.string :title
#   end
#
# @see RailsUuidPk::HasUuidv7PrimaryKey
# @see RailsUuidPk::Railtie
# @see https://github.com/seouri/rails-uuid-pk
module RailsUuidPk
  # The prefix used for all log messages.
  #
  # @return [String] The log message prefix
  LOG_PREFIX = "[RailsUuidPk]"

  # Returns the logger instance for this gem.
  #
  # Uses Rails.logger if available and not nil, otherwise creates a new Logger instance.
  #
  # @return [Logger] The logger instance
  # @example
  #   RailsUuidPk.logger.info("Custom message")
  def self.logger
    @logger ||= ((defined?(Rails.logger) && Rails.logger) || Logger.new($stdout))
    @logger = Logger.new($stdout) unless @logger.is_a?(Logger)
    @logger
  end

  # Sets the logger instance for this gem.
  #
  # @param logger [Logger] The logger instance to use
  # @example
  #   RailsUuidPk.logger = Rails.logger
  def self.logger=(logger)
    @logger = logger
  end

  # Logs a message at the specified level.
  #
  # @param level [Symbol] The log level (:debug, :info, :warn, :error, :fatal)
  # @param message [String] The message to log
  # @example
  #   RailsUuidPk.log(:info, "UUID assigned successfully")
  def self.log(level, message)
    logger.send(level, "#{LOG_PREFIX} #{message}")
  end
end
