-- ============================================================================
-- Query 4: Customer Engagement Score
-- ============================================================================
-- 
-- Purpose: Calculate a comprehensive engagement score for each customer based
--          on historical behavior and real-time activity
--
-- Business Use Case: 
--   - Identify most engaged customers for loyalty programs
--   - Predict customer churn risk
--   - Personalize marketing campaigns
--   - Prioritize customer support resources
--   - Segment customers for targeted offers
--
-- Data Sources:
--   - Iceberg: customers_details (profile and tenure)
--   - Iceberg: customers_orders (purchase frequency and recency)
--   - Cassandra: customer_sessions (current engagement level)
--
-- Scoring Components:
--   1. Recency Score (0-30 points): How recently they purchased
--   2. Frequency Score (0-30 points): How often they purchase
--   3. Monetary Score (0-30 points): How much they spend
--   4. Activity Score (0-10 points): Current website engagement
--
-- Total Score Range: 0-100 points
--
-- Performance Notes:
--   - Aggregates historical data from Iceberg
--   - Joins real-time activity from Cassandra
--   - Uses CASE statements for score calculation
--
-- ============================================================================

SELECT 
    c.customer_id,
    c.name,
    c.email,
    c.customer_tier,
    c.signup_date,
    
    -- Historical Metrics
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.amount) AS lifetime_value,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF(CURRENT_DATE, MAX(o.order_date)) AS days_since_last_order,
    DATEDIFF(CURRENT_DATE, c.signup_date) AS customer_age_days,
    
    -- Real-Time Activity
    s.current_page,
    s.session_duration_minutes,
    s.items_in_cart,
    s.last_active_time,
    
    -- Recency Score (0-30 points)
    CASE 
        WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 7 THEN 30
        WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 30 THEN 25
        WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 60 THEN 20
        WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 90 THEN 15
        WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 180 THEN 10
        WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 365 THEN 5
        ELSE 0
    END AS recency_score,
    
    -- Frequency Score (0-30 points)
    CASE 
        WHEN COUNT(DISTINCT o.order_id) >= 20 THEN 30
        WHEN COUNT(DISTINCT o.order_id) >= 15 THEN 25
        WHEN COUNT(DISTINCT o.order_id) >= 10 THEN 20
        WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 15
        WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 10
        WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 5
        ELSE 0
    END AS frequency_score,
    
    -- Monetary Score (0-30 points)
    CASE 
        WHEN SUM(o.amount) >= 10000 THEN 30
        WHEN SUM(o.amount) >= 5000 THEN 25
        WHEN SUM(o.amount) >= 2000 THEN 20
        WHEN SUM(o.amount) >= 1000 THEN 15
        WHEN SUM(o.amount) >= 500 THEN 10
        WHEN SUM(o.amount) >= 100 THEN 5
        ELSE 0
    END AS monetary_score,
    
    -- Activity Score (0-10 points) - Real-time engagement
    CASE 
        WHEN s.current_page = 'checkout' THEN 10
        WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 8
        WHEN s.current_page = 'product_page' THEN 6
        WHEN s.current_page = 'search_results' THEN 4
        WHEN s.current_page = 'homepage' THEN 2
        ELSE 0
    END AS activity_score,
    
    -- Total Engagement Score (0-100)
    (
        -- Recency Score
        CASE 
            WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 7 THEN 30
            WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 30 THEN 25
            WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 60 THEN 20
            WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 90 THEN 15
            WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 180 THEN 10
            WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 365 THEN 5
            ELSE 0
        END +
        -- Frequency Score
        CASE 
            WHEN COUNT(DISTINCT o.order_id) >= 20 THEN 30
            WHEN COUNT(DISTINCT o.order_id) >= 15 THEN 25
            WHEN COUNT(DISTINCT o.order_id) >= 10 THEN 20
            WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 15
            WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 10
            WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 5
            ELSE 0
        END +
        -- Monetary Score
        CASE 
            WHEN SUM(o.amount) >= 10000 THEN 30
            WHEN SUM(o.amount) >= 5000 THEN 25
            WHEN SUM(o.amount) >= 2000 THEN 20
            WHEN SUM(o.amount) >= 1000 THEN 15
            WHEN SUM(o.amount) >= 500 THEN 10
            WHEN SUM(o.amount) >= 100 THEN 5
            ELSE 0
        END +
        -- Activity Score
        CASE 
            WHEN s.current_page = 'checkout' THEN 10
            WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 8
            WHEN s.current_page = 'product_page' THEN 6
            WHEN s.current_page = 'search_results' THEN 4
            WHEN s.current_page = 'homepage' THEN 2
            ELSE 0
        END
    ) AS total_engagement_score,
    
    -- Engagement Segment
    CASE 
        WHEN (
            CASE 
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 7 THEN 30
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 30 THEN 25
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 60 THEN 20
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 90 THEN 15
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 180 THEN 10
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 365 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN COUNT(DISTINCT o.order_id) >= 20 THEN 30
                WHEN COUNT(DISTINCT o.order_id) >= 15 THEN 25
                WHEN COUNT(DISTINCT o.order_id) >= 10 THEN 20
                WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 15
                WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 10
                WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN SUM(o.amount) >= 10000 THEN 30
                WHEN SUM(o.amount) >= 5000 THEN 25
                WHEN SUM(o.amount) >= 2000 THEN 20
                WHEN SUM(o.amount) >= 1000 THEN 15
                WHEN SUM(o.amount) >= 500 THEN 10
                WHEN SUM(o.amount) >= 100 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN s.current_page = 'checkout' THEN 10
                WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 8
                WHEN s.current_page = 'product_page' THEN 6
                WHEN s.current_page = 'search_results' THEN 4
                WHEN s.current_page = 'homepage' THEN 2
                ELSE 0
            END
        ) >= 80 THEN 'Champions'
        WHEN (
            CASE 
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 7 THEN 30
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 30 THEN 25
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 60 THEN 20
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 90 THEN 15
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 180 THEN 10
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 365 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN COUNT(DISTINCT o.order_id) >= 20 THEN 30
                WHEN COUNT(DISTINCT o.order_id) >= 15 THEN 25
                WHEN COUNT(DISTINCT o.order_id) >= 10 THEN 20
                WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 15
                WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 10
                WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN SUM(o.amount) >= 10000 THEN 30
                WHEN SUM(o.amount) >= 5000 THEN 25
                WHEN SUM(o.amount) >= 2000 THEN 20
                WHEN SUM(o.amount) >= 1000 THEN 15
                WHEN SUM(o.amount) >= 500 THEN 10
                WHEN SUM(o.amount) >= 100 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN s.current_page = 'checkout' THEN 10
                WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 8
                WHEN s.current_page = 'product_page' THEN 6
                WHEN s.current_page = 'search_results' THEN 4
                WHEN s.current_page = 'homepage' THEN 2
                ELSE 0
            END
        ) >= 60 THEN 'Loyal Customers'
        WHEN (
            CASE 
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 7 THEN 30
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 30 THEN 25
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 60 THEN 20
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 90 THEN 15
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 180 THEN 10
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 365 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN COUNT(DISTINCT o.order_id) >= 20 THEN 30
                WHEN COUNT(DISTINCT o.order_id) >= 15 THEN 25
                WHEN COUNT(DISTINCT o.order_id) >= 10 THEN 20
                WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 15
                WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 10
                WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN SUM(o.amount) >= 10000 THEN 30
                WHEN SUM(o.amount) >= 5000 THEN 25
                WHEN SUM(o.amount) >= 2000 THEN 20
                WHEN SUM(o.amount) >= 1000 THEN 15
                WHEN SUM(o.amount) >= 500 THEN 10
                WHEN SUM(o.amount) >= 100 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN s.current_page = 'checkout' THEN 10
                WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 8
                WHEN s.current_page = 'product_page' THEN 6
                WHEN s.current_page = 'search_results' THEN 4
                WHEN s.current_page = 'homepage' THEN 2
                ELSE 0
            END
        ) >= 40 THEN 'Potential Loyalists'
        WHEN (
            CASE 
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 7 THEN 30
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 30 THEN 25
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 60 THEN 20
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 90 THEN 15
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 180 THEN 10
                WHEN DATEDIFF(CURRENT_DATE, MAX(o.order_date)) <= 365 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN COUNT(DISTINCT o.order_id) >= 20 THEN 30
                WHEN COUNT(DISTINCT o.order_id) >= 15 THEN 25
                WHEN COUNT(DISTINCT o.order_id) >= 10 THEN 20
                WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 15
                WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 10
                WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN SUM(o.amount) >= 10000 THEN 30
                WHEN SUM(o.amount) >= 5000 THEN 25
                WHEN SUM(o.amount) >= 2000 THEN 20
                WHEN SUM(o.amount) >= 1000 THEN 15
                WHEN SUM(o.amount) >= 500 THEN 10
                WHEN SUM(o.amount) >= 100 THEN 5
                ELSE 0
            END +
            CASE 
                WHEN s.current_page = 'checkout' THEN 10
                WHEN s.current_page = 'cart' AND s.items_in_cart > 0 THEN 8
                WHEN s.current_page = 'product_page' THEN 6
                WHEN s.current_page = 'search_results' THEN 4
                WHEN s.current_page = 'homepage' THEN 2
                ELSE 0
            END
        ) >= 20 THEN 'At Risk'
        ELSE 'Hibernating'
    END AS engagement_segment

