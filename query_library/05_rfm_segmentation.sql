-- ============================================================================
-- Query 5: RFM Segmentation (Recency, Frequency, Monetary)
-- ============================================================================
-- 
-- Purpose: Segment customers using RFM analysis - a proven marketing technique
--          to identify customer value and behavior patterns
--
-- Business Use Case: 
--   - Target marketing campaigns to specific customer segments
--   - Allocate marketing budget efficiently
--   - Predict customer lifetime value
--   - Identify customers at risk of churning
--   - Personalize customer communications
--
-- Data Sources:
--   - Iceberg: customers_details (customer profile)
--   - Iceberg: customers_orders (purchase history)
--   - Cassandra: customer_sessions (current engagement)
--
-- RFM Components:
--   - Recency (R): How recently did the customer purchase?
--   - Frequency (F): How often do they purchase?
--   - Monetary (M): How much do they spend?
--
-- Scoring Method:
--   - Each component scored 1-5 (5 = best)
--   - Combined RFM score: 111 to 555
--   - Segments based on score patterns
--
-- Performance Notes:
--   - Uses NTILE for quintile calculation
--   - Aggregates historical data from Iceberg
--   - Joins real-time activity for enhanced insights
--
-- ============================================================================

WITH customer_rfm AS (
    SELECT 
        c.customer_id,
        c.name,
        c.email,
        c.customer_tier,
        c.city,
        c.country,
        c.signup_date,
        
        -- Recency: Days since last order
        DATEDIFF(CURRENT_DATE, MAX(o.order_date)) AS recency_days,
        
        -- Frequency: Total number of orders
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        
        -- Monetary: Total amount spent
        SUM(o.amount) AS monetary_value,
        
        -- Additional metrics
        AVG(o.amount) AS avg_order_value,
        MAX(o.order_date) AS last_order_date,
        MIN(o.order_date) AS first_order_date
        
    FROM iceberg_data.customers_schema.customers_details c
    LEFT JOIN iceberg_data.customers_schema.customers_orders o 
        ON c.customer_id = o.customer_id
    GROUP BY 
        c.customer_id, c.name, c.email, c.customer_tier,
        c.city, c.country, c.signup_date
),

rfm_scores AS (
    SELECT 
        *,
        -- Recency Score (5 = most recent, 1 = least recent)
        -- Lower recency_days = better (more recent)
        CASE 
            WHEN recency_days IS NULL THEN 0
            WHEN recency_days <= 30 THEN 5
            WHEN recency_days <= 60 THEN 4
            WHEN recency_days <= 90 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END AS r_score,
        
        -- Frequency Score (5 = most frequent, 1 = least frequent)
        CASE 
            WHEN frequency_orders >= 20 THEN 5
            WHEN frequency_orders >= 10 THEN 4
            WHEN frequency_orders >= 5 THEN 3
            WHEN frequency_orders >= 2 THEN 2
            WHEN frequency_orders >= 1 THEN 1
            ELSE 0
        END AS f_score,
        
        -- Monetary Score (5 = highest spend, 1 = lowest spend)
        CASE 
            WHEN monetary_value >= 10000 THEN 5
            WHEN monetary_value >= 5000 THEN 4
            WHEN monetary_value >= 2000 THEN 3
            WHEN monetary_value >= 500 THEN 2
            WHEN monetary_value >= 100 THEN 1
            ELSE 0
        END AS m_score
        
    FROM customer_rfm
)

