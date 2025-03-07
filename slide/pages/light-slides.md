---
theme: default
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: false
info: |
  ## Immutable Database Design with Postgres
  A comprehensive course on implementing immutable patterns in PostgreSQL
drawings:
  persist: false
transition: slide-left
title: Immutable Database Design with Postgres
---

# Immutable Database Design with Postgres

A comprehensive course on implementing immutable patterns in PostgreSQL

<div class="pt-12">
  <span @click="$slidev.nav.next" class="px-2 py-1 rounded cursor-pointer" hover="bg-white bg-opacity-10">
    Press Space for next page <carbon:arrow-right class="inline"/>
  </span>
</div>

---
layout: section
---

# Fundamentals of Immutability in Databases

---
layout: two-cols
---

# What is Immutable Database Design?

<v-clicks>

**Definition:**
Immutable database design is an approach where data, once written, is never modified or deleted. Instead, new versions of the data are appended, preserving the complete history of changes.

**Key principle:** 
"Append-only" data modifications

**Traditional vs. Immutable:**
- **Traditional:** Create, Read, Update, Delete
- **Immutable:** Create, Read (never Update or Delete)

</v-clicks>

::right::

<div v-click class="ml-4 mt-20">

**Philosophical foundation:**

The database becomes a ledger of facts that happened at specific points in time, rather than just the current state of affairs.

</div>
---
layout: section
---
# Database Locking

<div class="flex justify-center">
  <img src="/images/immutabledb/database-locks-infographic.svg" alt="Database Locks Infographic" class="w-1/2">
</div>

---

# Mutable vs. Immutable Example

<div class="grid grid-cols-2 gap-4">
<div v-click>

**Mutable approach:**

```sql
-- User changes their address
UPDATE customers 
SET address = '123 New Street', 
    updated_at = NOW() 
WHERE customer_id = 42;
```

</div>
<div v-click>

**Immutable approach:**

```sql
-- User changes their address
INSERT INTO customer_addresses (
    customer_id, address, valid_from
) VALUES (
    42, '123 New Street', NOW()
);
```

</div>
</div>

---
layout: section
---

# Benefits of Immutability

<div class="flex justify-center">
  <img src="/images/immutabledb/immutable-db-comparison.svg" alt="Immutable DB Comparison" class="w-1/2">
</div>

---
layout: default
---

# Truly Immutable Databases

**Examples:**
- Datomic
- XTDB
- Immudb
- EventStoreDB
- ClickHouse
- Blockchain-based databases
---
layout: default
---

# Immutable Database Design Patterns

<div class="flex justify-center">
  <img src="/images/immutabledb/immutable-db-patterns.svg" alt="Immutable DB Patterns" class="w-1/2">
</div>

---
layout: section
---

# Immutable Database Design Patterns with PostgreSQL
Implementation Examples

---
layout: default
---

# Pattern 1: Event Sourcing

Store all changes to application state as a sequence of events

```sql
-- Events table to store all domain events
CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  aggregate_type VARCHAR(100) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100) NOT NULL
);

-- Index for efficient querying by aggregate
CREATE INDEX idx_events_aggregate ON events(aggregate_type, aggregate_id);
CREATE INDEX idx_events_created_at ON events(created_at);
```

---

# Event Sourcing: Example Usage


<div style="overflow-y: auto; height: 450px;">
```sql
-- Inserting a user creation event
INSERT INTO events (
  aggregate_id, 
  aggregate_type, 
  event_type, 
  event_data, 
  created_by
) VALUES (
  'f47ac10b-58cc-4372-a567-0e02b2c3d479', 
  'user', 
  'UserCreated', 
  '{"email": "john@example.com", "name": "John Doe"}', 
  'system'
);

-- Inserting a profile update event
INSERT INTO events (
  aggregate_id, 
  aggregate_type, 
  event_type, 
  event_data, 
  created_by
) VALUES (
  'f47ac10b-58cc-4372-a567-0e02b2c3d479', 
  'user', 
  'ProfileUpdated', 
  '{"name": "John Smith"}', 
  'f47ac10b-58cc-4372-a567-0e02b2c3d479'
);
```
</div>
---

# Event Sourcing: Replay Function

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION get_current_user_state(user_id UUID)
RETURNS JSONB AS $$
DECLARE
  result JSONB := '{}'::JSONB;
  event_record RECORD;
