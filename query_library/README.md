# 📊 Query Library

This directory contains a comprehensive collection of SQL queries demonstrating federated analytics across Iceberg (historical data) and Cassandra (real-time data) using watsonx.data and AstraDB.

## 📚 Documentation

- **[Setup Guide](SETUP_GUIDE.md)** - Complete environment setup instructions
- **[Integration Guide](INTEGRATION_GUIDE.md)** - Connect queries to BI tools, APIs, and workflows
- **[Data Dictionary](../DATA_DICTIONARY.md)** - Schema reference and data structures

## 📁 Query Files

### 1. Customer 360 View
**File:** `01_customer_360_view.sql`

**Purpose:** Complete customer profile combining historical and real-time data

**Use Cases:**
- Customer support context
- Sales team insights
- Personalized marketing

**Key Metrics:**
- Lifetime value
- Total orders
- Current activity
- Transaction status

**Data Sources:** Iceberg (customers, orders) + Cassandra (sessions, transactions)

---

### 2. High-Value Customers at Checkout
**File:** `02_high_value_customers_at_checkout.sql`

**Purpose:** Identify VIP customers currently at checkout for proactive support

**Use Cases:**
- Prevent cart abandonment
- VIP customer support
- Conversion optimization

**Key Metrics:**
- Lifetime value > $1000
- Gold/Platinum tier
- Currently at checkout
- Support priority level

**Data Sources:** Iceberg (customers, orders) + Cassandra (sessions)

---

### 3. Abandoned Cart Recovery
**File:** `03_abandoned_cart_recovery.sql`

**Purpose:** Identify and prioritize abandoned carts for recovery campaigns

**Use Cases:**
- Cart recovery emails
- Discount offers
- Revenue recovery
- Conversion optimization

**Key Metrics:**
- Items in cart
- Time since abandonment
- Estimated cart value
- Recovery priority

**Data Sources:** Iceberg (customers, orders) + Cassandra (sessions)

**Automation:** Can trigger email/SMS campaigns based on abandonment time

---

### 4. Customer Engagement Score
**File:** `04_customer_engagement_score.sql`

**Purpose:** Calculate comprehensive engagement score (0-100) for each customer

**Use Cases:**
- Customer segmentation
- Loyalty programs
- Churn prediction
- Marketing prioritization

**Scoring Components:**
- Recency (0-30 points)
- Frequency (0-30 points)
- Monetary (0-30 points)
- Activity (0-10 points)

**Segments:** Champions, Loyal, Potential, At Risk, Hibernating

**Data Sources:** Iceberg (customers, orders) + Cassandra (sessions)

---

### 5. RFM Segmentation
**File:** `05_rfm_segmentation.sql`

**Purpose:** Classic RFM (Recency, Frequency, Monetary) analysis for customer segmentation

**Use Cases:**
- Marketing campaign targeting
- Budget allocation
- Customer lifetime value prediction
- Retention strategies

**RFM Scores:** 1-5 for each component (555 = best)

**Segments:**
- Champions
- Loyal Customers
- Potential Loyalists
- New Customers
- At Risk
- Cannot Lose Them
- Hibernating
- Lost

**Data Sources:** Iceberg (customers, orders) + Cassandra (sessions)

---

### 6. Real-Time Analytics Dashboard
**File:** `06_real_time_analytics_dashboard.sql`

**Purpose:** Live operational dashboard showing current customer activity

**Use Cases:**
- Operations monitoring
- Real-time alerts
- Support team dashboard
- Executive dashboards

**Key Features:**
- Active users by page
- Customers at checkout
- Pending transactions
- Alert prioritization
- Conversion likelihood

**Refresh Rate:** Real-time (< 1 second)

**Data Sources:** Cassandra (sessions, transactions) + Iceberg (customers, orders)

---

### 7. Churn Risk Prediction
**File:** `07_churn_risk_prediction.sql`

