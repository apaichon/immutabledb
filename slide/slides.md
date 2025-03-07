---
theme: default
background: https://source.unsplash.com/collection/94734566/1920x1080
class: text-center
highlighter: shiki
lineNumbers: false
info: |
  ## Immutable Database Design with Postgres
  A comprehensive 3-hour course on implementing immutable patterns in PostgreSQL
drawings:
  persist: false
transition: slide-left
title: Immutable Database Design with Postgres
---

# Immutable Database Design with Postgres

A 3-hour comprehensive course

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

---
layout: default
---

# Data Integrity and Auditability

<v-clicks>

- **Complete change history:**
  - Every change is recorded, never overwritten
  - Answer questions like "Who changed what, when, and why?"
  - Trace the evolution of any data point from creation to present

- **Example audit query:**

```sql
SELECT 
    valid_from, 
    address, 
    created_by_user 
FROM customer_addresses 
WHERE customer_id = 42 
ORDER BY valid_from;
```

- **Immutability as evidence:**
  - Guaranteed data lineage for legal and compliance purposes
  - Tamper-evident data storage
  - Digital forensics capabilities

</v-clicks>

---

# Time Travel Queries

<v-clicks>

- **Access data as it existed at any point in time:**
  - Historical reporting
  - Trend analysis
  - Error investigation

- **Example time travel query:**

```sql
-- Get a customer's address as it was on January 1, 2023
SELECT address 
FROM customer_addresses 
WHERE customer_id = 42
  AND valid_from <= '2023-01-01'::timestamp
ORDER BY valid_from DESC
LIMIT 1;
```

- **Business use cases:**
  - Recreating invoices as they appeared when sent
  - Analyzing decision-making based on information available at the time
  - Reconciling historical financial records

</v-clicks>

---

# Simplified Backup and Recovery

<v-clicks>

- **Inherent data protection:**
  - Historical data is always preserved by design
  - Recovery means restoring to a point in time, not rebuilding lost data

- **Disaster recovery benefits:**
  - More granular recovery points
  - Ability to recover specific data without full database restores
  - Simpler logical data recovery

- **Operational advantages:**
  - Reduced downtime during recovery scenarios
  - Better RTO (Recovery Time Objective) capabilities
  - Improved RPO (Recovery Point Objective) metrics

</v-clicks>

---

# Regulatory Compliance

<v-clicks>

- **Built-in compliance with data retention requirements:**
  - Financial regulations (SOX, FINRA, etc.)
  - Healthcare regulations (HIPAA)
  - Privacy laws (GDPR, CCPA)

- **Specific compliance features:**
  - Guaranteed non-destruction of records
  - Immutable audit trails
  - Evidence for regulatory investigations

- **Real-world examples:**
  - Financial transaction records for tax authorities
  - Clinical trials data that cannot be modified after collection
  - Legal evidence preservation

</v-clicks>

---
layout: section
---

# Challenges and Considerations

---
layout: default
---

# Storage Requirements

<v-clicks>

- **Increased storage needs:**
  - Every change requires new records
  - Historical data accumulates continuously
  - Need for storage planning and lifecycle management

- **Strategies to address:**
  - Table partitioning for historical data
  - Compression techniques
  - Archiving policies
  - Tiered storage solutions

</v-clicks>

---

# Query Complexity

<v-clicks>

- **Added complexity for current-state queries:**
  - Need to filter for the most recent version of each record
  - Joins become more complex
  - Indexing strategies must accommodate temporal access

- **Performance implications:**
  - More CPU work for filtering
  - More complex execution plans
  - Potential for slower queries without proper optimization

</v-clicks>

---

# Application Layer Changes

<v-clicks>

- **Different programming paradigm:**
  - Applications must be designed for append-only operations
  - Business logic must account for versioning
  - APIs need to handle temporal parameters

- **Development challenges:**
  - More complex data access patterns
  - Need for temporal awareness in code
  - Different testing approaches

</v-clicks>

---

# Data Lifecycle Management

<v-clicks>

- **Balancing immutability with practical limitations:**
  - Regulatory requirements for deletion (e.g., GDPR)
  - Performance impact of ever-growing tables
  - Cost implications of unlimited storage growth

