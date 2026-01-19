# rails-uuid-pk

**Dead-simple UUIDv7 primary keys for modern Rails apps**

Automatically use UUID v7 for **all primary keys** in Rails applications. Works with PostgreSQL, MySQL, and SQLite — **zero configuration required**. Just add the gem and you're done!

[![Gem Version](https://img.shields.io/gem/v/rails-uuid-pk.svg?style=flat-square)](https://rubygems.org/gems/rails-uuid-pk)
[![Ruby](https://img.shields.io/badge/ruby-≥3.3-red.svg?style=flat-square)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/rails-≥8.1-9650f9.svg?style=flat-square)](https://rubyonrails.org)
[![CI](https://img.shields.io/github/actions/workflow/status/seouri/rails-uuid-pk/ci.yml?branch=main&style=flat-square)](https://github.com/seouri/rails-uuid-pk/actions)

## Why this gem?

- **Assumes UUIDv7 primary keys by default** for all models - just add the gem and you're done!
- Uses **native** `SecureRandom.uuid_v7` (Ruby 3.3+)
- Automatically sets `:uuid` as default primary key type
- Works perfectly on PostgreSQL, MySQL, and SQLite
- Zero database extensions needed
- Production-ready logging for debugging and monitoring

## Installation

Add to your `Gemfile`:

```ruby
gem "rails-uuid-pk", "~> 0.13"
```

Then run:

```bash
bundle install
```

That's it! The gem automatically enables UUIDv7 primary keys for all your models.

## Usage

**By default, all models use UUIDv7 primary keys.** After installation, every new model automatically gets a `uuid` primary key with UUIDv7 values:

```bash
rails g model User name:string email:string
# → creates id: :uuid with automatic uuidv7 generation
```

```ruby
# This works out of the box:
User.create!(name: "Alice")  # ← id is automatically a proper UUIDv7
```

### Exception: Opting Out of UUID Primary Keys

For **exceptional cases** where you need integer primary keys (legacy tables, third-party integrations, etc.), you can explicitly opt out:

```ruby
class LegacyModel < ApplicationRecord
  use_integer_primary_key  # Exception: this model uses integer PKs instead
end

# Migration must also specify :integer for the table
create_table :legacy_models, id: :integer do |t|
  t.string :name
end
```

**Migration helpers automatically detect mixed primary key types** and set appropriate foreign key types:

```ruby
# Rails will automatically use the correct foreign key types
create_table :related_records do |t|
  t.references :legacy_model, null: false  # → integer foreign key (LegacyModel uses integers)
  t.references :user, null: false          # → UUID foreign key (User uses UUIDs by default)
end
```

## Important Compatibility Notes

### Action Text & Active Storage

When installing Action Text or Active Storage, migrations automatically integrate with UUID primary keys - no changes needed.

### Polymorphic associations

Polymorphic associations work seamlessly with UUID primary keys. Foreign key types are automatically detected.

## Performance & Architecture

UUIDv7 provides excellent performance with monotonic ordering and reduced index fragmentation compared to UUIDv4.

- **Generation**: ~800,000 UUIDs/second with cryptographic security
- **Storage**: Native UUID (16B) on PostgreSQL, VARCHAR(36) on MySQL/SQLite
- **Index Performance**: Better locality than random UUIDs

For detailed performance analysis and optimization guides, see [PERFORMANCE.md](PERFORMANCE.md).

For architecture decisions and design rationale, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for setup instructions, testing, and contribution guidelines.

## Security

For security considerations and vulnerability reporting, see [SECURITY.md](SECURITY.md).

## Contributing

Bug reports and pull requests welcome on GitHub. See [DEVELOPMENT.md](DEVELOPMENT.md) for contribution guidelines.

## License

MIT License - see [MIT-LICENSE](MIT-LICENSE) for details.
