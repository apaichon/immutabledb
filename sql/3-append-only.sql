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


-- Example

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

--

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

select get_account_balance('a47fc10b-58cc-4372-a567-0e02b2c3d123');