FROM iceberg_data.customers_schema.customers_details c

LEFT JOIN iceberg_data.customers_schema.customers_orders o 
    ON c.customer_id = o.customer_id

LEFT JOIN astradb_catalog.customers.customer_sessions s 
    ON c.customer_id = s.customer_id

GROUP BY 
    c.customer_id, 
    c.name, 
    c.email, 
    c.customer_tier,
    c.signup_date,
    s.current_page, 
    s.session_duration_minutes, 
    s.items_in_cart,
    s.last_active_time

ORDER BY total_engagement_score DESC, lifetime_value DESC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id              : Unique customer identifier
-- name                     : Customer full name
-- email                    : Customer email
-- customer_tier            : Loyalty tier
-- signup_date              : Registration date
-- total_orders             : Number of orders
-- lifetime_value           : Total spend
-- last_order_date          : Most recent order
-- days_since_last_order    : Recency metric
-- customer_age_days        : Days since signup
-- current_page             : Current page viewing
-- session_duration_minutes : Current session time
-- items_in_cart            : Items in cart
-- last_active_time         : Last activity timestamp
-- recency_score            : 0-30 points
-- frequency_score          : 0-30 points
-- monetary_score           : 0-30 points
-- activity_score           : 0-10 points
-- total_engagement_score   : 0-100 points
-- engagement_segment       : Champions/Loyal/Potential/At Risk/Hibernating
-- ============================================================================

-- ============================================================================
-- Engagement Segments & Actions:
-- ============================================================================
-- 
-- CHAMPIONS (80-100 points):
--   - Your best customers
--   - Actions: VIP treatment, early access, exclusive offers
--   - Retention: Very high priority
--
-- LOYAL CUSTOMERS (60-79 points):
--   - Regular purchasers with good value
--   - Actions: Loyalty rewards, referral programs
--   - Retention: High priority
--
-- POTENTIAL LOYALISTS (40-59 points):
--   - Recent customers with growth potential
--   - Actions: Engagement campaigns, product recommendations
--   - Retention: Medium priority
--
-- AT RISK (20-39 points):
--   - Declining engagement
--   - Actions: Win-back campaigns, special offers
--   - Retention: High priority (prevent churn)
--
-- HIBERNATING (0-19 points):
--   - Inactive or very low engagement
--   - Actions: Re-engagement campaigns, surveys
--   - Retention: Low priority (focus on reactivation)
--
-- ============================================================================

-- Made with Bob
