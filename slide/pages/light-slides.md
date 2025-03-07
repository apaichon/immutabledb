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

<div class="flex justify-center">
  <img src="/images/immutabledb/event-sourcing-flow.svg" alt="Event Sourcing Flow" class="w-1/2">
</div>

---

# Event Sourcing: Example Usage


<div style="overflow-y: auto; height: 450px;">
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

<div class="flex justify-center">
  <img src="/images/immutabledb/append-only-log-flow.svg" alt="Append-Only Log Flow" class="w-1/2">
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

<div class="grid grid-cols-2 gap-4">
<div>

**Key Components:**
- Valid time periods (valid_from, valid_to)
- Primary key includes temporal component
- Never delete or update records
- Insert new versions for changes

</div>
<div>

**Benefits:**
- Complete history tracking
- Point-in-time queries
- Audit compliance
- No data loss

</div>
</div>

---

# Temporal Tables: Flow
<div class="flex justify-center">
  <img src="/images/immutabledb/temporal-tables-flow.svg" alt="Temporal Tables Flow" class="w-1/2">
</div>
---

# Temporal Tables: Structure

```sql
CREATE TABLE customers_temporal (
    customer_id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP NOT NULL DEFAULT 'infinity',
    modified_by VARCHAR(50) NOT NULL,
    PRIMARY KEY (customer_id, valid_from)
);

-- Indexes for efficient querying
CREATE INDEX idx_customers_current 
ON customers_temporal (customer_id) 
WHERE valid_to = 'infinity';

CREATE INDEX idx_customers_history 
ON customers_temporal (customer_id, valid_from, valid_to);
```

---

# Temporal Tables: Insert Function

```sql
CREATE OR REPLACE FUNCTION insert_customer(
    p_customer_id INTEGER,
    p_name VARCHAR,
    p_email VARCHAR,
    p_status VARCHAR,
    p_modified_by VARCHAR
) RETURNS VOID AS $$
BEGIN
    INSERT INTO customers_temporal (
        customer_id,
        name,
        email,
        status,
        valid_from,
        modified_by
    )
    VALUES (
        p_customer_id,
        p_name,
        p_email,
        p_status,
        CURRENT_TIMESTAMP,
        p_modified_by
    );
END;
$$ LANGUAGE plpgsql;
```

---

# Temporal Tables: Update Function

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION update_customer(
    p_customer_id INTEGER,
    p_name VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_modified_by VARCHAR DEFAULT NULL
) RETURNS VOID AS $$
DECLARE 
    v_current_record customers_temporal%ROWTYPE;
BEGIN
    -- Get current record
    SELECT * INTO v_current_record
    FROM customers_temporal
    WHERE customer_id = p_customer_id
    AND valid_to = 'infinity';

    -- Close current period
    UPDATE customers_temporal
    SET valid_to = CURRENT_TIMESTAMP
    WHERE customer_id = p_customer_id
    AND valid_to = 'infinity';

    -- Insert new version
    INSERT INTO customers_temporal (
        customer_id, name, email, status,
        valid_from, modified_by
    )
    VALUES (
        p_customer_id,
        COALESCE(p_name, v_current_record.name),
        COALESCE(p_email, v_current_record.email),
        COALESCE(p_status, v_current_record.status),
        CURRENT_TIMESTAMP,
        p_modified_by
    );
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Temporal Tables: Querying

<div style="overflow-y: auto; height: 450px;">

```sql
-- Get current state
SELECT * FROM customers_temporal
WHERE customer_id = 101
AND valid_to = 'infinity';

-- Get complete history
SELECT * FROM customers_temporal
WHERE customer_id = 101
ORDER BY valid_from;

-- Get state at specific time
SELECT * FROM customers_temporal
WHERE customer_id = 101
AND valid_from <= '2023-01-01'::timestamp
AND valid_to > '2023-01-01'::timestamp;

-- Current customers view
CREATE VIEW current_customers AS
SELECT 
    customer_id,
    name,
    email,
    status,
    valid_from AS last_updated,
    modified_by AS last_modified_by
FROM customers_temporal
WHERE valid_to = 'infinity';
```
</div>
---

