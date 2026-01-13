# Architecture Overview

This document outlines the architectural decisions, design principles, and technical trade-offs made in rails-uuid-pk. It serves as a guide for understanding why certain approaches were chosen and the implications of those decisions.

## Core Design Principles

### Zero-Configuration Philosophy
**Decision**: Automatic integration without explicit configuration
- **Rationale**: Maximize ease of adoption for Rails developers
- **Implementation**: Railtie-based automatic inclusion in `ActiveRecord::Base`
- **Impact**: Just add the gem to Gemfile - no additional setup required

### Database Agnosticism
**Decision**: Support PostgreSQL, MySQL, and SQLite with unified API
- **Rationale**: Enable database portability and CI/testing flexibility
- **Implementation**: Adapter-specific extensions with common interface
- **Impact**: Developers can switch databases without code changes

### App-Level UUID Generation
**Decision**: Generate UUIDs in application code, not database
- **Rationale**: Maximum compatibility across database versions and types
- **Implementation**: `before_create` callback using `SecureRandom.uuid_v7`
- **Trade-offs**: No database-native UUID functions, but universal compatibility

## Architectural Components

### 1. Core Modules

#### Concern (`lib/rails_uuid_pk/concern.rb`)
```ruby
module RailsUuidPk
  module HasUuidv7PrimaryKey
    extend ActiveSupport::Concern

    included do
      before_create :assign_uuidv7_if_needed, if: -> { id.nil? }
    end

    private

    def assign_uuidv7_if_needed
      return if id.present?
      self.id = SecureRandom.uuid_v7
    end
  end
end
```

**Responsibilities**:
- UUIDv7 generation logic
- Defensive programming (only assign if id is nil)
- Hook into ActiveRecord lifecycle

#### Migration Helpers (`lib/rails_uuid_pk/migration_helpers.rb`)
**Responsibilities**:
- Automatic foreign key type detection
- Polymorphic association support
- Schema inspection and caching

#### Custom Type (`lib/rails_uuid_pk/type.rb`)
**Responsibilities**:
- UUID validation and casting
- Schema dumping compatibility
- Rails version awareness

#### Railtie (`lib/rails_uuid_pk/railtie.rb`)
**Responsibilities**:
- Automatic gem integration
- Database adapter extensions
- Generator configuration

### 2. Database Adapter Extensions

#### PostgreSQL (`pg` gem integration)
- Native UUID type support (16 bytes)
- Full database function compatibility
- Optimized for PostgreSQL's UUID handling

#### MySQL (`mysql2` gem integration)
- VARCHAR(36) storage for UUIDs
- Custom type mapping for ActiveRecord
- Compatible with MySQL 8.0+ string handling

#### SQLite (`sqlite3` gem integration)
- VARCHAR(36) storage for UUIDs
- Custom type mapping for ActiveRecord
- Optimized for development and testing

## Key Architectural Decisions

### Decision 1: App-Level vs Database-Level Generation

#### Chosen Approach: App-Level Generation
```ruby
# In application code
before_create :assign_uuidv7_if_needed, if: -> { id.nil? }

def assign_uuidv7_if_needed
  return if id.present?
  self.id = SecureRandom.uuid_v7
end
```

#### Alternative Considered: Database-Level Generation
```sql
-- PostgreSQL native approach
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name VARCHAR(255)
);
```

#### Trade-off Analysis

| Aspect | App-Level | Database-Level |
|--------|-----------|----------------|
| **Compatibility** | Universal (all DBs) | DB-specific functions required |
| **Performance** | Minimal overhead | Potentially faster (no app round-trip) |
| **Testing** | Consistent across environments | Requires DB function setup |
| **Migration** | App manages UUIDs | DB manages UUIDs |
| **Dependencies** | Ruby SecureRandom only | Database extensions/functions |
| **Consistency** | Guaranteed across transactions | Dependent on DB implementation |

#### Rationale for App-Level Choice
1. **Universal Compatibility**: Works with any database without extensions
2. **Testing Simplicity**: Same behavior in development, test, and production
3. **Migration Safety**: UUIDs are assigned before database constraints
4. **Zero Dependencies**: No database-specific setup or extensions required
5. **Performance**: `SecureRandom.uuid_v7` is sufficiently fast for most applications