SELECT 
    r.customer_id,
    r.name,
    r.email,
    r.customer_tier,
    r.city,
    r.country,
    r.signup_date,
    
    -- RFM Metrics
    r.recency_days,
    r.frequency_orders,
    r.monetary_value,
    r.avg_order_value,
    r.last_order_date,
    r.first_order_date,
    
    -- RFM Scores
    r.r_score,
    r.f_score,
    r.m_score,
    CONCAT(CAST(r.r_score AS VARCHAR), CAST(r.f_score AS VARCHAR), CAST(r.m_score AS VARCHAR)) AS rfm_score,
    
    -- Real-Time Activity
    s.current_page,
    s.items_in_cart,
    s.session_duration_minutes,
    s.last_active_time,
    
    -- RFM Segment Classification
    CASE 
        -- Champions: Best customers (bought recently, buy often, spend most)
        WHEN r.r_score >= 4 AND r.f_score >= 4 AND r.m_score >= 4 THEN 'Champions'
        
        -- Loyal Customers: Buy regularly, good spenders
        WHEN r.r_score >= 3 AND r.f_score >= 4 AND r.m_score >= 3 THEN 'Loyal Customers'
        
        -- Potential Loyalists: Recent customers with good frequency
        WHEN r.r_score >= 4 AND r.f_score >= 2 AND r.m_score >= 2 THEN 'Potential Loyalists'
        
        -- New Customers: Recent first-time buyers
        WHEN r.r_score >= 4 AND r.f_score <= 2 AND r.m_score >= 1 THEN 'New Customers'
        
        -- Promising: Recent shoppers with potential
        WHEN r.r_score >= 3 AND r.f_score <= 2 AND r.m_score >= 2 THEN 'Promising'
        
        -- Need Attention: Above average recency, frequency, and monetary
        WHEN r.r_score >= 3 AND r.f_score >= 3 AND r.m_score >= 3 THEN 'Need Attention'
        
        -- About to Sleep: Below average recency, frequency, and monetary
        WHEN r.r_score >= 2 AND r.f_score >= 2 AND r.m_score >= 2 THEN 'About to Sleep'
        
        -- At Risk: Spent big, purchased often, but long ago
        WHEN r.r_score <= 2 AND r.f_score >= 3 AND r.m_score >= 3 THEN 'At Risk'
        
        -- Cannot Lose Them: Made big purchases, haven't returned
        WHEN r.r_score <= 2 AND r.f_score >= 4 AND r.m_score >= 4 THEN 'Cannot Lose Them'
        
        -- Hibernating: Last purchase long ago, low frequency
        WHEN r.r_score <= 2 AND r.f_score <= 2 AND r.m_score >= 2 THEN 'Hibernating'
        
        -- Lost: Lowest recency, frequency, and monetary scores
        WHEN r.r_score <= 2 AND r.f_score <= 2 AND r.m_score <= 2 THEN 'Lost'
        
        ELSE 'Other'
    END AS rfm_segment,
    
    -- Recommended Action
    CASE 
        WHEN r.r_score >= 4 AND r.f_score >= 4 AND r.m_score >= 4 
            THEN 'Reward them. They are your best customers!'
        
        WHEN r.r_score >= 3 AND r.f_score >= 4 AND r.m_score >= 3 
            THEN 'Upsell higher value products. Engage them.'
        
        WHEN r.r_score >= 4 AND r.f_score >= 2 AND r.m_score >= 2 
            THEN 'Offer membership or loyalty program.'
        
        WHEN r.r_score >= 4 AND r.f_score <= 2 AND r.m_score >= 1 
            THEN 'Provide onboarding support, build relationship.'
        
        WHEN r.r_score >= 3 AND r.f_score <= 2 AND r.m_score >= 2 
            THEN 'Create brand awareness, offer free trials.'
        
        WHEN r.r_score >= 3 AND r.f_score >= 3 AND r.m_score >= 3 
            THEN 'Make limited time offers, recommend products.'
        
        WHEN r.r_score >= 2 AND r.f_score >= 2 AND r.m_score >= 2 
            THEN 'Share valuable resources, recommend popular products.'
        
        WHEN r.r_score <= 2 AND r.f_score >= 3 AND r.m_score >= 3 
            THEN 'Win them back via renewals or newer products.'
        
        WHEN r.r_score <= 2 AND r.f_score >= 4 AND r.m_score >= 4 
            THEN 'Aggressive win-back campaign, special offers.'
        
        WHEN r.r_score <= 2 AND r.f_score <= 2 AND r.m_score >= 2 
            THEN 'Offer other relevant products, special discounts.'
        
        WHEN r.r_score <= 2 AND r.f_score <= 2 AND r.m_score <= 2 
            THEN 'Revive interest with reach out campaign, ignore if not responsive.'
        
        ELSE 'Monitor and engage appropriately.'
    END AS recommended_action,
    
    -- Priority Level
    CASE 
        WHEN r.r_score >= 4 AND r.f_score >= 4 AND r.m_score >= 4 THEN 'Very High'
        WHEN r.r_score <= 2 AND r.f_score >= 4 AND r.m_score >= 4 THEN 'Very High'
        WHEN r.r_score >= 3 AND r.f_score >= 3 THEN 'High'
        WHEN r.r_score <= 2 AND r.f_score >= 3 AND r.m_score >= 3 THEN 'High'
        WHEN r.r_score >= 2 THEN 'Medium'
        ELSE 'Low'
    END AS priority_level,
    
    -- Customer Lifetime (days)
    DATEDIFF(CURRENT_DATE, r.signup_date) AS customer_lifetime_days,
    
    -- Purchase Frequency (orders per month)
    CASE 
        WHEN DATEDIFF(CURRENT_DATE, r.first_order_date) > 0 
        THEN CAST(r.frequency_orders * 30.0 / DATEDIFF(CURRENT_DATE, r.first_order_date) AS DECIMAL(10,2))
        ELSE 0
    END AS orders_per_month

FROM rfm_scores r

-- Join real-time session data
LEFT JOIN astradb_catalog.customers.customer_sessions s 
    ON r.customer_id = s.customer_id