# Pattern 5: Snapshot Pattern

<div class="grid grid-cols-2 gap-4">
<div>

**Key Components:**
- Events table (source of truth)
- Snapshots table (performance optimization)
- Automatic snapshot creation
- Balance calculation with snapshots

</div>
<div>

**Benefits:**
- Improved query performance
- Reduced event replay time
- Memory efficiency
- Scalable event sourcing

</div>
</div>

---

# Snapshot Pattern: Flow
<div class="flex justify-center">
  <img src="/images/immutabledb/snapshot-pattern-flow.svg" alt="Snapshot Pattern Flow" class="w-1/2">
</div>
---

# Snapshot Pattern: Structure

<div style="overflow-y: auto; height: 450px;">
```sql
-- Events table (source of truth)
CREATE TABLE account_events (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    amount NUMERIC(12, 2),
    reference VARCHAR(100),
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Snapshots table
CREATE TABLE account_snapshots (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL,
    balance NUMERIC(12, 2) NOT NULL,
    snapshot_up_to_event_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_account_events ON account_events(account_id, occurred_at);
CREATE UNIQUE INDEX idx_latest_snapshot 
ON account_snapshots(account_id, snapshot_up_to_event_id);
```
</div>
---

# Snapshot Pattern: Event Recording

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION record_account_event(
    p_account_id INTEGER,
    p_event_type VARCHAR,
    p_amount NUMERIC DEFAULT NULL,
    p_reference VARCHAR DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE 
    new_event_id INTEGER;
BEGIN
    INSERT INTO account_events (
        account_id,
        event_type,
        amount,
        reference,
        metadata
    )
    VALUES (
        p_account_id,
        p_event_type,
        p_amount,
        p_reference,
        p_metadata
    )
    RETURNING id INTO new_event_id;
    
    RETURN new_event_id;
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Snapshot Pattern: Balance Calculation

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION get_account_balance(p_account_id INTEGER) 
RETURNS NUMERIC AS $$
DECLARE 
    latest_snapshot RECORD;
    current_balance NUMERIC;
BEGIN
    -- Find the latest snapshot
    SELECT * INTO latest_snapshot
    FROM account_snapshots
    WHERE account_id = p_account_id
    ORDER BY snapshot_up_to_event_id DESC
    LIMIT 1;

    -- If no snapshot exists, calculate from all events
    IF NOT FOUND THEN 
        RETURN calculate_balance_from_events(p_account_id);
    END IF;

    -- Calculate incremental balance from events after the snapshot
    current_balance := latest_snapshot.balance + 
        calculate_balance_from_events(
            p_account_id,
            latest_snapshot.snapshot_up_to_event_id + 1
        );

    RETURN current_balance;
END;
$$ LANGUAGE plpgsql;
```
</div>
---

# Snapshot Pattern: Automatic Creation

<div style="overflow-y: auto; height: 450px;">

```sql
CREATE OR REPLACE FUNCTION check_snapshot_needed(
    p_account_id INTEGER,
    p_event_threshold INTEGER DEFAULT 50
) RETURNS BOOLEAN AS $$
DECLARE
    latest_snapshot RECORD;
    latest_event_id INTEGER;
    events_since_snapshot INTEGER;
BEGIN
    -- Find the latest snapshot
    SELECT * INTO latest_snapshot
    FROM account_snapshots
    WHERE account_id = p_account_id
    ORDER BY snapshot_up_to_event_id DESC
    LIMIT 1;

    -- Get the latest event ID
    SELECT MAX(id) INTO latest_event_id
    FROM account_events
    WHERE account_id = p_account_id;

    -- Create first snapshot if none exists
    IF NOT FOUND AND latest_event_id IS NOT NULL THEN
        PERFORM create_account_snapshot(p_account_id);
        RETURN TRUE;
    END IF;

    -- Calculate events since last snapshot
    events_since_snapshot := latest_event_id - latest_snapshot.snapshot_up_to_event_id;

    -- Create new snapshot if passed threshold
    IF events_since_snapshot >= p_event_threshold THEN
        PERFORM create_account_snapshot(p_account_id);
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Trigger for automatic snapshot creation
CREATE TRIGGER account_event_after_insert
    AFTER INSERT ON account_events 
    FOR EACH ROW 
    EXECUTE FUNCTION after_event_insert_trigger();
```
</div>
---

# Pattern 6: Materialized Views

<div class="grid grid-cols-2 gap-4">
<div>

**Key Components:**
- Base tables with events
- Materialized view definition
- Refresh strategy
- Automatic refresh triggers

</div>
<div>

**Benefits:**
- Improved query performance
- Complex data aggregation
- Real-time analytics
- Reduced database load

</div>
</div>

---

# Materialized Views: Flow

<div class="flex justify-center">
  <img src="/images/immutabledb/materialized-view-flow.svg" alt="Materialized View Flow" class="w-1/2">
</div>

--- 

# Materialized Views: Table Structure

```sql
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    base_price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_events (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB NOT NULL,
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventory_events (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    event_type VARCHAR(50) NOT NULL,
    quantity INTEGER NOT NULL,
    warehouse_id INTEGER NOT NULL,
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

# Materialized Views: Analytics View

<div style="overflow-y: auto; height: 450px;">
```sql
CREATE MATERIALIZED VIEW product_analytics AS
WITH price_data AS (
    SELECT 
        p.product_id,
        p.name,
        p.base_price,
        COALESCE(
            (SELECT (pe.event_data->>'new_price')::NUMERIC
             FROM product_events pe
             WHERE pe.product_id = p.product_id
             AND pe.event_type = 'price_changed'
             ORDER BY pe.occurred_at DESC
             LIMIT 1
            ), p.base_price
        ) AS current_price
    FROM products p
),
inventory_data AS (
    SELECT 
        product_id,
        SUM(CASE
            WHEN event_type = 'stock_added' THEN quantity
            WHEN event_type = 'stock_removed' THEN -quantity
            ELSE 0
        END) AS current_stock
    FROM inventory_events
    GROUP BY product_id
)
SELECT 
    pd.product_id,
    pd.name,
    pd.base_price,
    pd.current_price,
    COALESCE(id.current_stock, 0) AS current_inventory,
    CURRENT_TIMESTAMP AS last_updated
FROM price_data pd
LEFT JOIN inventory_data id ON pd.product_id = id.product_id;
```
</div>
---

# Materialized Views: Refresh Strategy

<div style="overflow-y: auto; height: 450px;">

```sql
-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_product_analytics() 
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY product_analytics;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for automatic refresh
CREATE OR REPLACE FUNCTION refresh_analytics_trigger() 
RETURNS TRIGGER AS $$
BEGIN
    -- Could implement more sophisticated logic here
    -- For example, using pg_advisory_lock to prevent concurrent refreshes
    PERFORM refresh_product_analytics();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers on source tables
CREATE TRIGGER refresh_on_product_change
    AFTER INSERT OR UPDATE ON products 
    FOR EACH STATEMENT 
    EXECUTE FUNCTION refresh_analytics_trigger();

CREATE TRIGGER refresh_on_product_event
    AFTER INSERT ON product_events 
    FOR EACH STATEMENT 
    EXECUTE FUNCTION refresh_analytics_trigger();
```
</div>
---

# Materialized Views: Usage Examples

<div style="overflow-y: auto; height: 450px;">

```sql
-- View current analytics
SELECT * FROM product_analytics;

-- Compare performance
EXPLAIN ANALYZE SELECT * FROM product_analytics;

-- vs calculating directly (slower)
EXPLAIN ANALYZE 
WITH price_data AS (
    SELECT p.product_id, p.name, p.base_price,
           -- Complex price calculation
           COALESCE((
               SELECT (pe.event_data->>'new_price')::NUMERIC
               FROM product_events pe
               WHERE pe.product_id = p.product_id
               AND pe.event_type = 'price_changed'
               ORDER BY pe.occurred_at DESC
               LIMIT 1
           ), p.base_price) AS current_price
    FROM products p
)
-- ... rest of complex calculation ...
SELECT * FROM price_data;

-- Manual refresh when needed
SELECT refresh_product_analytics();
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




