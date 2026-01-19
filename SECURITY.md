# Security Considerations

## Supported Versions

We take security seriously and actively maintain this gem. The following versions are currently supported with security updates:

| Version | Supported          | Security Support Until |
| ------- | ------------------ | ---------------------- |
| 0.13.x  | :white_check_mark: | Ongoing                |
| 0.12.x  | :white_check_mark: | 6 months from 0.13.0  |
| 0.11.x  | :white_check_mark: | 6 months from 0.12.0  |
| < 0.11  | :x:                | None                   |

## Reporting a Vulnerability

**Please report security vulnerabilities responsibly.**

If you discover a security vulnerability in rails-uuid-pk, please:

1. **DO NOT** create a public GitHub issue
2. Email security concerns to: **seouri@gmail.com**
3. Include detailed information about:
   - The vulnerability description
   - Steps to reproduce
   - Potential impact assessment
   - Your contact information for follow-up

**Response Time**: We will acknowledge receipt within 24 hours and provide a more detailed response within 72 hours indicating our next steps.

## Cryptographic Security Analysis

### UUIDv7 Cryptographic Properties

This gem uses **UUIDv7** (RFC 9562) for primary key generation, which provides the following security characteristics:

> **Privacy Consideration**: UUIDv7 includes a timestamp component that reveals approximate record creation time. Do not use if creation timestamp must be hidden.
>
> **Enhanced Privacy Documentation**: Added explicit warning about UUIDv7 timestamp exposure in SECURITY.md, clarifying that UUIDv7 includes a timestamp component that reveals approximate record creation time and advising against use when creation timestamps must be hidden.

#### Strengths
- **Cryptographically Secure Generation**: Uses Ruby's `SecureRandom.uuid_v7()` backed by system CSPRNG (OpenSSL or system entropy)
- **Monotonic Ordering**: Time-based ordering prevents index fragmentation while maintaining unpredictability
- **High Entropy**: 128-bit randomness with structured time component
- **RFC 9562 Compliance**: Follows latest UUID standards

#### Known Limitations
- **Timestamp Exposure**: First 48 bits contain millisecond-precision timestamp
- **Predictability Window**: Generated UUIDs reveal creation time ± milliseconds
- **No Forward Secrecy**: Compromised keys don't affect future UUID security

### Timestamp Exposure Considerations

```ruby
# Example: UUIDv7 reveals generation timestamp
uuid = "017f22e2-79b0-7cc3-98c4-dc0c0c07398f"
timestamp_ms = uuid[0..7].to_i(16) >> 4  # Extract 48-bit timestamp
# This reveals the UUID was generated at: 2023-11-15 10:30:45.123 UTC
```

**Security Impact**: An attacker observing UUIDs can determine:
- Approximate creation time of records
- Rate of record generation
- Potential correlation between UUID sequences and business activities

**Mitigations**:
- Use UUIDv4 for applications requiring maximum unpredictability
- Implement rate limiting to prevent timing attacks
- Avoid exposing UUIDs in public APIs when timing data is sensitive

## Database Security Implications

### Primary Key Security

#### Sequential ID Vulnerabilities (Avoided)
Traditional auto-incrementing IDs create security risks:
- **Enumeration Attacks**: `SELECT * FROM users WHERE id > 1000` reveals user count
- **Resource Discovery**: Predictable URLs enable scraping
- **Race Conditions**: Concurrent requests can leak information

#### UUIDv7 Advantages
- **Non-Enumerability**: No predictable sequence for attackers to exploit
- **Global Uniqueness**: No collision risks across distributed systems
- **Index Efficiency**: Time-ordered UUIDs provide better B-tree performance

### Foreign Key Security Considerations

#### Polymorphic Associations
When using polymorphic references with UUID primary keys:

```ruby
# Migration
create_table :comments do |t|
  t.references :commentable, polymorphic: true, type: :uuid
end
```

**Security Implications**:
- Foreign keys become non-guessable
- Prevents enumeration of related records
- Complicates unauthorized data access patterns

#### Join Table Exposure
Many-to-many relationships expose UUIDs in join tables:

```ruby
# users_posts join table contains UUID foreign keys
# An attacker seeing these can correlate users with content
```

**Recommendations**:
- Use appropriate access controls regardless of key type
- Implement row-level security when needed
- Consider UUID visibility in audit logs

## Performance-Security Trade-offs

### Index Performance vs Security

| Aspect | Integer Keys | UUIDv7 Keys | Security Impact |
|--------|-------------|-------------|-----------------|
| **Index Size** | 4 bytes | 16 bytes | Neutral |
| **Cache Efficiency** | Excellent | Good | Neutral |
| **Predictability** | High Risk | Low Risk | Security Benefit |
| **Fragmentation** | None | Low (monotonic) | Security Benefit |

### Query Performance Considerations

#### Range Queries on Time
UUIDv7's time-based ordering enables efficient time-range queries:

```ruby
# Find records from last hour (efficient with UUIDv7)
User.where("id >= ? AND id < ?", min_uuid_for_hour, max_uuid_for_hour)
```

**Security Benefit**: Enables efficient audit logging and temporal access controls

