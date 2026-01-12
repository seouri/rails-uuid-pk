# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v1.0.0.html).

## [0.8.0] - 2026-01-12

### Changed
- **Refactored UUID Type Registration**: Moved from global type map registration to connection-specific registration for improved precision and database compatibility
- **Enhanced Type Mapping Precision**: UUID types now only map to specific `varchar(36)` and `uuid` SQL types, preventing hijacking of standard string columns
- **Improved Adapter Extensions**: Enhanced MySQL and SQLite adapter extensions with dedicated `register_uuid_types` methods and proper initialization hooks

### Added
- **String Column Protection Test**: Added test to ensure standard string columns are not incorrectly mapped to UUID type

### Technical Details
- Updated Railtie to use `ActiveSupport.on_load` hooks for cleaner adapter extension prepending
- Implemented connection-aware UUID type registration during adapter initialization and connection setup
- Enhanced migration helpers compatibility and type detection robustness

## [0.7.0] - 2026-01-12

### Added
- **SECURITY.md**: Comprehensive security documentation covering UUIDv7-specific security considerations
  - Cryptographic security analysis with timestamp exposure details
  - Database security implications and foreign key considerations
  - Performance-security trade-offs analysis
  - Security vulnerability reporting process
  - Side-channel attack vectors and mitigation strategies
  - Compliance considerations (GDPR, HIPAA, etc.)
  - Security testing recommendations and monitoring guidelines
- **ARCHITECTURE.md**: Comprehensive architecture documentation
  - Core design principles and architectural decisions
  - App-level vs database-level UUID generation analysis
  - Database compatibility rationale and trade-offs
  - Migration performance implications and caching strategies
  - Database replication and backup considerations
  - ORM and query builder integration details
  - Error handling and resilience patterns
  - Future evolution and extensibility points
- **PERFORMANCE.md**: Comprehensive performance documentation in dedicated file
  - UUID generation throughput metrics and cryptographic security details
  - Database-specific performance characteristics (PostgreSQL, MySQL, SQLite)
  - Index performance analysis comparing 36-byte UUIDs vs 4-byte integers
  - Scaling recommendations for tables of different sizes (<1M, 1M-10M, >10M records)
  - UUIDv7 vs UUIDv4 performance trade-offs with detailed comparison tables
  - Index fragmentation and cache locality analysis
  - Production monitoring and optimization guidelines
- **README.md**: Streamlined with concise performance overview and link to PERFORMANCE.md
- **Comprehensive UUIDv7 Correctness Testing**: Added extensive test suite validating UUIDv7 compliance
  - RFC 9562 version and variant bits validation
  - Timestamp monotonicity and collision resistance testing
  - Format consistency and edge case handling
  - Statistical randomness quality analysis
  - Cross-database compatibility verification

### Changed
- **Schema Dumper Compatibility**: Replaced fragile `caller` detection with Rails version-aware schema type handling
  - Rails 8.1+: Uses `:uuid` type in schema dumps for native UUID support
  - Rails 8.0.x: Uses `:string` type to avoid "Unknown type 'uuid'" errors
  - Future-proof design that adapts to Rails version changes
  - Added comprehensive test coverage for schema dumping behavior

### Fixed
- **Schema Dumping Fragility**: Eliminated dependency on Rails internal `caller` stack inspection
- **Rails Version Compatibility**: Robust handling of UUID types across different Rails versions

### Security
- Enhanced security posture with professional security documentation
- Clear vulnerability disclosure process for responsible reporting
- UUID-specific security guidance for enterprise adoption

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