BEGIN
  FOR event_record IN 
    SELECT event_type, event_data 
    FROM events 
    WHERE aggregate_id = user_id AND aggregate_type = 'user'
    ORDER BY created_at ASC
  LOOP
    CASE event_record.event_type
      WHEN 'UserCreated' THEN
        result := result || event_record.event_data;
      WHEN 'EmailChanged' THEN
        result := jsonb_set(result, '{email}', event_record.event_data->>'email');
      WHEN 'ProfileUpdated' THEN
        result := result || event_record.event_data;
      ELSE
        -- Handle other event types
    END CASE;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Pattern 3: Append-Only Log

<div style="overflow-y: auto; height: 450px;">

```sql
-- Transactions log table (append-only)
CREATE TABLE transaction_log (
  id BIGSERIAL PRIMARY KEY,
  transaction_type VARCHAR(50) NOT NULL,
  entity_id UUID NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  data JSONB NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Make it truly append-only with triggers
CREATE OR REPLACE FUNCTION prevent_update_delete()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'This table is append-only. Updates and deletes are not allowed.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_transaction_log_update
BEFORE UPDATE ON transaction_log
FOR EACH ROW EXECUTE FUNCTION prevent_update_delete();

CREATE TRIGGER prevent_transaction_log_delete
BEFORE DELETE ON transaction_log
FOR EACH ROW EXECUTE FUNCTION prevent_update_delete();
```
</div>
---

# Append-Only Log: Example Usage

<div style="overflow-y: auto; height: 450px;">

```sql
-- Recording a deposit
INSERT INTO transaction_log (
  transaction_type, 
  entity_id, 
  entity_type, 
  data, 
  metadata
) VALUES (
  'deposit', 
  'a47fc10b-58cc-4372-a567-0e02b2c3d123', 
  'account', 
  '{"amount": 100.00, "currency": "USD"}', 
  '{"channel": "web", "ip": "192.168.1.1"}'
);

-- Recording a withdrawal
INSERT INTO transaction_log (
  transaction_type, 
  entity_id, 
  entity_type, 
  data, 
  metadata
) VALUES (
  'withdrawal', 
  'a47fc10b-58cc-4372-a567-0e02b2c3d123', 
  'account', 
  '{"amount": 50.00, "currency": "USD"}', 
  '{"channel": "atm", "location": "ATM-123"}'
);
```

</div>
---