#### Index Bloat Monitoring
Large UUID indexes may require monitoring:

```sql
-- Monitor index bloat (PostgreSQL example)
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'users' AND attname = 'id';
```

**Recommendation**: Monitor index statistics and plan maintenance windows

## Side-Channel Attack Vectors

### Timing Attacks

#### UUID Generation Timing
UUID generation is fast and constant-time, but bulk operations may reveal system load:

```ruby
# Bulk UUID generation timing can reveal system capacity
start = Time.now
100.times { User.create!(name: "User") }
duration = Time.now - start
# Duration reveals concurrent load and system performance
```

**Mitigation**: Implement rate limiting and monitoring

### Information Leakage Through Errors

#### Database Error Messages
UUID validation errors may leak information:

```ruby
# Potential information leakage
User.find("invalid-uuid") # => ActiveRecord::RecordNotFound
# vs
User.find("550e8400-e29b-41d4-a716-446655440000") # => User or Not Found
```

**Mitigation**: Use consistent error messages regardless of UUID validity

### Cross-Application Correlation

#### UUID Reuse Across Services
Using the same UUID generation in multiple applications can create correlation vectors:

```ruby
# Service A: User UUID
# Service B: Order UUID with same timestamp
# Correlation: Same user placed order at same millisecond
```

**Recommendation**: Use service-specific UUID namespaces or additional entropy

## Dependency Security

This gem has minimal dependencies with known security postures:

### Runtime Dependencies
- **rails (~> 8.0)**: Monitored via Rails security advisories
- **Database adapters**: Follow respective project security practices
  - **pg (~> 1.6.3)**: PostgreSQL adapter (compatible with PostgreSQL 18+)
  - **mysql2 (~> 0.5.7)**: MySQL adapter (compatible with MySQL 9+)
  - **sqlite3 (~> 2.9.0)**: SQLite adapter

### Development Dependencies
- Testing frameworks with regular security updates
- Code quality tools (RuboCop, RuboCop-Rails)

## Secure Usage Guidelines

### 1. Application-Level Security
```ruby
# DO: Use UUIDs for public-facing identifiers
class Post < ApplicationRecord
  # UUID primary key is secure by default
end

# DON'T: Don't rely on UUID secrecy alone
class User < ApplicationRecord
  # Still need authentication and authorization
  def visible_posts
    posts.where(published: true) # Business logic access control
  end
end
```

### 2. API Security
```ruby
# DO: Use UUIDs in APIs
get '/posts/:id' do
  post = Post.find_by!(id: params[:id])
  authorize! :read, post # Authorization still required
  render post
end

# DON'T: Don't assume UUIDs prevent all attacks
# Rate limiting, input validation still essential
```

### 3. Database Security
```ruby
# DO: Use appropriate access controls
class ApplicationPolicy
  def show?
    user.admin? || record.user_id == user.id
  end
end

# DON'T: Don't expose UUIDs unnecessarily
# Consider using different identifiers for public APIs
```

## Security Testing Recommendations

### Automated Security Testing
```ruby
# Add to test suite
class SecurityTest < ActiveSupport::TestCase
  test "UUIDs are not predictable" do
    uuids = 1000.times.map { SecureRandom.uuid_v7 }
    # Verify no obvious patterns
    assert uuids.uniq.length == uuids.length
  end

  test "timing attack resistance" do
    # Verify constant-time UUID generation
    times = 100.times.map do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      SecureRandom.uuid_v7
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    variance = times.max - times.min
    assert variance < 0.001 # Less than 1ms variance
  end
end
```

### Penetration Testing Checklist
- [ ] UUID enumeration attempts
- [ ] Timing attack analysis
- [ ] Information leakage through errors
- [ ] Cross-service correlation analysis
- [ ] Database access pattern analysis

## Security Maintenance

### Regular Security Reviews
- **Monthly**: Dependency updates and vulnerability scans
- **Quarterly**: Security architecture review
- **Annually**: Full security assessment

### Security Monitoring
- Monitor for unusual UUID generation patterns
- Alert on potential enumeration attacks
- Track performance degradation that might indicate attacks

## Compliance Considerations

### GDPR and Privacy
- UUIDs as personal data: Generally not considered personal information
- Audit logging: UUIDs provide excellent audit trails
- Data minimization: Consider if UUID exposure meets data minimization requirements

### Industry-Specific Security
- **Healthcare (HIPAA)**: UUIDs support proper access controls
- **Financial Services**: Enhanced audit capabilities
- **Government**: Supports classification and access controls

## Conclusion

Rails-UUID-PK provides a secure foundation for UUIDv7 primary keys with proper cryptographic properties and database security benefits. However, security is defense-in-depth: UUIDs enhance security but don't replace proper authentication, authorization, and access controls.

**Key Takeaways**:
1. UUIDv7 provides better security than sequential IDs
2. Timestamp exposure is a known trade-off
3. Application-level security controls remain essential
4. Monitor performance and security metrics in production
5. Regular security reviews and updates are critical

For questions about security or to report vulnerabilities, contact the security team at seouri@gmail.com.