- **Possible approaches:**
  - Logical deletion markers
  - Cryptographic obfuscation
  - Separate archival systems

</v-clicks>

---
layout: two-cols
---

# Truly Immutable Databases

<v-clicks>
<div style="overflow-y: scroll; height: 400px;">

**Examples:**
- Datomic
- XTDB
- Immudb
- Blockchain-based databases

**Key characteristics:**
- Immutability as a foundational principle
- Built-in temporal query capabilities
- Architectural support for append-only operations
- Often incorporate Merkle trees or similar structures for verification


**Advantages:**
- Immutability guarantees at the database level
- Optimized for temporal queries
- Built-in tools for historical data management

</div>

</v-clicks>

::right::

<div class="ml-4">

# Immutable Patterns in RDBMS

<v-clicks>
<div style="overflow-y: scroll; height: 400px;">

**Implementation in PostgreSQL:**
- Temporal table patterns
- Strategic use of constraints and triggers
- Careful schema design
- Leveraging transaction isolation

**Key patterns we'll cover:**
- Temporal tables
- Event sourcing
- Bitemporal modeling
- Versioned records

**Advantages:**
- Leveraging familiar technology
- Flexibility to apply immutability selectively
- Integration with existing systems
- Balancing immutability with practical concerns
</div>
</v-clicks>

</div>

---
layout: center
class: text-center
---

# Immutable Schema Design Patterns

PostgreSQL implementation techniques for immutable data


---
layout: section
---

# Temporal Tables Pattern


---
layout: default
---

# What are Temporal Tables?

<v-clicks>

- Tables that track the **validity period** of each record
- Enable historical views of data at any point in time
- Implement an append-only model for changes
- Sometimes called "time-travel tables" or "history tables"

</v-clicks>

<div v-click class="mt-8 bg-blue-100 p-4 rounded">

**Key concept**: Instead of updating existing records, we add new ones with a time boundary.

</div>

---

# Effective Dating with Temporal Columns

<v-clicks>

## Core Temporal Columns

- **valid_from**: When this version of the record became active
- **valid_to**: When this version of the record became inactive (or NULL for current records)
- Sometimes called "effective_from" and "effective_to" in business contexts

## Additional Useful Metadata

- **created_at**: When this record was inserted (transaction time)
- **created_by**: Who created this version
- **reason_code**: Why this change was made

</v-clicks>

---
layout: two-cols
---

# Basic Temporal Table Structure

<v-clicks>

```sql
CREATE TABLE customer_addresses (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  
  valid_from TIMESTAMP NOT NULL,
  valid_to TIMESTAMP,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  created_by TEXT NOT NULL
);

-- Ensure valid time periods
ALTER TABLE customer_addresses
ADD CONSTRAINT valid_time_period 
CHECK (valid_to IS NULL OR valid_from < valid_to);
```

</v-clicks>

::right::

<div v-click class="ml-4 mt-20">

**Key aspects:**

- Natural key (customer_id) + temporal columns
- valid_to = NULL marks current version
- CHECK constraint enforces temporal logic
- No UPDATE or DELETE operations allowed
- Primary key on surrogate id, not business key

</div>

---

# Implementing Constraints

<v-clicks>

## Temporal Non-Overlapping Constraint

```sql
CREATE UNIQUE INDEX customer_address_current_idx 
ON customer_addresses (customer_id) 
WHERE valid_to IS NULL;
```

## Prevent Overlapping Time Periods

```sql
CREATE EXTENSION btree_gist;

ALTER TABLE customer_addresses
ADD CONSTRAINT no_overlapping_periods
EXCLUDE USING gist (
  customer_id WITH =,
  tsrange(valid_from, valid_to) WITH &&
);
```

</v-clicks>

---

# Inserting New Versions

<v-clicks>

<div style="overflow-y: scroll; height: 400px;">
## Initial Insert (First Version)

```sql
INSERT INTO customer_addresses (
  customer_id, address, city, state, zip,
  valid_from, created_by
)
VALUES (
  42, '123 Main St', 'Portland', 'OR', '97201',
  NOW(), 'system'
);
```

