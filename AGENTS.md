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

2. **Access the devcontainer** for command execution:
   ```bash
   # Execute commands inside the running devcontainer
   devcontainer exec --workspace-folder /workspaces/rails-uuid-pk bundle install

   # Run tests
   devcontainer exec --workspace-folder /workspaces/rails-uuid-pk ./bin/test

   # Run code quality checks
   devcontainer exec --workspace-folder /workspaces/rails-uuid-pk ./bin/rubocop

   # Interactive shell access
   devcontainer exec --workspace-folder /workspaces/rails-uuid-pk bash
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
- **Always specify workspace folder**: Use `--workspace-folder /workspaces/rails-uuid-pk` to ensure correct container context
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
5. **Run tests**: Ensure all tests pass (`./bin/test`)
6. **Code quality**: Run RuboCop (`./bin/rubocop`)
7. **Update documentation**: README, CHANGELOG if needed

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
