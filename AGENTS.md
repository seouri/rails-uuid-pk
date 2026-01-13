# rails-uuid-pk - Agent Development Guide

This guide helps LLM coding agents understand and contribute to the rails-uuid-pk gem effectively.

## Project Overview

**rails-uuid-pk** is a Ruby gem that automatically uses UUIDv7 for all primary keys in Ruby on Rails applications. It provides seamless integration with Rails generators, automatic UUIDv7 generation, and support for PostgreSQL, MySQL, and SQLite databases.

### Key Features
- Automatic UUIDv7 primary key generation using Ruby 3.3+ `SecureRandom.uuid_v7`
- Smart migration helpers that automatically detect and set UUID foreign key types
- Railtie-based automatic inclusion in all ActiveRecord models
- Database-agnostic design (PostgreSQL, MySQL, and SQLite)
- Truly zero-configuration - just add to Gemfile
- Comprehensive test suite

## Development Environment

### Prerequisites
- Ruby 3.3.0+
- Rails 8.0+
- PostgreSQL (optional, for testing)
- MySQL 8.0+ (optional, for testing)
- SQLite3 (included with Ruby)

### Quick Start
1. Clone the repository
2. Run `bundle install`
3. Use `./bin/test` to run the full test suite
4. Use `./bin/rubocop` for code quality checks

### Terminal-based AI Agents

For AI coding agents that operate via command-line interfaces (such as Gemini CLI, Claude Code, or similar tools) and need to access the devcontainer environment from the host system:

#### Devcontainer CLI Setup
1. **Install Devcontainer CLI** on your host system:
   ```bash
   npm install -g @devcontainers/cli
   ```

2. **Access the devcontainer** for command execution (run from project root):
   ```bash
   # Execute commands inside the running devcontainer
   devcontainer exec --workspace-folder . bundle install

   # Run tests
   devcontainer exec --workspace-folder . ./bin/test

   # Run code quality checks
   devcontainer exec --workspace-folder . ./bin/rubocop

   # Interactive shell access
   devcontainer exec --workspace-folder . bash
   ```

#### Alternative Access Methods
If Devcontainer CLI is not available, you can also access via Docker directly:

```bash
# Find the devcontainer
docker ps | grep devcontainer

# Execute commands in the container
docker exec -it <container-id> ./bin/test
```

#### Best Practices for Terminal Agents
- **Always specify workspace folder**: Use `--workspace-folder .` to ensure correct container context
- **Sequential execution**: Run commands one at a time and wait for completion
- **Environment awareness**: Be aware that file paths and environment variables may differ between host and container
- **Use project scripts**: Prefer `./bin/test` and `./bin/rubocop` over direct `bundle exec` commands for consistency

## Project Structure

```
rails-uuid-pk/
├── lib/                          # Main gem code
│   ├── rails_uuid_pk.rb          # Main module
│   ├── rails_uuid_pk/            # Core functionality
│   │   ├── concern.rb            # UUIDv7 generation concern
│   │   ├── migration_helpers.rb  # Smart foreign key type detection
│   │   ├── railtie.rb            # Rails integration
│   │   └── version.rb            # Version info
│   └── generators/               # Rails generators (removed - gem is now zero-config)
├── test/                         # Test suite
│   ├── dummy/                    # Rails dummy app for testing
│   ├── rails_uuid_pk_test.rb     # Main test file
│   └── test_helper.rb            # Test configuration
├── bin/                          # Executable scripts
│   ├── test                      # Test runner
│   └── rubocop                   # Code quality checker
├── .github/workflows/ci.yml      # CI configuration
├── rails_uuid_pk.gemspec         # Gem specification
├── ARCHITECTURE.md               # Architectural decisions and design rationale
├── SECURITY.md                   # Security policy and considerations
├── PERFORMANCE.md                # Detailed performance analysis and optimization
└── README.md                     # User documentation
```

## Code Architecture

### Core Components

1. **Concern (`lib/rails_uuid_pk/concern.rb`)**:
   - `HasUuidv7PrimaryKey` module
   - `before_create` callback for UUID generation
   - Uses `SecureRandom.uuid_v7` for reliable UUIDv7 creation

2. **MigrationHelpers (`lib/rails_uuid_pk/migration_helpers.rb`)**:
   - `References` module that extends ActiveRecord migration methods
   - Automatically detects UUID primary keys in referenced tables
   - Sets appropriate foreign key types (`:uuid` vs `:integer`)
   - Handles both regular and polymorphic associations
   - Respects explicitly set user types

3. **Railtie (`lib/rails_uuid_pk/railtie.rb`)**:
   - Automatic inclusion in `ActiveRecord::Base`
   - Generator configuration (`primary_key_type: :uuid`)
   - Database-specific configurations (SQLite schema format, type mappings)
   - Includes migration helpers in ActiveRecord migration classes

4. **Logging Framework (`lib/rails_uuid_pk.rb`)**:
   - `RailsUuidPk.logger` and `RailsUuidPk.log` methods for structured logging
   - Integrates with Rails logger for production debugging and monitoring
   - Debug logging for UUID assignment, migration helpers, and adapter registration
   - Production-ready logging with configurable levels and log aggregation support

### Key Design Decisions

- **Railtie-based inclusion**: Automatic integration without requiring model changes
- **Database agnostic**: Works with PostgreSQL, MySQL, and SQLite
- **Fallback approach**: App-side generation instead of native DB functions for compatibility
- **Minimal API**: Zero-configuration after installation

## Testing Strategy