**Purpose:** Identify customers at risk of churning with actionable retention strategies

**Use Cases:**
- Proactive retention
- Win-back campaigns
- Revenue protection
- Customer health monitoring

**Risk Levels:**
- Critical (70-100 points)
- High (50-69 points)
- Medium (30-49 points)
- Low (0-29 points)

**Churn Indicators:**
- Days since last order
- Declining purchase frequency
- Reduced spending
- Low engagement

**Data Sources:** Iceberg (customers, orders) + Cassandra (sessions)

---

## 🚀 Quick Start

### Running Queries

1. **Access watsonx.data Query Workspace:**
   ```
   https://your-watsonx-instance/query-workspace
   ```

2. **Copy query from file**

3. **Adjust filters as needed:**
   - Customer ID
   - Date ranges
   - Tier filters
   - Risk thresholds

4. **Execute query**

### Example Usage

```sql
-- Get 360 view for specific customer
-- Edit 01_customer_360_view.sql and uncomment:
WHERE c.customer_id = 'C001'

-- Find high-value customers at checkout right now
-- Run 02_high_value_customers_at_checkout.sql as-is

-- Identify abandoned carts in last 24 hours
-- Edit 03_abandoned_cart_recovery.sql and adjust:
AND CAST((UNIX_TIMESTAMP(CURRENT_TIMESTAMP) - UNIX_TIMESTAMP(s.last_active_time)) / 3600.0 AS DECIMAL(10,2)) BETWEEN 1 AND 24
```

---

## 📊 Query Comparison Matrix

| Query | Real-Time Data | Historical Data | Aggregation | Use Case | Refresh Rate |
|-------|----------------|-----------------|-------------|----------|--------------|
| 01_customer_360_view | ✅ | ✅ | Medium | Support | On-demand |
| 02_high_value_checkout | ✅ | ✅ | Medium | Sales | Real-time |
| 03_abandoned_cart | ✅ | ✅ | Medium | Marketing | Hourly |
| 04_engagement_score | ✅ | ✅ | High | Segmentation | Daily |
| 05_rfm_segmentation | ✅ | ✅ | High | Marketing | Daily |
| 06_realtime_dashboard | ✅ | ✅ | Low | Operations | Real-time |
| 07_churn_prediction | ✅ | ✅ | High | Retention | Daily |

---

## 🎯 Query Selection Guide

### For Customer Support Teams
→ Use **01_customer_360_view.sql**
- Complete customer context
- Historical + real-time data
- Transaction status

### For Sales Teams
→ Use **02_high_value_customers_at_checkout.sql**
- Focus on high-value opportunities
- Proactive engagement
- Conversion optimization

### For Marketing Teams
→ Use **03_abandoned_cart_recovery.sql**, **04_engagement_score.sql**, **05_rfm_segmentation.sql**
- Campaign targeting
- Customer segmentation
- Personalization

### For Operations Teams
→ Use **06_real_time_analytics_dashboard.sql**
- Live monitoring
- Alert management
- Performance tracking

### For Retention Teams
→ Use **07_churn_risk_prediction.sql**
- Proactive retention
- Win-back campaigns
- Revenue protection

---

## 🔧 Customization Tips

### Adjusting Thresholds

```sql
-- Change lifetime value threshold
HAVING SUM(o.amount) > 1000  -- Change to 500, 2000, etc.

-- Adjust abandonment time
AND hours_since_active > 1  -- Change to 2, 6, 24, etc.

-- Modify risk score weights
CASE WHEN days_since_last_order > 90 THEN 20  -- Adjust points
```

### Adding Filters

```sql
-- Filter by country
WHERE c.country = 'USA'

-- Filter by tier
WHERE c.customer_tier IN ('Gold', 'Platinum')

-- Filter by date range
WHERE o.order_date >= DATE_SUB(CURRENT_DATE, 90)
```

### Performance Optimization

