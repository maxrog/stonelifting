# Database Migrations Guide

## Overview

This project uses **Fluent's migration system** to manage database schema changes. Migrations are tracked in the `_fluent_migrations` table to ensure they run exactly once.

## Current Setup

### Migration Safety Features

1. **Idempotent Migrations**: All table creation migrations use `.ignoreExisting()` to safely handle concurrent deployments
2. **No Error Swallowing**: Failed migrations will stop app startup (by design - see "Why This Matters")
3. **Automatic Migration**: `autoMigrate()` runs on every deployment to apply pending migrations

### Existing Migrations

- `CreateUser.swift` - Creates the `users` table
- `CreateStone.swift` - Creates the `stones` table (depends on `users`)

## Adding New Migrations

When you need to modify the database schema (add columns, create tables, add indexes, etc.):

### 1. Create a New Migration File

```swift
// Sources/StoneLifting/Migrations/AddStoneWeightVerified.swift
import Fluent

struct AddStoneWeightVerified: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // Add your schema changes here
        try await database.schema("stones")
            .field("weight_verified", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: any Database) async throws {
        // Reverse the changes
        try await database.schema("stones")
            .deleteField("weight_verified")
            .update()
    }
}
```

### 2. Register the Migration

Add it to `configure.swift` **in order** (Fluent runs migrations in registration order):

```swift
// Migrations
app.migrations.add(CreateUser())
app.migrations.add(CreateStone())
app.migrations.add(AddStoneWeightVerified())  // <- Add new migration here
```

### 3. Migration Best Practices

#### For Table Creation
Use `.ignoreExisting()` to make it safe for concurrent deployments:
```swift
try await database.schema("new_table")
    .ignoreExisting()
    .id()
    .field("name", .string, .required)
    .create()
```

#### For Adding Columns
Always provide defaults for required columns to avoid issues with existing data:
```swift
try await database.schema("stones")
    .field("new_column", .string, .required, .sql(.default("default_value")))
    .update()
```

#### For Complex Data Migrations
Split into separate migrations if needed:
```swift
// Migration 1: Add column with default
struct AddColumn: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("stones")
            .field("status", .string, .sql(.default("active")))
            .update()
    }
}

// Migration 2: Populate data based on business logic
struct PopulateStatus: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // Update rows based on complex logic
        try await database.raw("""
            UPDATE stones
            SET status = CASE
                WHEN is_hidden = true THEN 'hidden'
                WHEN report_count > 10 THEN 'flagged'
                ELSE 'active'
            END
        """).run()
    }
}
```

## Railway Deployment Behavior

### How Migrations Run on Railway

1. **Every instance runs migrations** when it starts up
2. **Fluent tracks completed migrations** in `_fluent_migrations` table
3. **First instance** creates tables/runs new migrations
4. **Subsequent instances** see migrations already completed, skip them
5. **Idempotent migrations** (with `.ignoreExisting()`) prevent race condition errors

### Expected Logs (Normal Behavior)

✅ **First instance starting:**
```
[ INFO ] Running database migrations...
[ INFO ] Migration 'CreateUser' completed
[ INFO ] Migration 'CreateStone' completed
[ INFO ] Database migrations completed successfully
```

✅ **Second instance starting (tables already exist):**
```
[ INFO ] Running database migrations...
[ INFO ] Database migrations completed successfully
```

## Testing Migrations Locally

### Test a New Migration

```bash
# 1. Ensure your local database is running
# 2. Run the app (migrations run automatically on startup)
swift run

# You should see:
# [ INFO ] Running database migrations...
# [ INFO ] Database migrations completed successfully
```

### Test Migration Rollback

```bash
# Revert the last migration
swift run App migrate --revert

# Or revert all migrations (caution: deletes all data!)
swift run App migrate --revert --all
```

### Test from Scratch

```bash
# Drop all tables and re-run migrations
dropdb vapor_database
createdb vapor_database
swift run
```

## Production Migration Checklist

Before deploying a migration to production:

- [ ] Migration tested locally with existing data
- [ ] Migration includes both `prepare()` and `revert()` methods
- [ ] Required columns have appropriate defaults
- [ ] Migration is registered in `configure.swift` in the correct order
- [ ] Complex data migrations are split into separate steps if needed
- [ ] No sensitive data logged during migration
- [ ] Performance impact considered (adding indexes to large tables?)
- [ ] Rollback strategy documented if migration is risky
- [ ] Database backup taken (Railway automatic backups enabled)

## Common Migration Patterns

### Add a Column
```swift
try await database.schema("stones")
    .field("new_field", .string)
    .update()
```

### Add a Column with Default (for existing data)
```swift
try await database.schema("stones")
    .field("new_field", .string, .required, .sql(.default("value")))
    .update()
```

### Add an Index
```swift
try await database.schema("stones")
    .field("location_name", .string)
    .update()
    .raw("CREATE INDEX IF NOT EXISTS idx_stones_location ON stones(location_name)")
    .run()
```

### Add a Foreign Key
```swift
try await database.schema("lifting_sessions")
    .field("stone_id", .uuid, .required, .references("stones", "id", onDelete: .cascade))
    .update()
```

### Rename a Column (requires raw SQL)
```swift
try await database.raw("""
    ALTER TABLE stones
    RENAME COLUMN old_name TO new_name
""").run()
```

### Create a New Table (with safety)
```swift
try await database.schema("new_table")
    .ignoreExisting()
    .id()
    .field("created_at", .datetime)
    .create()
```

## Troubleshooting

### "Table already exists" errors in Railway logs

### Migration won't run (says it's already completed)

Fluent tracks completed migrations. If you need to re-run:
```bash
# Locally: delete from tracking table
psql vapor_database -c "DELETE FROM _fluent_migrations WHERE name='MigrationName';"

# Or revert and re-apply
swift run App migrate --revert
swift run App migrate
```

### Migration stuck/hanging

- Check database connectivity
- Verify no other instances are holding locks
- Check Railway logs for connection timeouts
- Consider adding timeout to migration if it's a long-running data operation

## Further Reading

- [Fluent Documentation](https://docs.vapor.codes/fluent/overview/)
- [Fluent Migrations Guide](https://docs.vapor.codes/fluent/migrations/)
- [PostgreSQL Schema Management](https://www.postgresql.org/docs/current/ddl.html)
