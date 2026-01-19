# Development Guide

This guide covers development setup, testing, and contribution guidelines for rails-uuid-pk.

## Devcontainer Setup

This project includes a devcontainer configuration for VS Code (highly recommended, as it automatically sets up Ruby 3.3, Rails, PostgreSQL, MySQL, and SQLite in an isolated environment).

### Quick Start

1. Open the project in VS Code
2. When prompted, click "Reopen in Container" (or run `Dev Containers: Reopen in Container` from the command palette)
3. The devcontainer will set up Ruby 3.3, Rails, and all dependencies automatically

### Devcontainer CLI

For terminal-based development or automation, you can use the Devcontainer CLI. The devcontainer will be built and started automatically when you run the exec commands.

#### Installation

- **MacOS**: `brew install devcontainer`
- **Other systems**: `npm install -g @devcontainers/cli`

#### Usage

Run commands inside the devcontainer:

```bash
# Install dependencies
devcontainer exec --workspace-folder . bundle install

# Run tests
devcontainer exec --workspace-folder . ./bin/test

# Run code quality checks
devcontainer exec --workspace-folder . ./bin/rubocop

# Interactive shell
devcontainer exec --workspace-folder . bash
```



## Code Quality

```bash
# Run RuboCop for style checking
./bin/rubocop

# Auto-fix RuboCop offenses
./bin/rubocop -a
```

## Building the Gem

```bash
# Build the gem
gem build rails_uuid_pk.gemspec

# Install locally for testing
gem install rails-uuid-pk-0.11.0.gem
```

## Database Setup

For database testing, ensure the respective databases are running and accessible. The test suite uses these environment variables:
- `DB_HOST` (defaults to localhost)
- `RAILS_ENV=test_postgresql` for PostgreSQL tests
- `RAILS_ENV=test_mysql` for MySQL tests

## Contributing

### For Contributors

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

### Common Tasks

#### Adding New Features
1. Determine if it affects core concern, railtie, or generator
2. Add tests in the appropriate subdirectory under `test/` (e.g., `test/uuid/`, `test/migration_helpers/`, etc.)
3. Implement in appropriate module
4. Update README if user-facing

#### Database Compatibility
1. Test changes with both SQLite and PostgreSQL
2. Update type mappings in railtie if needed
3. Consider schema format implications

#### Migration Helpers
1. Modify `lib/rails_uuid_pk/migration_helpers.rb` for foreign key type detection logic
2. Add comprehensive tests in `test/migration_helpers/` for all scenarios:
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

#### Opt-out Functionality
1. **Default behavior**: rails-uuid-pk assumes UUIDv7 primary keys for all models by default
2. **Exceptions only**: Use `use_integer_primary_key` class method ONLY for specific models that need integer primary keys (legacy tables, third-party integrations, etc.)
3. When opting out: Modify generated migration to change `id: :uuid` to `id: :integer` for the table schema
4. Migration helpers automatically detect mixed primary key types and set appropriate foreign key types
5. Test mixed scenarios thoroughly when combining UUID and integer primary key models
6. **Inheritance behavior**: Subclasses do NOT automatically inherit the opt-out setting. Each class must explicitly call `use_integer_primary_key`. This is intentional to prevent accidental inheritance in polymorphic hierarchies where different tables may have different primary key types.

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

## Testing Strategy

### Test Organization
- **Unit tests**: Core functionality organized by feature in subdirectories:
  - `test/configuration/`: Configuration and setup tests
  - `test/database_adapters/`: Database-specific adapter tests
  - `test/migration_helpers/`: Migration helper functionality tests
  - `test/uuid/`: UUID generation and type tests
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

# Specific test file
./bin/test test/uuid/generation_test.rb

# Specific test file with specific database
DB=sqlite ./bin/test test/uuid/type_test.rb

# Multiple specific test files
./bin/test test/uuid/generation_test.rb test/uuid/type_test.rb

# Rails test suite (from test/dummy/)
cd test/dummy && rails test
```

### Test Database Setup
- SQLite: Automatic, no setup required
- PostgreSQL: Requires running PostgreSQL instance with test database
- MySQL: Requires running MySQL 8.0+ instance with test database

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

## Project Structure

```
rails-uuid-pk/
├── lib/                          # Main gem code
│   ├── rails_uuid_pk.rb          # Main module
│   ├── rails_uuid_pk/            # Core functionality
│   │   ├── concern.rb            # UUIDv7 generation concern
│   │   ├── migration_helpers.rb  # Smart foreign key type detection
│   │   ├── mysql2_adapter_extension.rb  # MySQL adapter UUID support
│   │   ├── railtie.rb            # Rails integration
│   │   ├── sqlite3_adapter_extension.rb # SQLite adapter UUID support
│   │   ├── type.rb               # Custom UUID ActiveRecord type
│   │   ├── uuid_adapter_extension.rb    # Shared UUID adapter functionality
│   │   └── version.rb            # Version info
│   └── generators/               # Rails generators (removed - gem is now zero-config)
├── test/                         # Test suite
│   ├── configuration/            # Configuration and setup tests
│   ├── database_adapters/        # Database-specific adapter tests
│   ├── dummy/                    # Rails dummy app for testing
│   ├── migration_helpers/        # Migration helper functionality tests
│   └── uuid/                     # UUID generation and type tests
├── bin/                          # Executable scripts
│   ├── benchmark                 # Performance benchmarking
│   ├── coverage                  # Test coverage reporting
│   ├── rubocop                   # Code quality checker
│   └── test                      # Test runner
├── .github/workflows/ci.yml      # CI configuration
├── rails_uuid_pk.gemspec         # Gem specification
├── ARCHITECTURE.md               # Architectural decisions and design rationale
├── SECURITY.md                   # Security policy and considerations
├── PERFORMANCE.md                # Detailed performance analysis and optimization
└── README.md                     # User documentation