ORDER BY 
    CASE priority_level
        WHEN 'Very High' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        ELSE 4
    END,
    r.monetary_value DESC,
    r.frequency_orders DESC,
    r.recency_days ASC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id              : Unique customer identifier
-- name                     : Customer full name
-- email                    : Customer email
-- customer_tier            : Loyalty tier
-- city                     : Customer city
-- country                  : Customer country
-- signup_date              : Registration date
-- recency_days             : Days since last purchase
-- frequency_orders         : Total number of orders
-- monetary_value           : Total amount spent
-- avg_order_value          : Average order amount
-- last_order_date          : Most recent order date
-- first_order_date         : First order date
-- r_score                  : Recency score (1-5)
-- f_score                  : Frequency score (1-5)
-- m_score                  : Monetary score (1-5)
-- rfm_score                : Combined RFM score (e.g., "555")
-- current_page             : Current page viewing
-- items_in_cart            : Items in cart
-- session_duration_minutes : Current session time
-- last_active_time         : Last activity timestamp
-- rfm_segment              : Customer segment name
-- recommended_action       : Suggested marketing action
-- priority_level           : Very High/High/Medium/Low
-- customer_lifetime_days   : Days since signup
-- orders_per_month         : Purchase frequency metric
-- ============================================================================

-- ============================================================================
-- RFM Segment Definitions & Marketing Strategies:
-- ============================================================================
-- 
-- 1. CHAMPIONS (R:4-5, F:4-5, M:4-5)
--    - Who: Best customers, buy often, spend most
--    - Action: Reward, early access, VIP treatment
--    - Budget: High - they deserve it
--    - Channel: Email, SMS, Phone
--
-- 2. LOYAL CUSTOMERS (R:3-5, F:4-5, M:3-5)
--    - Who: Regular buyers, good spenders
--    - Action: Upsell, cross-sell, loyalty program
--    - Budget: High
--    - Channel: Email, Personalized offers
--
-- 3. POTENTIAL LOYALISTS (R:4-5, F:2-3, M:2-3)
--    - Who: Recent customers with potential
--    - Action: Membership, engagement campaigns
--    - Budget: Medium-High
--    - Channel: Email, Social media
--
-- 4. NEW CUSTOMERS (R:4-5, F:1-2, M:1-2)
--    - Who: Recent first-time buyers
--    - Action: Onboarding, build relationship
--    - Budget: Medium
--    - Channel: Welcome series, tutorials
--
-- 5. PROMISING (R:3-4, F:1-2, M:2-3)
--    - Who: Recent shoppers with potential
--    - Action: Brand awareness, free trials
--    - Budget: Medium
--    - Channel: Content marketing, ads
--
-- 6. NEED ATTENTION (R:3-4, F:3-4, M:3-4)
--    - Who: Above average but declining
--    - Action: Limited offers, recommendations
--    - Budget: Medium
--    - Channel: Email, retargeting ads
--
-- 7. ABOUT TO SLEEP (R:2-3, F:2-3, M:2-3)
--    - Who: Below average, at risk
--    - Action: Share resources, popular products
--    - Budget: Low-Medium
--    - Channel: Email, content
--
-- 8. AT RISK (R:1-2, F:3-5, M:3-5)
--    - Who: Were good customers, now inactive
--    - Action: Win-back campaigns, renewals
--    - Budget: High (worth saving)
--    - Channel: Email, SMS, special offers
--
-- 9. CANNOT LOSE THEM (R:1-2, F:4-5, M:4-5)
--    - Who: Best customers who stopped buying
--    - Action: Aggressive win-back, VIP offers
--    - Budget: Very High (critical to retain)
--    - Channel: Phone, personalized email, gifts
--
-- 10. HIBERNATING (R:1-2, F:1-2, M:2-3)
--     - Who: Long time since purchase, low frequency
--     - Action: Relevant products, discounts
--     - Budget: Low
--     - Channel: Email, retargeting
--
-- 11. LOST (R:1-2, F:1-2, M:1-2)
--     - Who: Lowest scores across all metrics
--     - Action: Reach out campaign, ignore if unresponsive
--     - Budget: Very Low
--     - Channel: Last-chance email
--
-- ============================================================================

-- ============================================================================
-- Usage Examples:
-- ============================================================================
-- 
-- 1. Target Champions for referral program:
--    WHERE rfm_segment = 'Champions'
--
-- 2. Win-back campaign for at-risk customers:
--    WHERE rfm_segment IN ('At Risk', 'Cannot Lose Them')
--
-- 3. Onboarding campaign for new customers:
--    WHERE rfm_segment = 'New Customers'
--
-- 4. Budget allocation by priority:
--    GROUP BY priority_level
--
-- 5. Geographic analysis:
--    GROUP BY country, rfm_segment
--
-- ============================================================================

-- Made with Bob