## New Version (Changes Address)

```sql
-- Start a transaction
BEGIN;

-- Close the current record
UPDATE customer_addresses
SET valid_to = NOW()
WHERE customer_id = 42 AND valid_to IS NULL;

-- Insert the new version
INSERT INTO customer_addresses (
  customer_id, address, city, state, zip,
  valid_from, created_by
)
VALUES (
  42, '456 New Ave', 'Portland', 'OR', '97202',
  NOW(), 'john.doe'
);

COMMIT;
```

</div>
</v-clicks>

---

# Querying Point-in-Time Data

<v-clicks>

## Current State (As of Now)

```sql
SELECT * FROM customer_addresses
WHERE customer_id = 42
  AND valid_to IS NULL;
```

## Historical State (Point in Time)

```sql
SELECT * FROM customer_addresses
WHERE customer_id = 42
  AND valid_from <= '2023-06-15'::timestamp
  AND (valid_to IS NULL OR valid_to > '2023-06-15'::timestamp)
ORDER BY valid_from DESC
LIMIT 1;
```

## History of All Changes

```sql
SELECT * FROM customer_addresses
WHERE customer_id = 42
ORDER BY valid_from;
```

</v-clicks>

---

# Managing Temporal Table Size

<v-clicks>

## Table Partitioning by Time Range

```sql
CREATE TABLE customer_addresses (
  -- columns as before
) PARTITION BY RANGE (valid_from);

-- Create partitions for different time periods
CREATE TABLE customer_addresses_2022 
  PARTITION OF customer_addresses
  FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');

CREATE TABLE customer_addresses_2023 
  PARTITION OF customer_addresses
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
```

## Archiving Strategies

- Move older partitions to cheaper storage
- Implement retention policies based on business needs
- Consider compressing historical partitions

</v-clicks>

---

# Performance Optimization for Temporal Tables

<v-clicks>

## Indexing Strategies

```sql
-- Index for point-in-time queries
CREATE INDEX customer_addresses_temporal_idx
ON customer_addresses (customer_id, valid_from DESC);

-- Index for range queries
CREATE INDEX customer_addresses_range_idx
ON customer_addresses USING GIST (
  customer_id, 
  tsrange(valid_from, valid_to)
);
```

## Performance Tips

- Use covering indexes for frequent queries
- Consider partial indexes for current state
- Add date truncation functions for reporting queries
- Implement summarization tables for historical analysis

</v-clicks>

---
layout: section
---

# Event Sourcing with Postgres

---

# Event Sourcing Fundamentals

<v-clicks>

## Core Principles

- Store **events** (facts that happened) rather than current state
- Events are immutable by nature
- Current state is derived by replaying events
- "The event log is the source of truth"

## Benefits in Postgres Context

- Natural fit for append-only design
- Strong transaction guarantees
- JSON/JSONB for flexible event payloads
- Efficient indexing for event retrieval

</v-clicks>

---

# Event Table Design

<v-clicks>

```sql
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  
  -- Event metadata
  event_type VARCHAR(100) NOT NULL,
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID NOT NULL,
  occurred_at TIMESTAMP NOT NULL DEFAULT NOW(),
  user_id UUID NOT NULL,
  
  -- Event data
  payload JSONB NOT NULL,
  
  -- For optimistic concurrency
  sequence_number BIGINT NOT NULL,
  
  -- For event correlation
  correlation_id UUID,
  causation_id UUID
);

-- Indexes for efficient querying
CREATE INDEX events_entity_idx ON events (entity_type, entity_id, occurred_at);
CREATE INDEX events_type_idx ON events (event_type, occurred_at);
```

</v-clicks>

---

# Using JSON/JSONB for Event Payloads

<v-clicks>

## JSON or JSONB?

- **JSONB**: Binary, indexed, more efficient for querying
- **JSON**: Textual, preserves formatting and order, faster for inserts

</v-clicks>



## Payload Structure
<div style="overflow-y: scroll; height: 200px;">