```sql
-- Add LIMIT for testing
ORDER BY lifetime_value DESC
LIMIT 100;

-- Use specific customer IDs
WHERE c.customer_id IN ('C001', 'C002', 'C003')

-- Partition pruning on Iceberg
WHERE o.order_date >= DATE '2024-01-01'
```

---

## 📈 Best Practices

### 1. Query Performance
- Always filter on partition keys when possible
- Use LIMIT during development/testing
- Leverage predicate pushdown to source systems
- Monitor query execution time

### 2. Data Freshness
- Cassandra data: Real-time (< 1 second)
- Iceberg data: Batch updates (daily or on-demand)
- Consider data latency in business logic

### 3. Error Handling
- Use LEFT JOIN for optional data
- Handle NULL values appropriately
- Test with edge cases (new customers, no orders, etc.)

### 4. Documentation
- Comment complex logic
- Document business rules
- Include expected output examples
- Note any assumptions

---

## 🔗 Integration Examples

### Scheduling Queries

```bash
# Daily churn risk report
0 8 * * * /path/to/run_query.sh 07_churn_risk_prediction.sql

# Hourly abandoned cart check
0 * * * * /path/to/run_query.sh 03_abandoned_cart_recovery.sql

# Real-time dashboard (every 5 seconds)
*/5 * * * * /path/to/run_query.sh 06_real_time_analytics_dashboard.sql
```

### API Integration

```python
# Example: Get customer 360 view via API
import prestodb

conn = prestodb.dbapi.connect(
    host='your-presto-host',
    port=8080,
    user='your-user'
)

cursor = conn.cursor()
cursor.execute(open('01_customer_360_view.sql').read())
results = cursor.fetchall()
```

### BI Tool Connection

```yaml
# Tableau connection
connection_type: presto
host: your-watsonx-host
port: 8080
catalog: iceberg_data
schema: customers_schema
```

---

## 🆘 Troubleshooting

### Common Issues

**Issue:** Query returns no results
- Check customer_id format (C001 vs C1)
- Verify data exists in both systems
- Check date filters

**Issue:** Slow query performance
- Add WHERE clauses to filter data
- Use LIMIT during testing
- Check for missing indexes

**Issue:** NULL values in Cassandra columns
- Verify customer_id matching
- Check if session data exists
- Use LEFT JOIN instead of INNER JOIN

**Issue:** Syntax errors
- Verify catalog/schema names
- Check column names match schema
- Ensure proper GROUP BY clauses

---

## 📚 Additional Resources

- [DATA_DICTIONARY.md](../DATA_DICTIONARY.md) - Complete schema reference
- [README.md](../README.md) - Workshop overview and setup
- [watsonx.data Documentation](https://www.ibm.com/docs/en/watsonxdata)
- [AstraDB Documentation](https://docs.datastax.com/en/astra/)

---

## 🤝 Contributing

To add new queries:

1. Create new file: `XX_query_name.sql`
2. Follow existing format with header comments
3. Include business use case and expected output
4. Add entry to this README
5. Test thoroughly with sample data

---

## 📝 Query Template

```sql
-- ============================================================================
-- Query X: [Query Name]
-- ============================================================================
-- 
-- Purpose: [Brief description]
--
-- Business Use Case: 
--   - [Use case 1]
--   - [Use case 2]
--
-- Data Sources:
--   - Iceberg: [tables used]
--   - Cassandra: [tables used]
--
-- Key Metrics:
--   - [Metric 1]
--   - [Metric 2]
--
-- Performance Notes:
--   - [Optimization tips]
--
-- ============================================================================

SELECT 
    -- Your query here
FROM ...
WHERE ...
GROUP BY ...
ORDER BY ...;

-- ============================================================================
-- Expected Output Columns:
-- ============================================================================
-- column_name : Description
-- ============================================================================
```

---

*Last Updated: 2024*
*Version: 1.0*
