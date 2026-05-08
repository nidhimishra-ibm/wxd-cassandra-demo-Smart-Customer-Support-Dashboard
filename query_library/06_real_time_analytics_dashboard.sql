-- ============================================================================
-- Query 6: Real-Time Analytics Dashboard
-- ============================================================================
-- 
-- Purpose: Provide a comprehensive real-time view of current customer activity
--          combined with historical context for operational dashboards
--
-- Business Use Case: 
--   - Monitor live customer activity on website
--   - Track real-time conversion metrics
--   - Identify immediate support opportunities
--   - Display on operations dashboard/TV screens
--   - Alert on anomalies or high-value activities
--
-- Data Sources:
--   - Cassandra: customer_sessions (real-time activity)
--   - Cassandra: recent_transactions (latest transactions)
--   - Iceberg: customers_details (customer profiles)
--   - Iceberg: customers_orders (historical value)
--
-- Key Metrics:
--   - Active users by page
--   - Customers at checkout
--   - Pending transactions
--   - High-value customers online
--   - Cart abandonment risk
--
-- Refresh Rate: Real-time (< 1 second latency from Cassandra)
--
-- Performance Notes:
--   - Optimized for dashboard display
--   - Minimal aggregations for speed
--   - Cassandra queries use partition keys
--
-- ============================================================================

-- Main Dashboard Query
SELECT 
    -- Customer Identity
    c.customer_id,
    c.name,
    c.customer_tier,
    c.city,
    c.country,
    
    -- Historical Context
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.amount) AS lifetime_value,
    MAX(o.order_date) AS last_order_date,
    
    -- Real-Time Activity
    s.current_page,
    s.items_in_cart,
    s.session_duration_minutes,
    s.last_active_time,
    
    -- Recent Transaction Status
    t.transaction_id,
    t.status AS transaction_status,
    t.amount AS transaction_amount,
    t.payment_method,
    t.transaction_time,
    
    -- Calculated Metrics
    CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) AS minutes_since_active,
    
    -- Activity Status
    CASE 
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 1 
            THEN 'Active Now'
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 5 
            THEN 'Recently Active'
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 15 
            THEN 'Idle'
        ELSE 'Inactive'
    END AS activity_status,
    
    -- Conversion Likelihood
    CASE 
        WHEN s.current_page = 'checkout' AND s.items_in_cart > 0 THEN 'Very High'
        WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 'High'
        WHEN s.current_page = 'product_page' THEN 'Medium'
        WHEN s.current_page = 'search_results' THEN 'Low'
        ELSE 'Very Low'
    END AS conversion_likelihood,
    
    -- Alert Priority
    CASE 
        WHEN c.customer_tier IN ('Platinum', 'Gold') 
            AND s.current_page = 'checkout' 
            AND s.session_duration_minutes > 5 
            THEN 'URGENT: VIP at checkout needs help'
        WHEN s.current_page = 'checkout' 
            AND s.items_in_cart > 3 
            AND s.session_duration_minutes > 10 
            THEN 'HIGH: Large cart stuck at checkout'
        WHEN c.customer_tier IN ('Platinum', 'Gold') 
            AND s.items_in_cart > 0 
            AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) > 5 
            THEN 'MEDIUM: VIP cart abandonment risk'
        WHEN t.status = 'pending' 
            AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(t.transaction_time)) / 60.0 AS DECIMAL(10,2)) > 10 
            THEN 'MEDIUM: Transaction pending too long'
        ELSE 'Normal'
    END AS alert_priority

FROM astradb_catalog.customers.customer_sessions s

-- Join customer profile
LEFT JOIN iceberg_data.customers_schema.customers_details c 
    ON s.customer_id = c.customer_id

-- Join historical orders
LEFT JOIN iceberg_data.customers_schema.customers_orders o 
    ON c.customer_id = o.customer_id

-- Join recent transactions
LEFT JOIN astradb_catalog.customers.recent_transactions t 
    ON c.customer_id = t.customer_id

WHERE 
    -- Only show active or recently active sessions
    CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 30

GROUP BY 
    c.customer_id, c.name, c.customer_tier, c.city, c.country,
    s.current_page, s.items_in_cart, s.session_duration_minutes, s.last_active_time,
    t.transaction_id, t.status, t.amount, t.payment_method, t.transaction_time

ORDER BY 
    CASE alert_priority
        WHEN 'URGENT: VIP at checkout needs help' THEN 1
        WHEN 'HIGH: Large cart stuck at checkout' THEN 2
        WHEN 'MEDIUM: VIP cart abandonment risk' THEN 3
        WHEN 'MEDIUM: Transaction pending too long' THEN 4
        ELSE 5
    END,
    lifetime_value DESC,
    s.last_active_time DESC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id              : Unique customer identifier
-- name                     : Customer full name
-- customer_tier            : Loyalty tier
-- city                     : Customer city
-- country                  : Customer country
-- total_orders             : Historical order count
-- lifetime_value           : Total historical spend
-- last_order_date          : Most recent order
-- current_page             : Page currently viewing
-- items_in_cart            : Items in shopping cart
-- session_duration_minutes : Time on current page
-- last_active_time         : Last activity timestamp
-- transaction_id           : Recent transaction ID
-- transaction_status       : pending/completed/failed
-- transaction_amount       : Transaction amount
-- payment_method           : Payment method used
-- transaction_time         : Transaction timestamp
-- minutes_since_active     : Minutes since last activity
-- activity_status          : Active Now/Recently Active/Idle/Inactive
-- conversion_likelihood    : Very High/High/Medium/Low/Very Low
-- alert_priority           : Alert level and message
-- ============================================================================

