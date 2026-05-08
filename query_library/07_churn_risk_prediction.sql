-- ============================================================================
-- Query 7: Churn Risk Prediction
-- ============================================================================
-- 
-- Purpose: Identify customers at risk of churning based on behavioral patterns
--          and engagement metrics
--
-- Business Use Case: 
--   - Proactive customer retention campaigns
--   - Allocate retention budget to high-risk customers
--   - Identify root causes of churn
--   - Measure effectiveness of retention efforts
--   - Predict revenue at risk
--
-- Data Sources:
--   - Iceberg: customers_details (customer profile and tenure)
--   - Iceberg: customers_orders (purchase history and patterns)
--   - Cassandra: customer_sessions (current engagement level)
--
-- Churn Indicators:
--   - Long time since last purchase
--   - Declining purchase frequency
--   - Reduced engagement (no recent sessions)
--   - Lower average order value
--   - Decreased session duration
--
-- Risk Levels:
--   - Critical: Immediate action required (likely to churn within 30 days)
--   - High: Significant risk (likely to churn within 60 days)
--   - Medium: Moderate risk (likely to churn within 90 days)
--   - Low: Minimal risk (stable customer)
--
-- Performance Notes:
--   - Aggregates historical patterns from Iceberg
--   - Checks recent activity from Cassandra
--   - Uses multiple behavioral signals
--
-- ============================================================================

WITH customer_behavior AS (
    SELECT 
        c.customer_id,
        c.name,
        c.email,
        c.customer_tier,
        c.city,
        c.country,
        c.signup_date,
        
        -- Order Metrics
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.amount) AS lifetime_value,
        AVG(o.amount) AS avg_order_value,
        MAX(o.order_date) AS last_order_date,
        MIN(o.order_date) AS first_order_date,
        
        -- Recency
        DATEDIFF(CURRENT_DATE, MAX(o.order_date)) AS days_since_last_order,
        
        -- Customer Age
        DATEDIFF(CURRENT_DATE, c.signup_date) AS customer_age_days,
        
        -- Purchase Frequency (orders per month)
        CASE 
            WHEN DATEDIFF(MAX(o.order_date), MIN(o.order_date)) > 0 
            THEN CAST(COUNT(DISTINCT o.order_id) * 30.0 / DATEDIFF(MAX(o.order_date), MIN(o.order_date)) AS DECIMAL(10,2))
            ELSE 0
        END AS orders_per_month,
        
        -- Recent Activity (last 3 months vs previous 3 months)
        COUNT(DISTINCT CASE WHEN o.order_date >= DATE_SUB(CURRENT_DATE, 90) THEN o.order_id END) AS orders_last_90_days,
        COUNT(DISTINCT CASE WHEN o.order_date BETWEEN DATE_SUB(CURRENT_DATE, 180) AND DATE_SUB(CURRENT_DATE, 90) THEN o.order_id END) AS orders_previous_90_days,
        
        -- Spending Trend
        SUM(CASE WHEN o.order_date >= DATE_SUB(CURRENT_DATE, 90) THEN o.amount ELSE 0 END) AS spend_last_90_days,
        SUM(CASE WHEN o.order_date BETWEEN DATE_SUB(CURRENT_DATE, 180) AND DATE_SUB(CURRENT_DATE, 90) THEN o.amount ELSE 0 END) AS spend_previous_90_days
        
    FROM iceberg_data.customers_schema.customers_details c
    LEFT JOIN iceberg_data.customers_schema.customers_orders o 
        ON c.customer_id = o.customer_id
    GROUP BY 
        c.customer_id, c.name, c.email, c.customer_tier,
        c.city, c.country, c.signup_date
),

engagement_metrics AS (
    SELECT 
        cb.*,
        
        -- Real-Time Engagement
        s.current_page,
        s.items_in_cart,
        s.session_duration_minutes,
        s.last_active_time,
        
        -- Days since last website visit
        CASE 
            WHEN s.last_active_time IS NOT NULL 
            THEN DATEDIFF(CURRENT_DATE, CAST(s.last_active_time AS DATE))
            ELSE 999
        END AS days_since_last_visit,
        
        -- Engagement Status
        CASE 
            WHEN s.last_active_time IS NULL THEN 'No Recent Activity'
            WHEN DATEDIFF(CURRENT_DATE, CAST(s.last_active_time AS DATE)) = 0 THEN 'Active Today'
            WHEN DATEDIFF(CURRENT_DATE, CAST(s.last_active_time AS DATE)) <= 7 THEN 'Active This Week'
            WHEN DATEDIFF(CURRENT_DATE, CAST(s.last_active_time AS DATE)) <= 30 THEN 'Active This Month'
            ELSE 'Inactive'
        END AS engagement_status
        
    FROM customer_behavior cb
    LEFT JOIN astradb_catalog.customers.customer_sessions s 
        ON cb.customer_id = s.customer_id
)