```json
{
  "before": {
    "address": "123 Main St",
    "city": "Portland",
    "state": "OR"
  },
  "after": {
    "address": "456 New Ave", 
    "city": "Portland", 
    "state": "OR"
  },
  "changedFields": ["address"]
}
```


## Querying JSONB

```sql
-- Find events that modified a specific field
SELECT * FROM events
WHERE entity_type = 'customer'
  AND entity_id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
  AND payload->'changedFields' ? 'address';
```

</div>

---

# Generating State from Event Streams

<v-clicks>

## Materialized View Approach

<div style="overflow-y: scroll; height: 400px;">

```sql
CREATE MATERIALIZED VIEW current_customer_addresses AS
WITH latest_events AS (
  SELECT 
    entity_id,
    payload->'after' AS current_state,
    MAX(occurred_at) AS last_updated
  FROM events
  WHERE entity_type = 'customer_address'
  GROUP BY entity_id
)
SELECT 
  entity_id AS customer_id,
  current_state->>'address' AS address,
  current_state->>'city' AS city,
  current_state->>'state' AS state,
  last_updated
FROM latest_events;
```

## Function-Based Approach

```sql
CREATE OR REPLACE FUNCTION get_customer_state(
  p_customer_id UUID,
  p_point_in_time TIMESTAMP DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  result JSONB = '{}'::JSONB;
BEGIN
  SELECT 
    jsonb_agg(payload ORDER BY occurred_at)
  INTO result
  FROM events
  WHERE entity_type = 'customer'
    AND entity_id = p_customer_id
    AND (p_point_in_time IS NULL OR occurred_at <= p_point_in_time);

  RETURN result;
END;
$$ LANGUAGE plpgsql;
```
</div>

</v-clicks>

---

# Performance with Large Event Stores


## Challenges

- Growing event logs
- Complex aggregation for current state
- Query performance degradation over time

<div style="overflow-y: scroll; height: 300px;">

## Optimizations

- **Snapshotting**: Periodically save aggregated state

```sql
CREATE TABLE customer_snapshots (
  customer_id UUID PRIMARY KEY,
  state JSONB NOT NULL,
  last_event_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

- **Event Partitioning**: Partition by entity_type or time

```sql
CREATE TABLE events (
  -- columns as before
) PARTITION BY LIST (entity_type);

CREATE TABLE events_customers PARTITION OF events
  FOR VALUES IN ('customer');
```

- **Parallel Processing**: Leverage PG parallel query capabilities

</div>


---
layout: section
---

# Bitemporal Modeling

---

# Understanding Bitemporal Dimensions

<v-clicks>

## Two Time Dimensions

1. **Valid Time** (Business Time)
   - When something is true in the real world
   - Controlled by business rules
   - Can be in the future or past
   - Example: "Customer's address is valid from Jan 1 to Mar 31"

2. **Transaction Time** (System Time)
   - When something was recorded in the database
   - Controlled by the system
   - Always historical (now or past)
   - Example: "We recorded this address change on Dec 15"

## Why Two Dimensions?

- Represent corrections to historical data
- Distinguish between retroactive changes and corrections
- Support both "what did we know and when" and "what was true and when"

</v-clicks>

---
layout: two-cols
---

# Bitemporal Table Structure

<v-clicks>

```sql
CREATE TABLE customer_addresses_bt (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  
  -- Valid time (business perspective)
  valid_from TIMESTAMP NOT NULL,
  valid_to TIMESTAMP,
  
  -- Transaction time (system perspective)
  system_from TIMESTAMP NOT NULL 
    DEFAULT CURRENT_TIMESTAMP,
  system_to TIMESTAMP,
  
  created_by TEXT NOT NULL
);
```

</v-clicks>

::right::

<div v-click class="ml-4 mt-12">

**Four temporal states:**

1. **Current & Current**: 
   - Valid now, currently believed
   - valid_to IS NULL, system_to IS NULL

2. **Current & Historical**: 
   - Valid now, formerly believed
   - valid_to IS NULL, system_to IS NOT NULL

3. **Historical & Current**: 
   - Valid in past, currently believed
   - valid_to IS NOT NULL, system_to IS NULL

4. **Historical & Historical**: 
   - Valid in past, formerly believed
   - valid_to IS NOT NULL, system_to IS NOT NULL

</div>

---

# Implementing Bitemporal Tables

<v-clicks>

## Bitemporal Constraints

```sql
-- Time period validations
ALTER TABLE customer_addresses_bt
ADD CONSTRAINT valid_time_period 
CHECK (valid_to IS NULL OR valid_from < valid_to);

