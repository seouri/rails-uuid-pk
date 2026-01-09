# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v1.0.0.html).

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