# Append-Only Log: Calculating Balance

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION get_account_balance(account_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  balance NUMERIC := 0;
  log_record RECORD;
BEGIN
  FOR log_record IN 
    SELECT transaction_type, data 
    FROM transaction_log 
    WHERE entity_id = account_id AND entity_type = 'account'
    ORDER BY id ASC
  LOOP
    CASE log_record.transaction_type
      WHEN 'deposit' THEN
        balance := balance + (log_record.data->>'amount')::NUMERIC;
      WHEN 'withdrawal' THEN
        balance := balance - (log_record.data->>'amount')::NUMERIC;
      WHEN 'fee' THEN
        balance := balance - (log_record.data->>'amount')::NUMERIC;
      WHEN 'interest' THEN
        balance := balance + (log_record.data->>'amount')::NUMERIC;
      ELSE
        -- Other transaction types
    END CASE;
  END LOOP;
  
  RETURN balance;
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Pattern 4: Temporal Tables

<div style="overflow-y: auto; height: 450px;">

```sql
-- Temporal User table
CREATE TABLE users_temporal (
  id UUID NOT NULL,
  email VARCHAR(255) NOT NULL,
  name VARCHAR(100) NOT NULL,
  status VARCHAR(20) NOT NULL,
  valid_from TIMESTAMP NOT NULL,
  valid_to TIMESTAMP NOT NULL DEFAULT 'infinity'::TIMESTAMP,
  created_by VARCHAR(100) NOT NULL,
  PRIMARY KEY (id, valid_from)
);

-- Enforce non-overlapping periods
CREATE UNIQUE INDEX users_temporal_no_overlap
ON users_temporal (id, valid_from, valid_to)
WHERE valid_to != 'infinity'::TIMESTAMP;

-- Index for period queries
CREATE INDEX users_temporal_valid_period
ON users_temporal (id, valid_from, valid_to);
```
</div>
---

# Temporal Tables: Update Function

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION update_user_temporal(
  p_id UUID,
  p_email VARCHAR,
  p_name VARCHAR,
  p_status VARCHAR,
  p_modified_by VARCHAR
) RETURNS VOID AS $$
DECLARE
  current_time TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
  -- End validity of the current record
  UPDATE users_temporal
  SET valid_to = current_time
  WHERE id = p_id AND valid_to = 'infinity'::TIMESTAMP;
  
  -- Insert new version
  INSERT INTO users_temporal (
    id, email, name, status, valid_from, created_by
  ) VALUES (
    p_id,
    COALESCE(p_email, (SELECT email FROM users_temporal 
                      WHERE id = p_id 
                      ORDER BY valid_to DESC 
                      LIMIT 1)),
    COALESCE(p_name, (SELECT name FROM users_temporal 
                      WHERE id = p_id 
                      ORDER BY valid_to DESC 
                      LIMIT 1)),
    COALESCE(p_status, (SELECT status FROM users_temporal 
                      WHERE id = p_id 
                      ORDER BY valid_to DESC 
                      LIMIT 1)),
    current_time,
    p_modified_by
  );
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Temporal Tables: Example Queries

<div style="overflow-y: auto; height: 450px;">

```sql
-- Insert initial user
INSERT INTO users_temporal (id, email, name, status, valid_from, created_by)
VALUES (
  'b47ac10b-58cc-4372-a567-0e02b2c3d789',
  'jane@example.com',
  'Jane Doe',
  'active',
  '2023-01-01 00:00:00',
  'system'
);

-- Update user using function
SELECT update_user_temporal(
  'b47ac10b-58cc-4372-a567-0e02b2c3d789',
  'jane.doe@example.com',
  'Jane Smith',
  NULL,
  'admin'
);

-- Query user at a point in time
SELECT * FROM users_temporal
WHERE id = 'b47ac10b-58cc-4372-a567-0e02b2c3d789'
AND valid_from <= '2023-06-15'::TIMESTAMP
AND valid_to > '2023-06-15'::TIMESTAMP;

-- Query all historical versions
SELECT * FROM users_temporal
WHERE id = 'b47ac10b-58cc-4372-a567-0e02b2c3d789'
ORDER BY valid_from;
```
</div>
---

# Pattern 5: Snapshot Pattern

<div style="overflow-y: auto; height: 450px;">

```sql
-- Events table (from previous examples)

-- Snapshots table
CREATE TABLE snapshots (    
  id SERIAL PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  aggregate_type VARCHAR(100) NOT NULL,
  version INTEGER NOT NULL,
  state JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for efficient lookups
CREATE UNIQUE INDEX idx_snapshots_latest 
ON snapshots(aggregate_id, aggregate_type, version);
```
</div>
---

# Snapshot Pattern: Creation Function

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION create_user_snapshot(user_id UUID)
RETURNS VOID AS $$
DECLARE
  current_state JSONB;
  current_version INTEGER;
BEGIN
  -- Get the current state
  current_state := get_current_user_state(user_id);
  
  -- Calculate the current version
  SELECT COUNT(*) INTO current_version
  FROM events
  WHERE aggregate_id = user_id AND aggregate_type = 'user';
  
  -- Create a new snapshot
  INSERT INTO snapshots (
    aggregate_id, 
    aggregate_type, 
    version, 
    state
  ) VALUES (
    user_id,
    'user',
    current_version,
    current_state
  )
  ON CONFLICT (aggregate_id, aggregate_type, version) 
  DO NOTHING;
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Snapshot Pattern: Optimized State Function

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION get_user_state_with_snapshot(user_id UUID)
RETURNS JSONB AS $$
DECLARE
  result JSONB := '{}'::JSONB;
  snapshot_record RECORD;
  event_record RECORD;
  snapshot_version INTEGER := 0;
BEGIN
  -- Find the latest snapshot
  SELECT state, version INTO snapshot_record
  FROM snapshots
  WHERE aggregate_id = user_id AND aggregate_type = 'user'
  ORDER BY version DESC
  LIMIT 1;
  
  -- If a snapshot exists, use it as the starting point
  IF FOUND THEN
    result := snapshot_record.state;
    snapshot_version := snapshot_record.version;
  END IF;
  
  -- Apply any events that occurred after the snapshot
  FOR event_record IN 
    SELECT event_type, event_data 
    FROM events 
    WHERE aggregate_id = user_id 
      AND aggregate_type = 'user'
      AND id > (
        SELECT MAX(id) FROM events 
        WHERE aggregate_id = user_id 
          AND aggregate_type = 'user'
        LIMIT snapshot_version
      )
    ORDER BY created_at ASC
  LOOP
    -- Apply events (same logic as before)
    CASE event_record.event_type
      WHEN 'UserCreated' THEN
        result := result || event_record.event_data;
      WHEN 'EmailChanged' THEN
        result := jsonb_set(result, '{email}', event_record.event_data->>'email');
      WHEN 'ProfileUpdated' THEN
        result := result || event_record.event_data;
      ELSE
        -- Handle other event types
    END CASE;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Pattern 6: Materialized Views

<div style="overflow-y: auto; height: 450px;">

```sql
-- Create a regular materialized view for product catalog
CREATE MATERIALIZED VIEW product_catalog AS
SELECT 
  p.id,
  p.name,
  p.description,
  c.name AS category,
  p.price,
  i.quantity_available,
  COALESCE(r.average_rating, 0) AS average_rating
FROM 
  products p
JOIN 
  categories c ON p.category_id = c.id
JOIN 
  inventory i ON p.id = i.product_id
LEFT JOIN (
  SELECT 
    product_id, 
    AVG(rating) AS average_rating
  FROM 
    product_reviews
  GROUP BY 
    product_id
) r ON p.id = r.product_id;

-- Create index for efficient querying
CREATE INDEX idx_product_catalog_id ON product_catalog(id);
CREATE INDEX idx_product_catalog_category ON product_catalog(category);
CREATE INDEX idx_product_catalog_price ON product_catalog(price);
```
</div>
---

# Materialized Views: Refresh Function

<div style="overflow-y: auto; height: 450px;">

```sql
-- Create a function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY product_catalog;
  -- Add more materialized views as needed
END;
$$ LANGUAGE plpgsql;

-- Create a schedule to refresh the views
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('*/15 * * * *', 'SELECT refresh_materialized_views()');
```
</div>
---

# Materialized Views: With Events

<div style="overflow-y: auto; height: 450px;">

```sql
-- Create a function to build a materialized view from events
CREATE OR REPLACE FUNCTION rebuild_product_inventory_view()
RETURNS VOID AS $$
BEGIN
  -- Drop and recreate the materialized view
  DROP MATERIALIZED VIEW IF EXISTS product_inventory;
  
  CREATE MATERIALIZED VIEW product_inventory AS
  WITH inventory_events AS (
    SELECT 
      e.aggregate_id AS product_id,
      e.event_type,
      e.event_data,
      e.created_at
    FROM 
      events e
    WHERE 
      e.aggregate_type = 'product' AND
      (e.event_type = 'ProductCreated' OR
       e.event_type = 'InventoryChanged' OR
       e.event_type = 'PriceChanged')
  ),
  inventory_state AS (
    SELECT 
      product_id,
      SUM(CASE 
        WHEN event_type = 'InventoryChanged' THEN (event_data->>'quantity_change')::INTEGER
        ELSE 0
      END) AS quantity_available,
      MAX(CASE 
        WHEN event_type = 'PriceChanged' THEN (event_data->>'new_price')::NUMERIC
        WHEN event_type = 'ProductCreated' THEN (event_data->>'price')::NUMERIC
        ELSE NULL
      END) OVER (PARTITION BY product_id ORDER BY created_at) AS current_price,
      MAX(created_at) AS last_updated
    FROM 
      inventory_events
    GROUP BY 
      product_id
  )
  SELECT 
    p.id AS product_id,
    p.event_data->>'name' AS product_name,
    i.quantity_available,
    i.current_price,
    i.last_updated
  FROM 
    (SELECT DISTINCT ON (aggregate_id) 
      aggregate_id AS id, 
      event_data
     FROM events 
     WHERE aggregate_type = 'product' AND event_type = 'ProductCreated'
     ORDER BY aggregate_id, created_at) p
  JOIN 
    inventory_state i ON p.id = i.product_id;
  
  -- Create indexes
  CREATE INDEX idx_product_inventory_id ON product_inventory(product_id);
  CREATE INDEX idx_product_inventory_name ON product_inventory(product_name);
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# When to Use Each Pattern

<div style="overflow-y: auto; height: 450px;">

| Pattern | Best Used When |
|---------|---------------|
| **Event Sourcing** | - Need complete audit trail<br>- Complex business rules<br>- Domain-driven design approach |
| **CQRS** | - Different read & write requirements<br>- High-volume read/write operations<br>- Complex reporting needs |
| **Append-Only Log** | - Transactional systems<br>- Need for simple event capture<br>- Streaming data applications |
| **Temporal Tables** | - Historical reporting is key<br>- Need to support time-based queries<br>- Regulatory compliance requirements |
| **Snapshot Pattern** | - Performance concerns with event replay<br>- Large event streams<br>- Need faster recovery |
| **Materialized Views** | - Complex read queries<br>- Reporting and analytics<br>- Multiple data source integration |
</div>
---

# Implementation Tips

1. **Start small** - Begin with one pattern in a bounded context
2. **Consider storage needs** - Immutable data grows continuously
3. **Plan for archiving** - Define policies for old data
4. **Optimize reads** - Use indexes and denormalized views
5. **Be careful with migrations** - Schema changes need special handling
6. **Monitor performance** - Watch for slow event replays
7. **Consider compliance** - GDPR may require special approaches
8. **Use PostgreSQL 12+** - Better JSON & temporal features

---

# Thank You!

Questions?