ALTER TABLE customer_addresses_bt
ADD CONSTRAINT system_time_period 
CHECK (system_to IS NULL OR system_from < system_to);

-- Non-overlapping valid time periods
CREATE EXTENSION btree_gist;

ALTER TABLE customer_addresses_bt
ADD CONSTRAINT no_overlapping_valid_periods
EXCLUDE USING gist (
  customer_id WITH =,
  tsrange(valid_from, valid_to) WITH &&
) WHERE (system_to IS NULL);
```

## Ensure System Time is Automatic

```sql
-- Function to close system time
CREATE OR REPLACE FUNCTION close_system_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.system_from := CURRENT_TIMESTAMP;
    UPDATE customer_addresses_bt
    SET system_to = CURRENT_TIMESTAMP
    WHERE id = OLD.id AND system_to IS NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to manage system time
CREATE TRIGGER trg_system_time
BEFORE UPDATE ON customer_addresses_bt
FOR EACH ROW EXECUTE FUNCTION close_system_time();
```

</v-clicks>

---

# Complex Temporal Queries

<v-clicks>

## Current State (Both Dimensions)

```sql
SELECT * FROM customer_addresses_bt
WHERE customer_id = 42
  AND valid_from <= CURRENT_TIMESTAMP
  AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
  AND system_to IS NULL;
```

## As of a Business Date (Valid Time)

```sql
SELECT * FROM customer_addresses_bt
WHERE customer_id = 42
  AND valid_from <= '2023-03-15'::timestamp
  AND (valid_to IS NULL OR valid_to > '2023-03-15'::timestamp)
  AND system_to IS NULL;
```

## As Known at a System Date (Transaction Time)

```sql
SELECT * FROM customer_addresses_bt
WHERE customer_id = 42
  AND system_from <= '2023-01-10'::timestamp
  AND (system_to IS NULL OR system_to > '2023-01-10'::timestamp)
  AND valid_from <= CURRENT_TIMESTAMP
  AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP);
```

## Both Dimensions (Complete Time Travel)

```sql
SELECT * FROM customer_addresses_bt
WHERE customer_id = 42
  AND valid_from <= '2023-03-15'::timestamp
  AND (valid_to IS NULL OR valid_to > '2023-03-15'::timestamp)
  AND system_from <= '2023-01-10'::timestamp
  AND (system_to IS NULL OR system_to > '2023-01-10'::timestamp);
```

</v-clicks>

---

# Handling Corrections to Historical Data

<v-clicks>

## Scenario: Retroactive Correction

**Business scenario**: We discover on May 1, 2023 that a customer's address was incorrectly entered for the period Jan 1-Mar 31, 2023.

```sql
BEGIN;

-- Close current system version
UPDATE customer_addresses_bt
SET system_to = CURRENT_TIMESTAMP
WHERE customer_id = 42 
  AND valid_from = '2023-01-01'::timestamp
  AND valid_to = '2023-04-01'::timestamp
  AND system_to IS NULL;

-- Insert corrected version (same valid time, new system time)
INSERT INTO customer_addresses_bt (
  customer_id, address, city, state, zip,
  valid_from, valid_to, created_by
)
VALUES (
  42, '789 Corrected St', 'Portland', 'OR', '97203',
  '2023-01-01'::timestamp, '2023-04-01'::timestamp, 'audit.team'
);