SELECT 
    customer_id,
    name,
    email,
    customer_tier,
    city,
    country,
    signup_date,
    
    -- Historical Metrics
    total_orders,
    lifetime_value,
    avg_order_value,
    last_order_date,
    first_order_date,
    customer_age_days,
    orders_per_month,
    
    -- Recency Metrics
    days_since_last_order,
    days_since_last_visit,
    
    -- Trend Metrics
    orders_last_90_days,
    orders_previous_90_days,
    spend_last_90_days,
    spend_previous_90_days,
    
    -- Current Engagement
    current_page,
    items_in_cart,
    session_duration_minutes,
    last_active_time,
    engagement_status,
    
    -- Churn Risk Score (0-100, higher = more risk)
    (
        -- Recency Risk (0-30 points)
        CASE 
            WHEN days_since_last_order > 180 THEN 30
            WHEN days_since_last_order > 120 THEN 25
            WHEN days_since_last_order > 90 THEN 20
            WHEN days_since_last_order > 60 THEN 15
            WHEN days_since_last_order > 30 THEN 10
            ELSE 0
        END +
        
        -- Frequency Decline Risk (0-25 points)
        CASE 
            WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
            WHEN orders_last_90_days < orders_previous_90_days THEN 15
            WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
            ELSE 0
        END +
        
        -- Spending Decline Risk (0-25 points)
        CASE 
            WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
            WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
            WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
            WHEN spend_last_90_days < spend_previous_90_days THEN 10
            ELSE 0
        END +
        
        -- Engagement Risk (0-20 points)
        CASE 
            WHEN engagement_status = 'No Recent Activity' THEN 20
            WHEN engagement_status = 'Inactive' THEN 15
            WHEN engagement_status = 'Active This Month' THEN 10
            WHEN engagement_status = 'Active This Week' THEN 5
            ELSE 0
        END
    ) AS churn_risk_score,
    
    -- Churn Risk Level
    CASE 
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 70 THEN 'Critical'
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 50 THEN 'High'
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 30 THEN 'Medium'
        ELSE 'Low'
    END AS churn_risk_level,
    
    -- Revenue at Risk
    CAST(lifetime_value * 
        CASE 
            WHEN (
                CASE 
                    WHEN days_since_last_order > 180 THEN 30
                    WHEN days_since_last_order > 120 THEN 25
                    WHEN days_since_last_order > 90 THEN 20
                    WHEN days_since_last_order > 60 THEN 15
                    WHEN days_since_last_order > 30 THEN 10
                    ELSE 0
                END +
                CASE 
                    WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                    WHEN orders_last_90_days < orders_previous_90_days THEN 15
                    WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                    ELSE 0
                END +
                CASE 
                    WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                    WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                    WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                    WHEN spend_last_90_days < spend_previous_90_days THEN 10
                    ELSE 0
                END +
                CASE 
                    WHEN engagement_status = 'No Recent Activity' THEN 20
                    WHEN engagement_status = 'Inactive' THEN 15
                    WHEN engagement_status = 'Active This Month' THEN 10
                    WHEN engagement_status = 'Active This Week' THEN 5
                    ELSE 0
                END
            ) / 100.0 
        END AS DECIMAL(10,2)) AS revenue_at_risk,
    
    -- Recommended Retention Action
    CASE 
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 70 AND customer_tier IN ('Platinum', 'Gold')
            THEN 'URGENT: Personal call + 25% discount + VIP perks'
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 70
            THEN 'Win-back email series + 20% discount'
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 50
            THEN 'Re-engagement campaign + 15% discount'
        WHEN (
            CASE 
                WHEN days_since_last_order > 180 THEN 30
                WHEN days_since_last_order > 120 THEN 25
                WHEN days_since_last_order > 90 THEN 20
                WHEN days_since_last_order > 60 THEN 15
                WHEN days_since_last_order > 30 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
                WHEN orders_last_90_days < orders_previous_90_days THEN 15
                WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
                ELSE 0
            END +
            CASE 
                WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
                WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
                WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
                WHEN spend_last_90_days < spend_previous_90_days THEN 10
                ELSE 0
            END +
            CASE 
                WHEN engagement_status = 'No Recent Activity' THEN 20
                WHEN engagement_status = 'Inactive' THEN 15
                WHEN engagement_status = 'Active This Month' THEN 10
                WHEN engagement_status = 'Active This Week' THEN 5
                ELSE 0
            END
        ) >= 30
            THEN 'Reminder email + product recommendations'
        ELSE 'Monitor and maintain engagement'
    END AS recommended_action

