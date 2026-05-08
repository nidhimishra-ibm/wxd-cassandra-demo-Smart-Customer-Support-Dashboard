-- ============================================================================
-- Query 2: High-Value Customers at Checkout
-- ============================================================================
-- 
-- Purpose: Identify high-value customers currently at checkout to prioritize
--          support and prevent cart abandonment
--
-- Business Use Case: 
--   - Customer support can proactively reach out to VIP customers
--   - Sales team can offer personalized assistance
--   - Marketing can trigger special offers to close the sale
--   - Prevent high-value cart abandonment
--
-- Data Sources:
--   - Iceberg: customers_details (customer tier information)
--   - Iceberg: customers_orders (calculate lifetime value)
--   - Cassandra: customer_sessions (real-time checkout status)
--
-- Key Metrics:
--   - Lifetime Value: Total historical spend
--   - Customer Tier: Gold/Platinum customers only
--   - Current Page: Must be at 'checkout'
--   - Items in Cart: Number of items about to purchase
--
-- Filters Applied:
--   - Only Gold and Platinum tier customers
--   - Currently on checkout page
--   - Lifetime value > $1000 (configurable threshold)
--
-- Performance Notes:
--   - INNER JOIN on sessions ensures only active customers
--   - Predicate pushdown to Cassandra for current_page filter
--   - Aggregation on Iceberg for lifetime value calculation
--
-- Alert Triggers:
--   - High-value customer at checkout for > 5 minutes
--   - VIP customer with cart value > $5000
--   - Platinum customer showing hesitation (multiple page visits)
--
-- ============================================================================

SELECT 
    c.customer_id,
    c.name,
    c.email,
    c.customer_tier,
    c.city,
    c.country,
    
    -- Historical Value
    COUNT(DISTINCT o.order_id) AS total_past_orders,
    SUM(o.amount) AS lifetime_value,
    AVG(o.amount) AS avg_order_value,
    MAX(o.order_date) AS last_purchase_date,
    
    -- Current Session
    s.current_page,
    s.items_in_cart,
    s.session_duration_minutes,
    s.last_active_time,
    
    -- Calculated Fields
    DATEDIFF(CURRENT_DATE, MAX(o.order_date)) AS days_since_last_order,
    CASE 
        WHEN s.session_duration_minutes > 10 THEN 'Needs Assistance'
        WHEN s.session_duration_minutes > 5 THEN 'Monitor'
        ELSE 'Normal'
    END AS support_priority

FROM iceberg_data.customers_schema.customers_details c

-- INNER JOIN to get only customers with orders
JOIN iceberg_data.customers_schema.customers_orders o 
    ON c.customer_id = o.customer_id

-- INNER JOIN to get only active customers at checkout
JOIN astradb_catalog.customers.customer_sessions s 
    ON c.customer_id = s.customer_id

WHERE 
    -- Filter 1: Only checkout page (case-insensitive)
    LOWER(s.current_page) = 'checkout'
    
    -- Filter 2: Only high-tier customers
    AND c.customer_tier IN ('Gold', 'Platinum')

GROUP BY 
    c.customer_id, 
    c.name, 
    c.email,
    c.customer_tier,
    c.city,
    c.country,
    s.current_page, 
    s.items_in_cart,
    s.session_duration_minutes,
    s.last_active_time

-- Filter 3: Only customers with significant lifetime value
HAVING SUM(o.amount) > 1000

-- Order by most valuable customers first
ORDER BY lifetime_value DESC, s.session_duration_minutes DESC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id              : Unique customer identifier
-- name                     : Customer full name
-- email                    : Contact email for outreach
-- customer_tier            : Gold or Platinum
-- city                     : Customer location
-- country                  : Customer country
-- total_past_orders        : Number of completed orders
-- lifetime_value           : Total historical spend (USD)
-- avg_order_value          : Average order amount
-- last_purchase_date       : Date of last order
-- current_page             : Should be 'checkout'
-- items_in_cart            : Number of items in current cart
-- session_duration_minutes : Time spent at checkout
-- last_active_time         : Last activity timestamp
-- days_since_last_order    : Days since last purchase
-- support_priority         : Needs Assistance/Monitor/Normal
-- ============================================================================

-- ============================================================================
-- Action Items Based on Results:
-- ============================================================================
-- 1. support_priority = 'Needs Assistance'
--    → Trigger live chat popup
--    → Assign dedicated support agent
--    → Offer phone callback
--
-- 2. lifetime_value > $5000 AND customer_tier = 'Platinum'
--    → Offer exclusive discount
--    → Free expedited shipping
--    → Personal shopper assistance
--
-- 3. session_duration_minutes > 10
--    → Check for technical issues
--    → Offer help with payment
--    → Provide alternative payment methods
--
-- 4. days_since_last_order > 90
--    → Welcome back offer
--    → Highlight new products
--    → Loyalty points reminder
-- ============================================================================

-- Made with Bob
