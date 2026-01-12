# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v1.0.0.html).

## [0.6.0] - 2026-01-12

### Added
- **Support for `add_reference` and `add_belongs_to`**: Migration helpers now automatically handle foreign key types for these methods as well.
- **Performance Caching**: Added primary key lookup caching during migrations to improve performance.

### Changed
- **Improved Migration Helpers**: Enhanced robustness of foreign key type detection by handling more default types (`:bigint`, `:integer`, `nil`).
- **Refactored Railtie**: Unified UUID type registration for SQLite and MySQL, improving code maintainability.
- **Better Initialization**: Improved timing of adapter extensions using `ActiveSupport.on_load`.

## [0.5.0] - 2026-01-10

### Changed
- **Made gem truly zero-configuration**: Removed install generator and concern file
- Simplified installation to just `bundle install` - no generator command needed
- Removed `app/models/concerns/has_uuidv7_primary_key.rb` template and explicit inclusion option
- Updated documentation to reflect simplified zero-config approach
- All functionality now works automatically through Railtie inclusion

### Removed
- Install generator (`rails g rails_uuid_pk:install`)
- Optional concern file for explicit inclusion
- Generator template and associated test cases
- Manual installation steps and configuration options

### Technical Details
- Eliminated generator complexity while maintaining all core functionality
- Streamlined user experience - just add gem to Gemfile and it works
- Removed optional explicit concern inclusion in favor of automatic Railtie-based inclusion
- Updated AGENTS.md and README.md to reflect simplified architecture

## [0.4.0] - 2026-01-10

### Added
- **MySQL 8.0+ support**: Full MySQL compatibility with VARCHAR(36) UUID storage
- MySQL2 adapter extension for native database type mappings
- MySQL-specific type handling and schema dumping support
- Comprehensive MySQL test suite with performance and edge case testing
- CI pipeline support for MySQL 8.0 testing
- Updated documentation to include MySQL setup and compatibility notes

### Changed
- Updated project description to reflect support for PostgreSQL, MySQL, and SQLite
- Enhanced test runner to support all three database adapters
- Updated development environment setup to include MySQL configuration
- Expanded database coverage from 2 to 3 major Rails database adapters

### Technical Details
- Added `lib/rails_uuid_pk/mysql2_adapter_extension.rb` for MySQL adapter integration
- Extended Railtie with MySQL-specific type mappings and adapter detection
- Enhanced migration helpers compatibility with MySQL VARCHAR(36) column detection
- Added MySQL performance testing (bulk operations, concurrent access, memory efficiency)
- Implemented MySQL edge case testing (long table names, special characters)
- Updated CI workflow with MySQL 8.0 service configuration

## [0.3.0] - 2026-01-09

### Added
- Migration helpers that automatically detect and set UUID foreign key types
- Smart `references` method that inspects database schema to determine primary key types
- Automatic UUID type assignment for polymorphic associations when using global UUID primary keys
- Comprehensive test coverage for migration helper functionality

### Changed
- Eliminated need for manual editing of Action Text and Active Storage migrations
- Updated install generator message to reflect automatic foreign key type handling
- Updated README.md to document the improved zero-config experience
- Changed "Zero config after install" status from "Yes (mostly)" to "Yes"

### Removed
- Manual migration editing requirement for Action Text & Active Storage compatibility

## [0.2.0] - 2026-01-07

### Added
- SQLite schema dumping support for UUID primary keys using Ruby format
- Custom UUID type implementation for ActiveRecord type casting and validation
- SQLite3 adapter extension for native UUID database type definitions

### Changed
- Switched SQLite schema format from SQL to Ruby for improved compatibility and standard Rails behavior
- Updated test suite to expect Ruby schema format for SQLite databases

## [0.1.0] - 2026-01-07

### Added
- Initial release with UUIDv7 primary key support for Rails applications
- Automatic UUIDv7 generation using `SecureRandom.uuid_v7`
- Railtie for automatic inclusion in all ActiveRecord models
- Generator for installation and setup
- Support for PostgreSQL and SQLite databases
- Comprehensive test suite
- AGENTS.md file for LLM coding agent guidance
- Development section in README.md with setup and testing instructions
