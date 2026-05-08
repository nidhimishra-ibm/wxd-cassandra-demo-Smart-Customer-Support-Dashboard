-- ============================================================================
-- Query 3: Abandoned Cart Recovery
-- ============================================================================
-- 
-- Purpose: Identify customers who have items in cart but haven't completed
--          checkout, prioritized by customer value and cart abandonment time
--
-- Business Use Case: 
--   - Trigger automated email/SMS reminders
--   - Offer time-limited discounts to recover sales
--   - Identify friction points in checkout process
--   - Calculate potential revenue at risk
--
-- Data Sources:
--   - Iceberg: customers_details (customer profile)
--   - Iceberg: customers_orders (lifetime value calculation)
--   - Cassandra: customer_sessions (cart status and activity)
--
-- Key Metrics:
--   - Items in Cart: Number of abandoned items
--   - Time Since Active: Hours since last activity
--   - Lifetime Value: Historical customer value
--   - Recovery Priority: High/Medium/Low based on value and urgency
--
-- Abandonment Criteria:
--   - Has items in cart (items_in_cart > 0)
--   - On cart or checkout page
--   - Inactive for > 1 hour
--
-- Performance Notes:
--   - Filter on Cassandra first for active sessions
--   - Calculate time difference for abandonment detection
--   - Aggregate Iceberg data for customer value
--
-- ============================================================================

SELECT 
    c.customer_id,
    c.name,
    c.email,
    c.customer_tier,
    c.city,
    c.country,
    
    -- Historical Customer Value
    COUNT(DISTINCT o.order_id) AS total_past_orders,
    SUM(o.amount) AS lifetime_value,
    AVG(o.amount) AS avg_order_value,
    
    -- Cart Information
    s.items_in_cart,
    s.current_page,
    s.session_duration_minutes,
    s.last_active_time,
    
    -- Abandonment Metrics
    CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) AS hours_since_active,
    
    -- Estimated Cart Value (assuming avg order value per item)
    CASE 
        WHEN COUNT(DISTINCT o.order_id) > 0 
        THEN CAST(s.items_in_cart * (SUM(o.amount) / COUNT(DISTINCT o.order_id)) AS DECIMAL(10,2))
        ELSE s.items_in_cart * 50.0  -- Default estimate
    END AS estimated_cart_value,
    
    -- Recovery Priority
    CASE 
        WHEN c.customer_tier IN ('Platinum', 'Gold') AND s.items_in_cart >= 3 
            THEN 'High Priority'
        WHEN c.customer_tier IN ('Platinum', 'Gold') OR s.items_in_cart >= 2 
            THEN 'Medium Priority'
        ELSE 'Low Priority'
    END AS recovery_priority,
    
    -- Recommended Action
    CASE 
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) < 2 
            THEN 'Send Browser Push Notification'
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) < 6 
            THEN 'Send Email Reminder'
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) < 24 
            THEN 'Send Email with 10% Discount'
        ELSE 'Send Email with 15% Discount'
    END AS recommended_action,
    
    -- Discount Amount
    CASE 
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) < 6 
            THEN 0
        WHEN CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) < 24 
            THEN CAST(s.items_in_cart * (SUM(o.amount) / COUNT(DISTINCT o.order_id)) * 0.10 AS DECIMAL(10,2))
        ELSE CAST(s.items_in_cart * (SUM(o.amount) / COUNT(DISTINCT o.order_id)) * 0.15 AS DECIMAL(10,2))
    END AS suggested_discount_amount

FROM iceberg_data.customers_schema.customers_details c

-- Join historical orders for value calculation
LEFT JOIN iceberg_data.customers_schema.customers_orders o 
    ON c.customer_id = o.customer_id

-- Join active sessions with items in cart
JOIN astradb_catalog.customers.customer_sessions s 
    ON c.customer_id = s.customer_id

WHERE 
    -- Must have items in cart
    s.items_in_cart > 0
    
    -- On cart or checkout page
    AND LOWER(s.current_page) IN ('cart', 'checkout')
    
    -- Inactive for more than 1 hour
    AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) > 1

GROUP BY 
    c.customer_id, 
    c.name, 
    c.email, 
    c.customer_tier,
    c.city,
    c.country,
    s.items_in_cart, 
    s.current_page,
    s.session_duration_minutes,
    s.last_active_time

-- Order by priority and potential value
ORDER BY 
    CASE recovery_priority
        WHEN 'High Priority' THEN 1
        WHEN 'Medium Priority' THEN 2
        ELSE 3
    END,
    estimated_cart_value DESC,
    hours_since_active ASC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id                  : Unique customer identifier
-- name                         : Customer full name
-- email                        : Email for recovery campaign
-- customer_tier                : Loyalty tier
-- city                         : Customer location
-- country                      : Customer country
-- total_past_orders            : Number of completed orders
-- lifetime_value               : Total historical spend
-- avg_order_value              : Average order amount
-- items_in_cart                : Number of abandoned items
-- current_page                 : cart or checkout
-- session_duration_minutes     : Time spent before abandoning
-- last_active_time             : When they last interacted
-- hours_since_active           : Hours since abandonment
-- estimated_cart_value         : Estimated value of abandoned cart
-- recovery_priority            : High/Medium/Low Priority
-- recommended_action           : Next step to take
-- suggested_discount_amount    : Discount to offer (USD)
-- ============================================================================

-- ============================================================================
-- Recovery Campaign Strategy:
-- ============================================================================
-- 
-- IMMEDIATE (< 2 hours):
--   - Browser push notification
--   - "You left items in your cart!"
--   - No discount needed
--   - Conversion rate: ~15-20%
--
-- SHORT-TERM (2-6 hours):
--   - Email reminder
--   - "Don't forget your items"
--   - Show product images
--   - No discount yet
--   - Conversion rate: ~10-15%
--
-- MEDIUM-TERM (6-24 hours):
--   - Email with 10% discount
--   - "Complete your purchase and save 10%"
--   - Time-limited offer (24 hours)
--   - Conversion rate: ~20-25%
--
-- LONG-TERM (> 24 hours):
--   - Email with 15% discount
--   - "Last chance - 15% off your cart"
--   - Urgency messaging
--   - Conversion rate: ~15-20%
--
-- HIGH PRIORITY CUSTOMERS:
--   - Personal phone call
--   - Dedicated support chat
--   - Free shipping offer
--   - VIP treatment
--
-- ============================================================================

-- ============================================================================
-- Automation Integration:
-- ============================================================================
-- 
-- This query can be scheduled to run every hour and trigger:
-- 
-- 1. Marketing Automation Platform (e.g., Mailchimp, SendGrid)
--    - Send personalized recovery emails
--    - Include dynamic discount codes
--    - Track email opens and clicks
--
-- 2. CRM System (e.g., Salesforce)
--    - Create follow-up tasks for sales team
--    - Log abandonment events
--    - Track recovery success rate
--
-- 3. Push Notification Service
--    - Send browser/mobile notifications
--    - Personalized messaging
--    - Deep link to cart
--
-- 4. Analytics Dashboard
--    - Monitor abandonment rates
--    - Track recovery conversion
--    - Calculate ROI of campaigns
--
-- ============================================================================

-- Made with Bob
