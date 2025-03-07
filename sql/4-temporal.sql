-- Simple Temporal Tables Example
-- This demonstrates the core concepts of temporal tables with minimal complexity
-- 1. Create a simple customer temporal table
CREATE TABLE customers_temporal (
    customer_id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP NOT NULL DEFAULT 'infinity'::TIMESTAMP,
    modified_by VARCHAR(50) NOT NULL,
    PRIMARY KEY (customer_id, valid_from)
);
-- 2. Create index for current records
CREATE INDEX idx_customers_current ON customers_temporal (customer_id)
WHERE valid_to = 'infinity'::TIMESTAMP;
-- 3. Create index for historical queries
CREATE INDEX idx_customers_history ON customers_temporal (customer_id, valid_from, valid_to);
-- 4. Insert function for new customers
CREATE OR REPLACE FUNCTION insert_customer(
        p_customer_id INTEGER,
        p_name VARCHAR,
        p_email VARCHAR,
        p_status VARCHAR,
        p_modified_by VARCHAR
    ) RETURNS VOID AS $$ BEGIN
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
-- 5. Update function to maintain history
CREATE OR REPLACE FUNCTION update_customer(
        p_customer_id INTEGER,
        p_name VARCHAR DEFAULT NULL,
        p_email VARCHAR DEFAULT NULL,
        p_status VARCHAR DEFAULT NULL,
        p_modified_by VARCHAR DEFAULT NULL
    ) RETURNS VOID AS $$
DECLARE v_current_record customers_temporal %ROWTYPE;
BEGIN -- Get the current record
SELECT * INTO v_current_record
FROM customers_temporal
WHERE customer_id = p_customer_id
    AND valid_to = 'infinity'::TIMESTAMP;
IF NOT FOUND THEN RAISE EXCEPTION 'Customer with ID % not found',
p_customer_id;
END IF;
-- Close the current period
UPDATE customers_temporal
SET valid_to = CURRENT_TIMESTAMP
WHERE customer_id = p_customer_id
    AND valid_to = 'infinity'::TIMESTAMP;
-- Insert the new record with updated values
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
        COALESCE(p_name, v_current_record.name),
        COALESCE(p_email, v_current_record.email),
        COALESCE(p_status, v_current_record.status),
        CURRENT_TIMESTAMP,
        p_modified_by
    );
END;
$$ LANGUAGE plpgsql;

-- 6. Function to retrieve customer at a point in time
CREATE OR REPLACE FUNCTION get_customer_at_time(
        p_customer_id INTEGER,
        p_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) RETURNS SETOF customers_temporal AS $$ BEGIN RETURN QUERY
SELECT *
FROM customers_temporal
WHERE customer_id = p_customer_id
    AND valid_from <= p_timestamp
    AND valid_to > p_timestamp;
END;
$$ LANGUAGE plpgsql;
-- 7. Sample data and operations
-- Insert a new customer
SELECT insert_customer(
        101,
        'Alice Johnson',
        'alice@example.com',
        'active',
        'system'
    );
-- Let's wait a bit before the next operation
SELECT pg_sleep(1);
-- Update customer's email
SELECT update_customer(
        101,
        p_email := 'alice.johnson@example.com',
        p_modified_by := 'admin'
    );
-- Wait again
SELECT pg_sleep(1);
-- Update customer's status
SELECT update_customer(
        101,
        p_status := 'premium',
        p_modified_by := 'sales'
    );
-- 8. Query examples
-- Get current customer state
SELECT *
FROM customers_temporal
WHERE customer_id = 101
    AND valid_to = 'infinity'::TIMESTAMP;
-- Get customer history (all versions)
SELECT *
FROM customers_temporal
WHERE customer_id = 101
ORDER BY valid_from;
-- Get customer state at a specific time (second version)
SELECT *
FROM get_customer_at_time(
        101,
        (
            SELECT valid_from
            FROM customers_temporal
            WHERE customer_id = 101
            ORDER BY valid_from
            LIMIT 1 OFFSET 1
        )
    );
-- 9. View for current customer data
CREATE OR REPLACE VIEW current_customers AS
SELECT customer_id,
    name,
    email,
    status,
    valid_from AS last_updated,
    modified_by AS last_modified_by
FROM customers_temporal
WHERE valid_to = 'infinity'::TIMESTAMP;
-- Example query using the view
-- SELECT * FROM current_customers;

SELECT *
FROM current_customers