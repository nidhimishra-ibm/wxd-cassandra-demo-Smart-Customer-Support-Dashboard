-- ============================================================================
-- Query 1: Customer 360 View
-- ============================================================================
-- 
-- Purpose: Get a complete view of a customer including historical data and 
--          real-time activity
--
-- Business Use Case: 
--   - Customer support agents need complete customer context
--   - Sales teams want to understand customer value and current behavior
--   - Marketing teams need to personalize communications
--
-- Data Sources:
--   - Iceberg: customers_details (profile information)
--   - Iceberg: customers_orders (historical purchase data)
--   - Cassandra: customer_sessions (real-time website activity)
--   - Cassandra: recent_transactions (latest transaction status)
--
-- Key Metrics:
--   - Lifetime Value: Total amount spent by customer
--   - Total Orders: Number of completed orders
--   - Current Activity: What page they're on right now
--   - Cart Status: Items currently in shopping cart
--   - Transaction Status: Status of most recent transaction
--
-- Performance Notes:
--   - Use WHERE clause to filter by specific customer_id for faster results
--   - LEFT JOINs ensure we get customer data even if no active session
--
-- ============================================================================

SELECT 
    -- Customer Profile (from Iceberg)
    c.customer_id,
    c.name,
    c.email,
    c.customer_tier,
    c.city,
    c.country,
    c.signup_date,
    
    -- Historical Metrics (from Iceberg)
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.amount) AS lifetime_value,
    MAX(o.order_date) AS last_order_date,
    AVG(o.amount) AS average_order_value,
    
    -- Real-Time Activity (from Cassandra)
    s.current_page,
    s.session_duration_minutes,
    s.items_in_cart,
    s.last_active_time,
    
    -- Recent Transaction (from Cassandra)
    t.transaction_id,
    t.status AS transaction_status,
    t.amount AS pending_amount,
    t.payment_method,
    t.transaction_time
    
FROM iceberg_data.customers_schema.customers_details c

-- Join historical orders
LEFT JOIN iceberg_data.customers_schema.customers_orders o 
    ON c.customer_id = o.customer_id

-- Join real-time session data
LEFT JOIN astradb_catalog.customers.customer_sessions s 
    ON c.customer_id = s.customer_id

-- Join recent transactions
LEFT JOIN astradb_catalog.customers.recent_transactions t 
    ON c.customer_id = t.customer_id

-- Optional: Filter by specific customer
-- WHERE c.customer_id = 'C001'

GROUP BY 
    c.customer_id, 
    c.name, 
    c.email, 
    c.customer_tier,
    c.city,
    c.country,
    c.signup_date,
    s.current_page, 
    s.session_duration_minutes, 
    s.items_in_cart,
    s.last_active_time,
    t.transaction_id, 
    t.status, 
    t.amount,
    t.payment_method,
    t.transaction_time

ORDER BY lifetime_value DESC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id          : Unique customer identifier
-- name                 : Customer full name
-- email                : Customer email address
-- customer_tier        : Loyalty tier (Bronze/Silver/Gold/Platinum)
-- city                 : Customer city
-- country              : Customer country
-- signup_date          : Date customer registered
-- total_orders         : Count of all orders
-- lifetime_value       : Total amount spent (USD)
-- last_order_date      : Date of most recent order
-- average_order_value  : Average order amount
-- current_page         : Current page customer is viewing
-- session_duration_minutes : Time spent in current session
-- items_in_cart        : Number of items in shopping cart
-- last_active_time     : Last activity timestamp
-- transaction_id       : Most recent transaction ID
-- transaction_status   : Status (pending/completed/failed)
-- pending_amount       : Amount of pending transaction
-- payment_method       : Payment method used
-- transaction_time     : When transaction occurred
-- ============================================================================

-- Made with Bob