### Test Organization
- **Unit tests**: Core functionality in `test/rails_uuid_pk_test.rb`
- **Integration tests**: Full Rails app testing via dummy app
- **Database coverage**: Tests run against SQLite, PostgreSQL, and MySQL
- **CI coverage**: GitHub Actions runs all tests on multiple Ruby versions

### Running Tests
```bash
# All tests (SQLite + PostgreSQL + MySQL)
./bin/test

# Specific database
DB=sqlite ./bin/test
DB=postgres ./bin/test
DB=mysql ./bin/test

# Rails test suite (from test/dummy/)
cd test/dummy && rails test
```

### Test Database Setup
- SQLite: Automatic, no setup required
- PostgreSQL: Requires running PostgreSQL instance with test database
- MySQL: Requires running MySQL 8.0+ instance with test database

## Coding Conventions

### Ruby Style
- Follows RuboCop configuration (`.rubocop.yml`)
- Standard Ruby naming conventions
- 2-space indentation
- Line length: 120 characters

### Rails Patterns
- Uses ActiveSupport::Concern for mixins
- Railtie for Rails integration
- Standard Rails generator structure
- Follows Rails testing conventions

### Code Quality
- **RuboCop**: Enforced via CI
- **No monkey-patching**: Clean integration approach
- **Comprehensive tests**: High test coverage
- **Documentation**: README and inline comments

## Development Workflow

### For AI Agents

1. **Understand the problem**: Read issue/PR description and existing code
2. **Check existing patterns**: Review similar functionality in the codebase
3. **Write tests first**: Add tests for new features/fixes
4. **Implement changes**: Follow existing code patterns
5. **Update YARD documentation**: Add/update YARD comments for any new/modified code
6. **Run tests**: Ensure all tests pass (`./bin/test`)
7. **Code quality**: Run RuboCop (`./bin/rubocop`)
8. **Verify documentation**: Run `yard doc lib/` to ensure 100% documentation coverage
9. **Update documentation**: README, CHANGELOG if needed

### YARD Documentation Guidelines

**Always update YARD documentation when making code changes:**

#### When Adding New Code
```ruby
# For new modules/classes
# @example Usage example
#   MyClass.new.do_something
class MyClass
  # @param param [Type] Description of parameter
  # @return [ReturnType] Description of return value
  def my_method(param)
    # implementation
  end
end
```

#### When Modifying Existing Code
- **Update method descriptions** if behavior changes
- **Add/modify parameter documentation** (`@param`) for new/changed parameters
- **Update return types** (`@return`) if they change
- **Add examples** (`@example`) for complex functionality
- **Update `@see` references** for related components

#### Required YARD Tags
- `@param [Type] description` - For all method parameters
- `@return [Type] description` - For all return values (use `[void]` for no return)
- `@example` - Code examples showing usage
- `@see ClassName` - Cross-references to related classes/modules
- `@note` - Important implementation notes

#### Verification Steps
```bash
# Generate documentation and check coverage
yard doc lib/

# Expected output should show:
# Files:           8
# Modules:         7 (    0 undocumented)
# Classes:         2 (    0 undocumented)
# Constants:       2 (    0 undocumented)
# Methods:        19 (    0 undocumented)
# 100.00% documented
```

#### Best Practices
- **Keep examples realistic** and runnable
- **Document edge cases** and error conditions
- **Use consistent parameter naming** in examples
- **Reference RFCs/specs** for standards compliance (e.g., UUIDv7)
- **Document Rails version specifics** when applicable
- **Include performance implications** for complex operations

### Common Tasks

#### Adding New Features
1. Determine if it affects core concern, railtie, or generator
2. Add tests in `test/rails_uuid_pk_test.rb`
3. Implement in appropriate module
4. Update README if user-facing

#### Database Compatibility
1. Test changes with both SQLite and PostgreSQL
2. Update type mappings in railtie if needed
3. Consider schema format implications

#### Generator Changes
1. Modify templates in `lib/generators/rails_uuid_pk/install/templates/`
2. Update generator logic in `install_generator.rb`
3. Test generator output

#### Migration Helpers
1. Modify `lib/rails_uuid_pk/migration_helpers.rb` for foreign key type detection logic
2. Add comprehensive tests in `test/rails_uuid_pk_test.rb` for all scenarios:
   - References to existing UUID tables
   - References to non-UUID tables
   - Polymorphic associations
   - Explicit type overrides
   - Non-existent table handling
3. Update railtie in `lib/rails_uuid_pk/railtie.rb` if inclusion logic changes
4. Test with both SQLite and PostgreSQL databases

#### Bulk Operations
1. Remember that bulk operations (`Model.import`, `Model.insert_all`) bypass callbacks
2. Explicitly assign UUIDs when using bulk operations to avoid data integrity issues
3. Consider performance implications: bulk operations are faster but require manual UUID management
4. Test bulk operation scenarios to ensure data consistency

## Troubleshooting

### Common Issues

**Tests failing on PostgreSQL**:
- Ensure PostgreSQL is running
- Check `DB_HOST` environment variable
- Verify database credentials in `test/dummy/config/database.yml`

**RuboCop offenses**:
- Run `./bin/rubocop -a` for auto-fixes
- Check `.rubocop.yml` for project-specific rules

**Gem build issues**:
- Ensure all files are included in `rails_uuid_pk.gemspec`
- Check for syntax errors in Ruby files

### Getting Help
- Check existing tests for usage examples
- Review Rails documentation for integration patterns
- Look at similar Rails gems for inspiration

## Contributing Guidelines

- Follow conventional commit messages
- Update CHANGELOG.md for user-facing changes
- Maintain backward compatibility
- Test thoroughly across databases
- Keep the API minimal and focused

This guide should help agents understand the codebase and contribute effectively to rails-uuid-pk.
