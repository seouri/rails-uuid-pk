# rails-uuid-pk

**Dead-simple UUIDv7 primary keys for modern Rails apps**

Automatically use UUID v7 for **all primary keys** in Rails applications. Works with PostgreSQL, MySQL, and SQLite — **zero configuration required**. Just add the gem and you're done!

[![Gem Version](https://img.shields.io/gem/v/rails-uuid-pk.svg?style=flat-square)](https://rubygems.org/gems/rails-uuid-pk)
[![Ruby](https://img.shields.io/badge/ruby-≥3.3-red.svg?style=flat-square)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/rails-≥8.1-9650f9.svg?style=flat-square)](https://rubyonrails.org)
[![CI](https://img.shields.io/github/actions/workflow/status/seouri/rails-uuid-pk/ci.yml?branch=main&style=flat-square)](https://github.com/seouri/rails-uuid-pk/actions)

## Why this gem?

- Uses **native** `SecureRandom.uuid_v7` (Ruby 3.3+)
- Automatically sets `:uuid` as default primary key type
- Adds reliable `before_create` callback for UUIDv7 generation
- Works perfectly on **PostgreSQL 18+**, **MySQL 8.0+**, and **SQLite** (and older versions too)
- **PostgreSQL**: Uses native `UUID` column types with full database support
- **MySQL**: Uses `VARCHAR(36)` with custom ActiveRecord type handling
- **SQLite**: Uses `VARCHAR(36)` with custom ActiveRecord type handling
- Zero database extensions needed
- Minimal and maintainable — no monkey-patching hell
- Production-ready logging for debugging and monitoring

## Installation

Add to your `Gemfile`:

```ruby
gem "rails-uuid-pk", "~> 0.10"
```

Then run:

```bash
bundle install
```

That's it! The gem automatically enables UUIDv7 primary keys for all your models.

## Usage

After installation, **every new model** you generate will get a `uuid` primary key with automatic UUIDv7 values:

```bash
rails g model User name:string email:string
# → creates id: :uuid with automatic uuidv7 generation
```

That's it! No changes needed in your models.

```ruby
# This works out of the box:
User.create!(name: "Alice")  # ← id is automatically a proper UUIDv7
```

## Important Compatibility Notes

### Action Text & Active Storage

When you install Action Text or Active Storage:

```bash
rails action_text:install
rails active_storage:install
```

The generated migrations seamlessly integrate with UUID primary keys. Rails-uuid-pk's smart migration helpers automatically detect UUID primary keys in referenced tables and set the appropriate `type: :uuid` for foreign keys.

### Polymorphic associations

Polymorphic associations work seamlessly with UUID primary keys. Whether you're using Action Text's `record` references or custom polymorphic associations, the migration helpers automatically detect the parent table's primary key type and set the correct foreign key type.

For example, this migration will automatically use `type: :uuid` when the parent models have UUID primary keys:

```ruby
create_table :comments do |t|
  t.references :commentable, polymorphic: true
end
```

## Features / Trade-offs

| Feature                              | Status          | Notes                                                                 |
|--------------------------------------|-----------------|-----------------------------------------------------------------------|
| UUIDv7 generation                    | Automatic       | Uses `SecureRandom.uuid_v7` (very good randomness + monotonicity)     |
| PostgreSQL 18+ native `uuidv7()`     | Not used        | Fallback approach — more universal, no extensions needed             |
| PostgreSQL support                   | Full            | Native `UUID` column types with full database support                |
| MySQL 8.0+ support                   | Full            | Uses `VARCHAR(36)` with custom ActiveRecord type handling            |
| SQLite support                       | Full            | Uses `VARCHAR(36)` with custom ActiveRecord type handling            |
| Index locality / performance         | Very good       | UUIDv7 is monotonic → almost as good as sequential IDs                |
| Zero config after install            | Yes             | Migration helpers automatically handle foreign key types             |
| Works with Rails 7.1 – 8+            | Yes             | Tested conceptually up to Rails 8.1+                                  |

## Performance Overview

**Generation**: ~10,000 UUIDs/second with cryptographic security and monotonic ordering

| Database | Storage | Index Performance | Notes |
|----------|---------|-------------------|--------|
| **PostgreSQL** | Native UUID (16B) | Excellent | Optimal performance |
| **MySQL** | VARCHAR(36) (36B) | Good | 2.25x storage overhead |
| **SQLite** | VARCHAR(36) (36B) | Good | Good for development |

**Key Advantages**:
- **UUIDv7 outperforms UUIDv4** in most scenarios due to monotonic ordering
- **Better index locality** than random UUIDs with reduced fragmentation
- **Efficient range queries** for time-based data access
- **Production-ready scaling** with proper indexing and monitoring

For comprehensive performance analysis, scaling strategies, and optimization guides, see [PERFORMANCE.md](PERFORMANCE.md).

## Bulk Operations

**Important**: Bulk operations like `Model.import` bypass ActiveRecord callbacks, so UUIDs won't be automatically generated for bulk-inserted records. Use explicit UUID assignment or a custom bulk import method if needed.

```ruby
# Manual UUID assignment for bulk operations
users = [{ name: "Alice", id: SecureRandom.uuid_v7 }, { name: "Bob", id: SecureRandom.uuid_v7 }]
User.insert_all(users) # Bypasses callbacks, requires explicit IDs
```

## Why not use native PostgreSQL `uuidv7()`?

While PostgreSQL 18+ has excellent native `uuidv7()` support, the **fallback approach** was chosen for maximum compatibility:

- Works on SQLite without changes
- Works on older PostgreSQL versions
- No need to manage database extensions
- Zero risk when switching databases or in CI/test environments

You can still add native PostgreSQL defaults manually if you want maximum performance — the gem's fallback is safe and will simply be ignored.

## Development

### Devcontainer Setup

This project includes a devcontainer configuration for VS Code (highly recommended, as it automatically sets up Ruby 3.3, Rails, PostgreSQL, MySQL, and SQLite in an isolated environment). To get started:

1. Open the project in VS Code
2. When prompted, click "Reopen in Container" (or run `Dev Containers: Reopen in Container` from the command palette)
3. The devcontainer will set up Ruby 3.3, Rails, and all dependencies automatically

#### Devcontainer CLI

For terminal-based development or automation, you can use the Devcontainer CLI. The devcontainer will be built and started automatically when you run the exec commands.

##### Installation

- **MacOS**: `brew install devcontainer`
- **Other systems**: `npm install -g @devcontainers/cli`

##### Usage

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

### Running Tests

The project includes a comprehensive test suite that runs against SQLite, PostgreSQL, and MySQL.

```bash
# Run all tests (SQLite + PostgreSQL + MySQL)
./bin/test

# Run tests with coverage reporting
./bin/coverage

# Run performance benchmarks
./bin/benchmark

# Run tests for specific database
DB=sqlite ./bin/test      # SQLite only
DB=postgres ./bin/test    # PostgreSQL only
DB=mysql ./bin/test       # MySQL only

# Run specific test file
./bin/test test/uuid/generation_test.rb

# Run specific test file with specific database
DB=sqlite ./bin/test test/uuid/type_test.rb

# Run multiple specific test files
./bin/test test/uuid/generation_test.rb test/uuid/type_test.rb
```

### Code Quality

```bash
# Run RuboCop for style checking
./bin/rubocop

# Auto-fix RuboCop offenses
./bin/rubocop -a
```

### Building the Gem

```bash
# Build the gem
gem build rails_uuid_pk.gemspec

# Install locally for testing
gem install rails-uuid-pk-0.10.0.gem
```

### Database Setup

For database testing, ensure the respective databases are running and accessible. The test suite uses these environment variables:
- `DB_HOST` (defaults to localhost)
- `RAILS_ENV=test_postgresql` for PostgreSQL tests
- `RAILS_ENV=test_mysql` for MySQL tests

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seouri/rails-uuid-pk.

Please see our [Security Policy](SECURITY.md) for information about reporting security vulnerabilities.

For detailed architecture documentation, design decisions, and technical rationale, see [ARCHITECTURE.md](ARCHITECTURE.md).

## License

The gem is available as open source under the terms of the [MIT License](MIT-LICENSE).
