# rails-uuid-pk

**Dead-simple UUIDv7 primary keys for modern Rails apps**  
Works great with **PostgreSQL 18+**, **MySQL 8.0+**, and **SQLite 3.51+** — zero extra extensions required.

[![Gem Version](https://img.shields.io/gem/v/rails-uuid-pk.svg?style=flat-square)](https://rubygems.org/gems/rails-uuid-pk)
[![Ruby](https://img.shields.io/badge/ruby-≥3.3-red.svg?style=flat-square)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/rails-≥8.1-9650f9.svg?style=flat-square)](https://rubyonrails.org)

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

## Installation

Add to your `Gemfile`:

```ruby
gem "rails-uuid-pk", "~> 0.3"
```

Then run:

```bash
bundle install
rails generate rails_uuid_pk:install
```

The generator will:

- Set `primary_key_type: :uuid` in your generators config
- Create `app/models/concerns/has_uuidv7_primary_key.rb` (optional explicit include)
- Show important compatibility notes

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

When you run:

```bash
rails action_text:install
rails active_storage:install
```

The generated migrations will **automatically use the correct foreign key types** when referencing tables with UUID primary keys. No manual editing required!

This works because rails-uuid-pk includes smart migration helpers that detect the primary key type of referenced tables and automatically set `type: :uuid` for foreign keys.

### Polymorphic associations

**Polymorphic associations** (like Action Text's `record` references) will automatically use the correct foreign key type based on the referenced table's primary key. If the parent model uses UUID primary keys, the foreign key will be UUID type.

For **custom polymorphic associations**, the migration helpers will also automatically detect and set the correct type:

```ruby
# This will automatically use type: :uuid if the parent models have UUID primary keys
create_table :comments do |t|
  t.references :commentable, polymorphic: true
end
```

No manual `type: :uuid` specification needed!

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

## Why not use native PostgreSQL `uuidv7()`?

While PostgreSQL 18+ has excellent native `uuidv7()` support, the **fallback approach** was chosen for maximum compatibility:

- Works on SQLite without changes
- Works on older PostgreSQL versions
- No need to manage database extensions
- Zero risk when switching databases or in CI/test environments

You can still add native PostgreSQL defaults manually if you want maximum performance — the gem's fallback is safe and will simply be ignored.

## Development

### Devcontainer Setup

This project includes a devcontainer configuration for VS Code. To get started:

1. Open the project in VS Code
2. When prompted, click "Reopen in Container" (or run `Dev Containers: Reopen in Container` from the command palette)
3. The devcontainer will set up Ruby 3.3, Rails, and all dependencies automatically

### Running Tests

The project includes a comprehensive test suite that runs against SQLite, PostgreSQL, and MySQL.

```bash
# Run all tests (SQLite + PostgreSQL + MySQL)
./bin/test

# Run tests for specific database
DB=sqlite ./bin/test      # SQLite only
DB=postgres ./bin/test    # PostgreSQL only
DB=mysql ./bin/test       # MySQL only
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
gem install rails-uuid-pk-0.1.0.gem
```

### Database Setup

For database testing, ensure the respective databases are running and accessible. The test suite uses these environment variables:
- `DB_HOST` (defaults to localhost)
- `RAILS_ENV=test_postgresql` for PostgreSQL tests
- `RAILS_ENV=test_mysql` for MySQL tests

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seouri/rails-uuid-pk.

## License

The gem is available as open source under the terms of the [MIT License](MIT-LICENSE).