COMMIT;
```

## Result

- Original record: system_from=Dec15, system_to=May1, valid_from=Jan1, valid_to=Apr1
- Corrected record: system_from=May1, system_to=NULL, valid_from=Jan1, valid_to=Apr1

</v-clicks>

---
layout: section
---

# Materialized Views and Projections
## (15 minutes)

---

# Creating Read Models from Immutable Data

<v-clicks>

## The Challenge

- Immutable data patterns optimize for writes and history
- Reading current state becomes more complex
- Queries can be slower and more resource-intensive
- Solution: Separate read and write models (CQRS pattern)

## Read Model Approaches

1. **Materialized Views**: Database-managed snapshots
2. **Application Projections**: Application-managed read tables
3. **Hybrid Approach**: System-triggered updates to read tables

</v-clicks>

---

# Materialized Views for Current State

<v-clicks>

## Basic Materialized View

```sql
CREATE MATERIALIZED VIEW current_customer_addresses AS
SELECT 
  customer_id,
  address,
  city,
  state,
  zip
FROM customer_addresses ca1
WHERE valid_to IS NULL
  OR valid_to = (
    SELECT MAX(valid_to)
    FROM customer_addresses ca2
    WHERE ca2.customer_id = ca1.customer_id
  );
```

## For Temporal Tables

```sql
CREATE MATERIALIZED VIEW customer_addresses_current AS
SELECT DISTINCT ON (customer_id)
  customer_id,
  address,
  city,
  state,
  zip,
  valid_from
FROM customer_addresses
WHERE valid_from <= CURRENT_TIMESTAMP
  AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
ORDER BY customer_id, valid_from DESC;
```

</v-clicks>

---

# Refresh Strategies for Materialized Views

<v-clicks>

## Complete Refresh

```sql
-- Manual refresh
REFRESH MATERIALIZED VIEW customer_addresses_current;

-- With concurrency
REFRESH MATERIALIZED VIEW CONCURRENTLY customer_addresses_current;
```

## Scheduled Refresh

```sql
-- Using pg_cron extension
CREATE EXTENSION pg_cron;

SELECT cron.schedule('0 */1 * * *', 
  'REFRESH MATERIALIZED VIEW CONCURRENTLY customer_addresses_current');
```

## Trigger-Based Refresh

```sql
CREATE OR REPLACE FUNCTION refresh_customer_view()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY customer_addresses_current;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER refresh_mat_view
AFTER INSERT OR UPDATE ON customer_addresses
FOR EACH STATEMENT EXECUTE FUNCTION refresh_customer_view();
```

</v-clicks>

---

# Indexing Strategies for Temporal Queries

<v-clicks>

## Materialized View Indexes

```sql
-- Add indexes to materialized view
CREATE UNIQUE INDEX customer_addresses_current_pk 
ON customer_addresses_current (customer_id);

CREATE INDEX customer_addresses_current_city 
ON customer_addresses_current (city);
```

## Specialized Temporal Indexes

```sql
-- Range type index for temporal queries
CREATE INDEX customer_addresses_valid_range 
ON customer_addresses USING GIST (
  customer_id,
  tsrange(valid_from, valid_to, '[]')
);

-- Index for "AS OF" queries
CREATE INDEX customer_addresses_as_of 
ON customer_addresses (customer_id, valid_from DESC);
```

</v-clicks>

---

# Managing View Updates Efficiently

<v-clicks>

## Incremental Updates with Triggers

```sql
CREATE TABLE customer_addresses_current (
  customer_id BIGINT PRIMARY KEY,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  valid_from TIMESTAMP NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_current_address()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete any existing current address
  DELETE FROM customer_addresses_current
  WHERE customer_id = NEW.customer_id;
  
  -- Insert the new current address
  INSERT INTO customer_addresses_current
  SELECT 
    customer_id, address, city, state, zip, valid_from, NOW()
  FROM customer_addresses
  WHERE customer_id = NEW.customer_id
    AND valid_to IS NULL;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER maintain_current_address
AFTER INSERT OR UPDATE ON customer_addresses
FOR EACH ROW EXECUTE FUNCTION update_current_address();
```

## Performance Considerations

- Batch updates when possible
- Consider asynchronous refresh mechanisms
- Use partial refresh for large datasets
- Monitor materialized view size and refresh time

</v-clicks>

<div style="overflow-y: scroll; height: 200px;">

---
layout: end
---

# Thank You!

[Documentation](https://sli.dev) · [GitHub](https://github.com/slidevjs/slidev) · [Showcases](https://sli.dev/showcases)