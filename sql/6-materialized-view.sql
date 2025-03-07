-- Simple Materialized View Pattern Example
-- This demonstrates how to use materialized views with event-sourced data
-- 1. Create tables for our e-commerce domain
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
CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL REFERENCES products(product_id),
  quantity INTEGER NOT NULL,
  price_per_unit NUMERIC(10, 2) NOT NULL,
  ordered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- 2. Create indexes for efficient querying
CREATE INDEX idx_product_events ON product_events(product_id, occurred_at);
CREATE INDEX idx_inventory_events ON inventory_events(product_id, occurred_at);
CREATE INDEX idx_order_items ON order_items(product_id, ordered_at);
-- 3. Create a materialized view for product analytics
CREATE MATERIALIZED VIEW product_analytics AS WITH -- Calculate current price based on price change events
price_data AS (
  SELECT p.product_id,
    p.name,
    p.base_price,
    COALESCE(
      (
        SELECT (pe.event_data->>'new_price')::NUMERIC
        FROM product_events pe
        WHERE pe.product_id = p.product_id
          AND pe.event_type = 'price_changed'
        ORDER BY pe.occurred_at DESC
        LIMIT 1
      ), p.base_price
    ) AS current_price
  FROM products p
),
-- Calculate current inventory levels
inventory_data AS (
  SELECT product_id,
    warehouse_id,
    SUM(
      CASE
        WHEN event_type = 'stock_added' THEN quantity
        WHEN event_type = 'stock_removed' THEN - quantity
        ELSE 0
      END
    ) AS current_stock
  FROM inventory_events
  GROUP BY product_id,
    warehouse_id
),
-- Calculate total inventory across all warehouses
total_inventory AS (
  SELECT product_id,
    SUM(current_stock) AS total_stock
  FROM inventory_data
  GROUP BY product_id
),
-- Calculate sales data
sales_data AS (
  SELECT product_id,
    SUM(quantity) AS units_sold,
    SUM(quantity * price_per_unit) AS total_revenue
  FROM order_items
  GROUP BY product_id
) -- Combine all the data
SELECT pd.product_id,
  pd.name,
  pd.base_price,
  pd.current_price,
  COALESCE(ti.total_stock, 0) AS current_inventory,
  COALESCE(sd.units_sold, 0) AS units_sold,
  COALESCE(sd.total_revenue, 0) AS total_revenue,
  CASE
    WHEN COALESCE(sd.units_sold, 0) > 0 THEN COALESCE(sd.total_revenue, 0) / COALESCE(sd.units_sold, 0)
    ELSE NULL
  END AS average_selling_price,
  CURRENT_TIMESTAMP AS last_updated
FROM price_data pd
  LEFT JOIN total_inventory ti ON pd.product_id = ti.product_id
  LEFT JOIN sales_data sd ON pd.product_id = sd.product_id;
-- 4. Create index on the materialized view
CREATE UNIQUE INDEX idx_product_analytics ON product_analytics(product_id);
-- 5. Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_product_analytics() RETURNS VOID AS $$ BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY product_analytics;
END;
$$ LANGUAGE plpgsql;
-- 6. Function to insert product price change event
CREATE OR REPLACE FUNCTION change_product_price(
    p_product_id INTEGER,
    p_new_price NUMERIC(10, 2),
    p_reason VARCHAR DEFAULT NULL
  ) RETURNS VOID AS $$ BEGIN
INSERT INTO product_events (
    product_id,
    event_type,
    event_data
  )
VALUES (
    p_product_id,
    'price_changed',
    jsonb_build_object(
      'new_price',
      p_new_price,
      'old_price',
      (
        SELECT COALESCE(
            (
              SELECT (event_data->>'new_price')::NUMERIC
              FROM product_events
              WHERE product_id = p_product_id
                AND event_type = 'price_changed'
              ORDER BY occurred_at DESC
              LIMIT 1
            ), (
              SELECT base_price
              FROM products
              WHERE product_id = p_product_id
            )
          )
      ),
      'reason',
      p_reason
    )
  );
END;
$$ LANGUAGE plpgsql;
-- 7. Function to record inventory changes
CREATE OR REPLACE FUNCTION update_inventory(
    p_product_id INTEGER,
    p_warehouse_id INTEGER,
    p_quantity INTEGER,
    p_event_type VARCHAR
  ) RETURNS VOID AS $$ BEGIN -- Validate event type
  IF p_event_type NOT IN ('stock_added', 'stock_removed') THEN RAISE EXCEPTION 'Invalid event type: %',
  p_event_type;
END IF;
-- Ensure quantity is positive
IF p_quantity <= 0 THEN RAISE EXCEPTION 'Quantity must be positive';
END IF;
-- Record the inventory event
INSERT INTO inventory_events (
    product_id,
    event_type,
    quantity,
    warehouse_id
  )
