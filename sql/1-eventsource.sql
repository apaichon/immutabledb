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

select * from get_current_user_state('f47ac10b-58cc-4372-a567-0e02b2c3d479')