#### Bulk Operations Limitation
The app-level callback approach has one important limitation: bulk operations bypass ActiveRecord callbacks. This means operations like `Model.import` or `Model.insert_all` won't automatically generate UUIDs. Applications requiring bulk imports must explicitly assign UUIDs:

```ruby
# Manual UUID assignment required for bulk operations
users = [{ name: "Alice", id: SecureRandom.uuid_v7 }, { name: "Bob", id: SecureRandom.uuid_v7 }]
User.insert_all(users) # Bypasses callbacks, requires explicit IDs
```

This is a conscious trade-off for universal compatibility and zero-configuration benefits.

### Decision 2: UUIDv7 vs Other UUID Versions

#### Chosen: UUIDv7 (RFC 9562)
- **Monotonic Ordering**: Time-based ordering reduces index fragmentation
- **Cryptographically Secure**: Uses system CSPRNG for randomness
- **Standard Compliant**: Latest UUID standard with time-based ordering
- **Database Friendly**: Better index locality than random UUIDs

#### Alternatives Considered
- **UUIDv4**: Random, maximum unpredictability, poor index performance
- **UUIDv1**: MAC address based, privacy concerns, time-ordered
- **Sequential IDs**: Auto-increment, predictable, good performance but security issues

#### UUIDv7 Advantages for Rails Applications
1. **Index Performance**: Monotonic ordering improves B-tree efficiency
2. **Audit Capabilities**: Time-based ordering enables temporal queries
3. **Security**: Cryptographically secure generation
4. **Standards Compliance**: RFC 9562 adherence

### Decision 3: Railtie-Based Integration

#### Chosen: Automatic Railtie Integration
```ruby
# lib/rails_uuid_pk/railtie.rb
module RailsUuidPk
  class Railtie < ::Rails::Railtie
    initializer "rails_uuid_pk.configure" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.include HasUuidv7PrimaryKey
      end
    end
  end
end
```

#### Benefits
- **Zero Configuration**: Works immediately after bundle install
- **Convention over Configuration**: Follows Rails patterns
- **Backwards Compatible**: Doesn't break existing applications
- **Automatic**: No manual model changes required

#### Alternative: Explicit Inclusion
```ruby
# Would require developers to add to each model
class User < ApplicationRecord
  include RailsUuidPk::HasUuidv7PrimaryKey
end
```

### Decision 4: Database Adapter Extension Pattern

#### Chosen: Individual Adapter Extensions
```ruby
# lib/rails_uuid_pk/postgresql_adapter_extension.rb
module RailsUuidPk
  module PostgreSQLAdapterExtension
    def native_database_types
      super.merge(uuid: { name: "uuid" })
    end
  end
end

# lib/rails_uuid_pk/mysql2_adapter_extension.rb
module RailsUuidPk
  module Mysql2AdapterExtension
    def native_database_types
      super.merge(uuid: { name: "varchar", limit: 36 })
    end
  end
end
```

#### Benefits
- **Database-Specific Optimization**: Each database gets appropriate handling
- **Clean Separation**: Adapter concerns are isolated
- **Extensible**: Easy to add new database support
- **Testable**: Each adapter can be tested independently

## Migration Performance Implications

### Schema Inspection Caching
```ruby
# lib/rails_uuid_pk/migration_helpers.rb
def uuid_primary_key?(table_name)
  @uuid_pk_cache ||= {}
  return @uuid_pk_cache[table_name] if @uuid_pk_cache.key?(table_name)

  # Database schema inspection
  conn = connection
  pk_column = find_primary_key_column(table_name, conn)
  @uuid_pk_cache[table_name] = !!(pk_column && pk_column.sql_type =~ /uuid|varchar\(36\)/)
end
```

**Performance Impact**:
- **Caching**: Reduces database queries during migrations
- **Memory**: Small memory footprint for cache
- **Accuracy**: Cache is per-migration instance, ensuring freshness