VALUES (
    p_product_id,
    p_event_type,
    p_quantity,
    p_warehouse_id
  );
END;
$$ LANGUAGE plpgsql;
-- 8. Function to record an order
CREATE OR REPLACE FUNCTION record_order(
    p_order_id INTEGER,
    p_product_id INTEGER,
    p_quantity INTEGER
  ) RETURNS VOID AS $$
DECLARE v_current_price NUMERIC(10, 2);
BEGIN -- Get current price
SELECT COALESCE(
    (
      SELECT (event_data->>'new_price')::NUMERIC
      FROM product_events
      WHERE product_id = p_product_id
        AND event_type = 'price_changed'
      ORDER BY occurred_at DESC
      LIMIT 1
    ), (
      SELECT base_price
      FROM products
      WHERE product_id = p_product_id
    )
  ) INTO v_current_price;
-- Insert order item
INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    price_per_unit
  )
VALUES (
    p_order_id,
    p_product_id,
    p_quantity,
    v_current_price
  );
-- Remove the items from inventory (example uses warehouse_id=1)
PERFORM update_inventory(p_product_id, 1, p_quantity, 'stock_removed');
END;
$$ LANGUAGE plpgsql;
-- 9. Create a trigger to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_analytics_trigger() RETURNS TRIGGER AS $$ BEGIN -- Could implement more sophisticated logic here to avoid too frequent refreshes
  -- For example, using pg_advisory_lock to prevent concurrent refreshes
  -- or a debounce mechanism to not refresh too often
  PERFORM refresh_product_analytics();
RETURN NULL;
END;
$$ LANGUAGE plpgsql;
-- Create triggers on all the source tables
CREATE TRIGGER refresh_on_product_change
AFTER
INSERT
  OR
UPDATE ON products FOR EACH STATEMENT EXECUTE FUNCTION refresh_analytics_trigger();
CREATE TRIGGER refresh_on_product_event
AFTER
INSERT ON product_events FOR EACH STATEMENT EXECUTE FUNCTION refresh_analytics_trigger();
CREATE TRIGGER refresh_on_inventory_change
AFTER
INSERT ON inventory_events FOR EACH STATEMENT EXECUTE FUNCTION refresh_analytics_trigger();
CREATE TRIGGER refresh_on_order
AFTER
INSERT ON order_items FOR EACH STATEMENT EXECUTE FUNCTION refresh_analytics_trigger();
-- 10. Sample data: Set up products and events
DO $$ BEGIN -- Insert sample products
INSERT INTO products (name, description, base_price)
VALUES (
    'Smartphone X',
    'Latest smartphone with advanced features',
    999.99
  ),
  (
    'Laptop Pro',
    'Professional laptop for developers',
    1499.99
  ),
  (
    'Wireless Earbuds',
    'Premium wireless earbuds with noise cancellation',
    199.99
  );
-- Add initial inventory
PERFORM update_inventory(1, 1, 100, 'stock_added');
-- 100 smartphones in warehouse 1
PERFORM update_inventory(2, 1, 50, 'stock_added');
-- 50 laptops in warehouse 1
PERFORM update_inventory(3, 1, 200, 'stock_added');
-- 200 earbuds in warehouse 1
-- Change some prices
PERFORM change_product_price(1, 899.99, 'Seasonal discount');
PERFORM change_product_price(3, 179.99, 'Promotional offer');
-- Record some orders
PERFORM record_order(1001, 1, 5);
-- 5 smartphones
PERFORM record_order(1001, 3, 3);
-- 3 earbuds
PERFORM record_order(1002, 2, 2);
-- 2 laptops
PERFORM record_order(1003, 1, 1);
-- 1 smartphone
PERFORM record_order(1004, 3, 10);
-- 10 earbuds
-- Later price change
PERFORM change_product_price(2, 1399.99, 'Competitive adjustment');
-- More inventory and orders
PERFORM update_inventory(1, 1, 50, 'stock_added');
-- 50 more smartphones
PERFORM record_order(1005, 1, 8);
-- 8 more smartphones
PERFORM record_order(1006, 2, 5);
-- 5 more laptops
END $$;
-- 11. Example queries
-- View the materialized analytics data
-- SELECT * FROM product_analytics;
-- Manually refresh the materialized view
-- SELECT refresh_product_analytics();
-- Compare performance between materialized view and direct calculation
-- EXPLAIN ANALYZE SELECT * FROM product_analytics;
-- vs. calculating the same data directly (slower as data grows)
-- EXPLAIN ANALYZE
-- WITH price_data AS (...), inventory_data AS (...), ...
-- SELECT ... FROM price_data ... ;
-- View product event history
-- SELECT * FROM product_events WHERE product_id = 1 ORDER BY occurred_at;
-- View inventory history
-- SELECT * FROM inventory_events WHERE product_id = 1 ORDER BY occurred_at;
