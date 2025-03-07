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

INSERT INTO customer_addresses (
  customer_id, address, city, state, zip,
  valid_from, created_by
)
VALUES (
  42, '123 Main St', 'Portland', 'OR', '97201',
  NOW(), 'system'
);

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

select * from customer_addresses