### Foreign Key Type Detection
```ruby
def references(*args, **options)
  ref_name = args.first
  ref_table = options.delete(:to_table) || ref_name.to_s.pluralize

  # Automatic type detection
  if uuid_primary_key?(ref_table)
    options[:type] = :uuid
  end

  super(*args, **options)
end
```

**Benefits**:
- **Automatic**: No manual foreign key type specification
- **Correct**: Ensures type consistency across relationships
- **Polymorphic**: Handles complex association scenarios

## Database Replication and Backup Considerations

### Replication Compatibility
- **UUID Generation**: App-level generation is replication-safe
- **No Conflicts**: UUIDs are globally unique by design
- **Ordering**: Time-based UUIDs maintain logical ordering across replicas

### Backup and Restore
- **Data Integrity**: UUIDs remain valid across backup/restore cycles
- **References**: Foreign key relationships preserved
- **Consistency**: No auto-increment conflicts or renumbering issues

### Multi-Region Deployments
- **Global Uniqueness**: UUIDs work across geographically distributed systems
- **Conflict Resolution**: No primary key conflicts in multi-master setups
- **Audit Trails**: Time-based UUIDs enable global event ordering

## ORM and Query Builder Impact

### ActiveRecord Integration
- **Seamless**: Works with all ActiveRecord features
- **Associations**: Supports belongs_to, has_many, has_one relationships
- **Validations**: Compatible with all Rails validations
- **Callbacks**: Integrates with Rails callback system

### Query Performance
- **Index Usage**: Leverages database indexes effectively
- **Range Queries**: UUIDv7 enables efficient time-based queries
- **Join Performance**: Foreign key relationships perform well
- **Batch Operations**: Compatible with find_each, find_in_batches

### Development Experience
- **No Code Changes**: Existing Rails code works unchanged
- **Migration Helpers**: Automatic foreign key type detection
- **Schema Dumping**: Compatible with Rails schema tools
- **Testing**: Works with all Rails testing frameworks

## Error Handling and Resilience

### Database Connection Failures
```ruby
def uuid_primary_key?(table_name)
  conn = connection
  return false unless conn.respond_to?(:table_exists?) && conn.table_exists?(table_name)

  # Graceful fallback on errors
  pk_column = find_primary_key_column(table_name, conn)
  !!(pk_column && pk_column.sql_type =~ /uuid|varchar\(36\)/)
rescue => e
  # Log warning and return false on connection errors
  Rails.logger.warn "rails-uuid-pk: Could not check table #{table_name}: #{e.message}"
  false
end
```

### Schema Inconsistencies
- **Defensive Programming**: Handles missing tables gracefully
- **Type Safety**: Validates UUID format before database operations
- **Migration Safety**: Works during schema changes and rollbacks

## Future Evolution Considerations

### Extensibility Points
- **Configuration System**: Planned configuration options for customization
- **Plugin Architecture**: Extensible adapter system for new databases
- **Performance Monitoring**: Optional telemetry and metrics collection

### Migration Path
- **Backwards Compatibility**: Current design supports gradual migration
- **Version Pinning**: Semantic versioning for breaking changes
- **Deprecation Warnings**: Clear communication of deprecated features

### Performance Optimizations
- **Native Database Functions**: Future option for database-level generation
- **Bulk Operations**: Optimized handling for large data imports
- **Index Strategies**: Advanced indexing recommendations

## Conclusion

The rails-uuid-pk architecture prioritizes **compatibility**, **simplicity**, and **performance** while maintaining **security** and **reliability**. Key decisions like app-level UUID generation and Railtie-based integration enable the zero-configuration experience while ensuring robust operation across diverse Rails applications and database environments.

The architecture successfully balances competing concerns:
- **Developer Experience**: Zero-configuration adoption
- **Database Compatibility**: Works across PostgreSQL, MySQL, and SQLite
- **Performance**: UUIDv7 provides better characteristics than alternatives
- **Maintainability**: Clean, modular design with clear separation of concerns
- **Future-Proofing**: Extensible architecture for ongoing evolution

This architectural foundation enables rails-uuid-pk to serve as a reliable, production-ready solution for UUID primary keys in Rails applications.
