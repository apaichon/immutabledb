-- Simple Snapshot Pattern Example
-- This demonstrates how snapshots can optimize performance for event-sourced systems
-- 1. Create an events table (the source of truth)
CREATE TABLE account_events (
  id SERIAL PRIMARY KEY,
  account_id INTEGER NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  amount NUMERIC(12, 2),
  reference VARCHAR(100),
  occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  metadata JSONB
);
CREATE INDEX idx_account_events ON account_events(account_id, occurred_at);
-- 2. Create a snapshots table
CREATE TABLE account_snapshots (
  id SERIAL PRIMARY KEY,
  account_id INTEGER NOT NULL,
  balance NUMERIC(12, 2) NOT NULL,
  snapshot_up_to_event_id INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX idx_latest_snapshot ON account_snapshots(account_id, snapshot_up_to_event_id);
CREATE INDEX idx_account_snapshots ON account_snapshots(account_id, created_at);
-- 3. Function to insert new events
CREATE OR REPLACE FUNCTION record_account_event(
    p_account_id INTEGER,
    p_event_type VARCHAR,
    p_amount NUMERIC DEFAULT NULL,
    p_reference VARCHAR DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
  ) RETURNS INTEGER AS $$
DECLARE new_event_id INTEGER;
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
-- 4. Function to calculate account balance from events
CREATE OR REPLACE FUNCTION calculate_balance_from_events(
    p_account_id INTEGER,
    p_from_event_id INTEGER DEFAULT 1
  ) RETURNS NUMERIC AS $$
DECLARE balance NUMERIC := 0;
event_record RECORD;
BEGIN FOR event_record IN
SELECT event_type,
  amount
FROM account_events
WHERE account_id = p_account_id
  AND id >= p_from_event_id
ORDER BY occurred_at ASC LOOP CASE
    event_record.event_type
    WHEN 'deposit' THEN balance := balance + event_record.amount;
WHEN 'withdrawal' THEN balance := balance - event_record.amount;
WHEN 'fee' THEN balance := balance - event_record.amount;
WHEN 'interest' THEN balance := balance + event_record.amount;
ELSE -- Other event types ignored
END CASE
;
END LOOP;
RETURN balance;
END;
$$ LANGUAGE plpgsql;
-- 5. Function to create a snapshot
CREATE OR REPLACE FUNCTION create_account_snapshot(p_account_id INTEGER) RETURNS VOID AS $$
DECLARE balance NUMERIC;
latest_event_id INTEGER;
snapshot_exists BOOLEAN;
BEGIN -- Get the ID of the latest event for this account
SELECT MAX(e.id) INTO latest_event_id -- Explicitly qualify the id
FROM account_events e -- Alias for clarity
WHERE e.account_id = p_account_id;
-- Exit if no events found
IF latest_event_id IS NULL THEN RAISE NOTICE 'No events found for account %',
p_account_id;
RETURN;
END IF;
-- Check if a snapshot already exists for this exact version
SELECT EXISTS (
    SELECT 1
    FROM account_snapshots
    WHERE account_id = p_account_id
      AND snapshot_up_to_event_id = latest_event_id
  ) INTO snapshot_exists;
-- Exit if a snapshot already exists for this version
IF snapshot_exists THEN RAISE NOTICE 'Snapshot already exists for account % at event %',
p_account_id,
latest_event_id;
RETURN;
END IF;
-- Calculate the current balance
balance := calculate_balance_from_events(p_account_id);
-- Create the snapshot
INSERT INTO account_snapshots (
    account_id,
    balance,
    snapshot_up_to_event_id
  )
VALUES (
    p_account_id,
    balance,
    latest_event_id
  );
RAISE NOTICE 'Created snapshot for account % with balance % at event %',
p_account_id,
balance,
latest_event_id;
END;
$$ LANGUAGE plpgsql;
-- 6. Function to get the latest account balance using snapshots for optimization
CREATE OR REPLACE FUNCTION get_account_balance(p_account_id INTEGER) RETURNS NUMERIC AS $$
DECLARE latest_snapshot RECORD;
current_balance NUMERIC;
BEGIN -- Find the latest snapshot
SELECT * INTO latest_snapshot
FROM account_snapshots
WHERE account_id = p_account_id
ORDER BY snapshot_up_to_event_id DESC
LIMIT 1;
-- If no snapshot exists, calculate from all events
IF NOT FOUND THEN RETURN calculate_balance_from_events(p_account_id);
END IF;
-- Calculate incremental balance from events after the snapshot
current_balance := latest_snapshot.balance + calculate_balance_from_events(
  p_account_id,
  latest_snapshot.snapshot_up_to_event_id + 1
);
RETURN current_balance;
END;
$$ LANGUAGE plpgsql;
-- 7. Function to schedule snapshots based on events count
CREATE OR REPLACE FUNCTION check_snapshot_needed(
    p_account_id INTEGER,
    p_event_threshold INTEGER DEFAULT 50
  ) RETURNS BOOLEAN AS $$
DECLARE latest_snapshot RECORD;
latest_event_id INTEGER;
events_since_snapshot INTEGER;
snapshot_created BOOLEAN := FALSE;
BEGIN -- Find the latest snapshot
SELECT * INTO latest_snapshot
FROM account_snapshots
WHERE account_id = p_account_id
ORDER BY snapshot_up_to_event_id DESC
LIMIT 1;
-- Get the latest event ID
SELECT MAX(id) INTO latest_event_id
FROM account_events
WHERE account_id = p_account_id;
-- If no latest event, exit
IF latest_event_id IS NULL THEN RETURN FALSE;
END IF;
-- If no snapshot exists and we have events, create one
IF NOT FOUND THEN PERFORM create_account_snapshot(p_account_id);
RETURN TRUE;
END IF;
-- Calculate events since last snapshot
events_since_snapshot := latest_event_id - latest_snapshot.snapshot_up_to_event_id;
-- Create a new snapshot if we've passed the threshold
IF events_since_snapshot >= p_event_threshold THEN PERFORM create_account_snapshot(p_account_id);
RETURN TRUE;
END IF;
RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
-- 8. Trigger to automatically check if snapshot is needed after inserting events
CREATE OR REPLACE FUNCTION after_event_insert_trigger() RETURNS TRIGGER AS $$ BEGIN -- Check if we need a new snapshot (threshold of 50 events)
  PERFORM check_snapshot_needed(NEW.account_id, 50);
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER account_event_after_insert
AFTER
INSERT ON account_events FOR EACH ROW EXECUTE FUNCTION after_event_insert_trigger();
-- 9. Example queries
-- View all events
-- SELECT * FROM account_events WHERE account_id = 1001 ORDER BY occurred_at;
-- View all snapshots
-- SELECT * FROM account_snapshots WHERE account_id = 1001 ORDER BY created_at;
-- Get current balance using snapshot optimization
-- SELECT get_account_balance(1001);
-- Demonstrate performance difference
-- Explain analyze SELECT calculate_balance_from_events(1001);
-- Explain analyze SELECT get_account_balance(1001);
-- Manually create a new snapshot
-- SELECT create_account_snapshot(1001);
-- Example usage of the snapshot pattern
DO $$
DECLARE account_id INTEGER := 1001;
BEGIN -- Create account
PERFORM record_account_event(
  account_id,
  'create_account',
  NULL,
  'New customer account',
  '{"customer_name": "John Doe", "account_type": "checking"}'
);
-- Initial deposit
PERFORM record_account_event(
  account_id,
  'deposit',
  1000.00,
  'Initial deposit',
  NULL
);
-- 60 more events to trigger multiple snapshots
-- First 30 transactions
FOR i IN 1..30 LOOP -- Some withdrawals
PERFORM record_account_event(
  account_id,
  'withdrawal',
  (random() * 50)::NUMERIC(12, 2),
  'ATM Withdrawal #' || i,
  NULL
);
-- Some deposits
PERFORM record_account_event(
  account_id,
  'deposit',
  (random() * 100)::NUMERIC(12, 2),
  'Deposit #' || i,
  NULL
);
END LOOP;
-- Next 30 transactions
FOR i IN 31..60 LOOP -- More withdrawals
PERFORM record_account_event(
  account_id,
  'withdrawal',
  (random() * 40)::NUMERIC(12, 2),
  'Purchase #' || i,
  NULL
);
-- Monthly fee
IF i % 10 = 0 THEN PERFORM record_account_event(
  account_id,
  'fee',
  9.99,
  'Monthly service fee',
  NULL
);
END IF;
END LOOP;
-- Display results
RAISE NOTICE 'Created account % with % events',
account_id,
(
  SELECT COUNT(*)
  FROM account_events
  WHERE account_id = 1001
);
RAISE NOTICE 'Final balance: %',
get_account_balance(account_id);
RAISE NOTICE 'Number of snapshots created: %',
(
  SELECT COUNT(*)
  FROM account_snapshots
  WHERE account_id = 1001
);
-- Example queries to explore the data
RAISE NOTICE E'\nLatest snapshot:';
RAISE NOTICE '%',
(
  SELECT jsonb_pretty(
      jsonb_build_object(
        'id',
        s.id,
        'account_id',
        s.account_id,
        'balance',
        s.balance,
        'snapshot_up_to_event_id',
        s.snapshot_up_to_event_id,
        'created_at',
        s.created_at
      )
    )
  FROM account_snapshots s
  WHERE s.account_id = 1001
  ORDER BY s.snapshot_up_to_event_id DESC
  LIMIT 1
);
-- Show performance comparison
RAISE NOTICE E'\nPerformance comparison:';
RAISE NOTICE 'Time to calculate from all events:';
EXPLAIN ANALYZE
SELECT calculate_balance_from_events(1001);
RAISE NOTICE E'\nTime to calculate using snapshot optimization:';
EXPLAIN ANALYZE
SELECT get_account_balance(1001);
END $$;
-- 1. Create a test account and add some transactions
SELECT record_account_event(1001, 'deposit', 1000.00, 'Initial deposit');
SELECT record_account_event(1001, 'withdrawal', 250.00, 'ATM withdrawal');
SELECT record_account_event(1001, 'deposit', 750.00, 'Salary deposit');
SELECT record_account_event(1001, 'fee', 5.00, 'Monthly fee');
-- 2. View all events for the account
SELECT *
FROM account_events
WHERE account_id = 1001
ORDER BY occurred_at;
-- 3. Check the current balance (this will automatically use snapshots if available)
SELECT get_account_balance(1001);
-- 4. Manually create a snapshot (though this is usually handled automatically)
SELECT create_account_snapshot(1001);
-- 5. View the snapshots
SELECT *
FROM account_snapshots
WHERE account_id = 1001
ORDER BY created_at;
-- 6. Add more transactions (snapshot will be created automatically after 50 events)
SELECT record_account_event(1001, 'deposit', 1000.00, 'Bonus');
SELECT record_account_event(1001, 'withdrawal', 300.00, 'Online purchase');
-- 7. Compare performance between methods
EXPLAIN ANALYZE
SELECT calculate_balance_from_events(1001);
-- Calculates from all events
EXPLAIN ANALYZE
SELECT get_account_balance(1001);