FROM engagement_metrics

WHERE 
    -- Only include customers with at least one order
    total_orders > 0
    
    -- Focus on customers with some churn risk
    AND (
        CASE 
            WHEN days_since_last_order > 180 THEN 30
            WHEN days_since_last_order > 120 THEN 25
            WHEN days_since_last_order > 90 THEN 20
            WHEN days_since_last_order > 60 THEN 15
            WHEN days_since_last_order > 30 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN orders_last_90_days = 0 AND orders_previous_90_days > 0 THEN 25
            WHEN orders_last_90_days < orders_previous_90_days THEN 15
            WHEN orders_last_90_days = orders_previous_90_days AND orders_last_90_days < 2 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN spend_last_90_days = 0 AND spend_previous_90_days > 0 THEN 25
            WHEN spend_last_90_days < spend_previous_90_days * 0.5 THEN 20
            WHEN spend_last_90_days < spend_previous_90_days * 0.75 THEN 15
            WHEN spend_last_90_days < spend_previous_90_days THEN 10
            ELSE 0
        END +
        CASE 
            WHEN engagement_status = 'No Recent Activity' THEN 20
            WHEN engagement_status = 'Inactive' THEN 15
            WHEN engagement_status = 'Active This Month' THEN 10
            WHEN engagement_status = 'Active This Week' THEN 5
            ELSE 0
        END
    ) >= 30

ORDER BY 
    churn_risk_score DESC,
    lifetime_value DESC;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- customer_id              : Unique customer identifier
-- name                     : Customer full name
-- email                    : Contact email
-- customer_tier            : Loyalty tier
-- city                     : Customer city
-- country                  : Customer country
-- signup_date              : Registration date
-- total_orders             : Total order count
-- lifetime_value           : Total historical spend
-- avg_order_value          : Average order amount
-- last_order_date          : Most recent order
-- first_order_date         : First order date
-- customer_age_days        : Days since signup
-- orders_per_month         : Purchase frequency
-- days_since_last_order    : Recency metric
-- days_since_last_visit    : Website engagement recency
-- orders_last_90_days      : Recent order count
-- orders_previous_90_days  : Previous period order count
-- spend_last_90_days       : Recent spend
-- spend_previous_90_days   : Previous period spend
-- current_page             : Current page (if active)
-- items_in_cart            : Items in cart
-- session_duration_minutes : Session time
-- last_active_time         : Last activity
-- engagement_status        : Activity level
-- churn_risk_score         : 0-100 risk score
-- churn_risk_level         : Critical/High/Medium/Low
-- revenue_at_risk          : Potential lost revenue
-- recommended_action       : Retention strategy
-- ============================================================================

-- ============================================================================
-- Retention Campaign Strategy by Risk Level:
-- ============================================================================
-- 
-- CRITICAL RISK (Score 70-100):
-- - VIP Customers: Personal call from account manager
-- - Offer: 25% discount + free shipping + loyalty points
-- - Timeline: Contact within 24 hours
-- - Budget: High (worth the investment)
-- - Success Metric: 40-50% win-back rate
--
-- HIGH RISK (Score 50-69):
-- - Multi-channel campaign: Email + SMS + Retargeting ads
-- - Offer: 20% discount + exclusive products
-- - Timeline: Contact within 3 days
-- - Budget: Medium-High
-- - Success Metric: 30-40% win-back rate
--
-- MEDIUM RISK (Score 30-49):
-- - Email campaign: 3-email series over 2 weeks
-- - Offer: 15% discount + product recommendations
-- - Timeline: Start within 1 week
-- - Budget: Medium
-- - Success Metric: 20-30% win-back rate
--
-- LOW RISK (Score 0-29):
-- - Maintenance: Regular newsletters
-- - Offer: Occasional promotions
-- - Timeline: Ongoing
-- - Budget: Low
-- - Success Metric: Maintain engagement
--
-- ============================================================================

-- Made with Bob