-- ============================================================================
-- Dashboard KPIs (Summary Queries):
-- ============================================================================

-- KPI 1: Active Users by Page
-- SELECT 
--     s.current_page,
--     COUNT(DISTINCT s.customer_id) AS active_users,
--     SUM(s.items_in_cart) AS total_items_in_carts
-- FROM astradb_catalog.customers.customer_sessions s
-- WHERE CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 5
-- GROUP BY s.current_page
-- ORDER BY active_users DESC;

-- KPI 2: Customers at Checkout
-- SELECT 
--     COUNT(DISTINCT s.customer_id) AS customers_at_checkout,
--     SUM(s.items_in_cart) AS total_items,
--     AVG(s.session_duration_minutes) AS avg_time_at_checkout
-- FROM astradb_catalog.customers.customer_sessions s
-- WHERE LOWER(s.current_page) = 'checkout'
--   AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 5;

-- KPI 3: Pending Transactions
-- SELECT 
--     COUNT(*) AS pending_transactions,
--     SUM(amount) AS pending_amount,
--     AVG(CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(transaction_time)) / 60.0 AS DECIMAL(10,2))) AS avg_pending_minutes
-- FROM astradb_catalog.customers.recent_transactions
-- WHERE status = 'pending';

-- KPI 4: High-Value Customers Online
-- SELECT 
--     COUNT(DISTINCT c.customer_id) AS vip_customers_online,
--     SUM(s.items_in_cart) AS vip_items_in_cart
-- FROM astradb_catalog.customers.customer_sessions s
-- JOIN iceberg_data.customers_schema.customers_details c ON s.customer_id = c.customer_id
-- WHERE c.customer_tier IN ('Platinum', 'Gold')
--   AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) <= 5;

-- KPI 5: Cart Abandonment Risk
-- SELECT 
--     COUNT(DISTINCT s.customer_id) AS at_risk_carts,
--     SUM(s.items_in_cart) AS at_risk_items
-- FROM astradb_catalog.customers.customer_sessions s
-- WHERE s.items_in_cart > 0
--   AND LOWER(s.current_page) IN ('cart', 'checkout')
--   AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 60.0 AS DECIMAL(10,2)) BETWEEN 5 AND 30;

-- ============================================================================
-- Alert Rules for Operations Team:
-- ============================================================================
-- 
-- CRITICAL ALERTS (Immediate Action):
-- 1. VIP customer at checkout > 5 minutes
--    → Trigger: Live chat popup
--    → Action: Assign senior support agent
--    → SLA: < 30 seconds response
--
-- 2. Transaction pending > 15 minutes
--    → Trigger: Payment system check
--    → Action: Contact customer
--    → SLA: < 2 minutes investigation
--
-- HIGH PRIORITY ALERTS:
-- 3. Large cart (>3 items) stuck at checkout > 10 minutes
--    → Trigger: Proactive support offer
--    → Action: Check for technical issues
--    → SLA: < 5 minutes response
--
-- 4. VIP customer cart idle > 5 minutes
--    → Trigger: Personalized offer
--    → Action: Send discount code
--    → SLA: < 10 minutes
--
-- MEDIUM PRIORITY ALERTS:
-- 5. Multiple failed transactions from same customer
--    → Trigger: Payment method review
--    → Action: Suggest alternative payment
--    → SLA: < 15 minutes
--
-- 6. High session duration without purchase
--    → Trigger: Usability issue investigation
--    → Action: A/B test review
--    → SLA: Daily review
--
-- ============================================================================

-- ============================================================================
-- Dashboard Visualization Recommendations:
-- ============================================================================
-- 
-- REAL-TIME METRICS (Update every 5 seconds):
-- - Active users count (large number display)
-- - Customers at checkout (with trend arrow)
-- - Pending transactions value (with alert indicator)
-- - VIP customers online (highlighted)
--
-- CHARTS:
-- - Line chart: Active users over last hour
-- - Bar chart: Users by page (horizontal bars)
-- - Pie chart: Customer tier distribution of active users
-- - Heatmap: Activity by hour and day of week
--
-- ALERTS PANEL:
-- - Scrolling list of priority alerts
-- - Color-coded by urgency (red/orange/yellow)
-- - Click to view customer details
-- - One-click action buttons
--
-- CUSTOMER LIST:
-- - Sortable table with all columns
-- - Filter by tier, page, alert level
-- - Search by customer name/ID
-- - Click row to open customer 360 view
--
-- ============================================================================

-- ============================================================================
-- Integration Points:
-- ============================================================================
-- 
-- 1. Live Chat System:
--    - Auto-trigger chat for URGENT alerts
--    - Pre-populate customer context
--    - Show lifetime value to agent
--
-- 2. CRM System:
--    - Log all alerts as activities
--    - Update customer engagement score
--    - Track support interactions
--
-- 3. Marketing Automation:
--    - Trigger personalized offers
--    - Send cart recovery emails
--    - Update customer segments
--
-- 4. Analytics Platform:
--    - Stream metrics to data warehouse
--    - Calculate conversion funnels
--    - Generate daily reports
--
-- 5. Notification System:
--    - Slack/Teams alerts for URGENT
--    - Email digest for daily summary
--    - SMS for critical issues
--
-- ============================================================================

-- Made with Bob
