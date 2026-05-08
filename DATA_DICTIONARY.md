# 📊 Data Dictionary & Schema Mapping

This document provides a comprehensive reference for all data structures, schemas, and mappings used in the workshop.

---

## 📑 Table of Contents

1. [Overview](#overview)
2. [Iceberg Tables (Historical Data)](#iceberg-tables-historical-data)
3. [Cassandra Tables (Real-Time Data)](#cassandra-tables-real-time-data)
4. [Data Relationships](#data-relationships)
5. [Query Mapping Examples](#query-mapping-examples)
6. [Data Flow](#data-flow)
7. [Sample Data](#sample-data)

---

## Overview

### Data Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Data Layer Overview                   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Historical Data (Iceberg)     Real-Time Data (Cassandra)│
│  ├── customers                 ├── customer_sessions     │
│  └── orders                    └── recent_transactions   │
│                                                          │
│  Joined via: customer_id                                 │
└──────────────────────────────────────────────────────────┘
```

### Catalog Structure

| Catalog | Type | Purpose | Location                                      |
|---------|------|---------|-----------------------------------------------|
| `iceberg_data` | Iceberg | Historical analytics | MinIO/S3 Object Storage|
| `cassandra` | Cassandra | Real-time operations | AstraDB Cloud |

### Schema Hierarchy

```
iceberg_data (catalog)
└── workshop (schema)
    ├── customers (table)
    └── orders (table)

cassandra (catalog)
└── customers (keyspace)
    ├── customer_sessions (table)
    └── recent_transactions (table)
```

---

## Iceberg Tables (Historical Data)

### Table: `iceberg_data.workshop.customers`

**Purpose:** Store historical customer profile information for analytics

**Storage Format:** Parquet (columnar format optimized for analytics)

**Schema Definition:**

```sql
CREATE TABLE iceberg_data.workshop.customers (
    customer_id VARCHAR,
    name VARCHAR,
    email VARCHAR,
    city VARCHAR,
    country VARCHAR,
    signup_date DATE,
    customer_tier VARCHAR
) WITH (
    format = 'PARQUET'
);
```

**Column Details:**

| Column Name | Data Type | Description | Example | Constraints |
|-------------|-----------|-------------|---------|-------------|
| `customer_id` | VARCHAR | Unique customer identifier | 'C001' | Primary Key, NOT NULL |
| `name` | VARCHAR | Customer full name | 'Arjun Patel' | NOT NULL |
| `email` | VARCHAR | Customer email address | 'arjun@example.com' | Unique |
| `city` | VARCHAR | Customer city | 'Mumbai' | - |
| `country` | VARCHAR | Customer country | 'India' | - |
| `signup_date` | DATE | Date customer signed up | DATE '2022-01-15' | NOT NULL |
| `customer_tier` | VARCHAR | Loyalty tier | 'Gold', 'Platinum', 'Silver', 'Bronze' | Enum-like |

**Business Rules:**
- `customer_tier` values: Bronze, Silver, Gold, Platinum
- `signup_date` must be in the past
- `email` should be unique per customer

**Typical Queries:**
- Customer segmentation by tier
- Geographic distribution analysis
- Customer lifetime value calculation
- Cohort analysis by signup date

---

### Table: `iceberg_data.workshop.orders`

**Purpose:** Store historical order transactions for analytics

**Storage Format:** Parquet

**Schema Definition:**

```sql
CREATE TABLE iceberg_data.workshop.orders (
    order_id VARCHAR,
    customer_id VARCHAR,
    product_name VARCHAR,
    amount DOUBLE,
    order_date DATE,
    status VARCHAR
) WITH (
    format = 'PARQUET'
);
```

**Column Details:**

| Column Name | Data Type | Description | Example | Constraints |
|-------------|-----------|-------------|---------|-------------|
| `order_id` | VARCHAR | Unique order identifier | 'O001' | Primary Key, NOT NULL |
| `customer_id` | VARCHAR | Reference to customer | 'C001' | Foreign Key to customers.customer_id |
| `product_name` | VARCHAR | Name of product ordered | 'Laptop Pro' | NOT NULL |
| `amount` | DOUBLE | Order amount in USD | 1299.99 | > 0 |
| `order_date` | DATE | Date order was placed | DATE '2023-01-10' | NOT NULL |
| `status` | VARCHAR | Order fulfillment status | 'Delivered', 'Pending', 'Cancelled' | Enum-like |

**Business Rules:**
- `status` values: Pending, Processing, Shipped, Delivered, Cancelled, Returned
- `amount` must be positive
- `order_date` must be >= customer's `signup_date`
- One customer can have multiple orders

**Typical Queries:**
- Revenue analysis by time period
- Product popularity analysis
- Customer purchase patterns
- Order fulfillment metrics

**Relationships:**
- **Many-to-One** with `customers` table via `customer_id`

---

## Cassandra Tables (Real-Time Data)

### Keyspace: `customers`

**Replication Strategy:** SimpleStrategy (for development)
**Replication Factor:** 1

```sql
CREATE KEYSPACE customers 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
```

---

### Table: `cassandra.customers.customer_sessions`

**Purpose:** Track real-time customer activity on the website

**Data Model:** Partition by `customer_id` for fast lookups

**Schema Definition:**

```sql
CREATE TABLE customers.customer_sessions (
    customer_id TEXT PRIMARY KEY,
    current_page TEXT,
    last_active_time TIMESTAMP,
    session_duration_minutes INT,
    items_in_cart INT
);
```

**Column Details:**

| Column Name | Data Type | Description | Example | Constraints |
|-------------|-----------|-------------|---------|-------------|
| `customer_id` | TEXT | Unique customer identifier (Partition Key) | 'C1' | PRIMARY KEY |
| `current_page` | TEXT | Current page customer is viewing | 'checkout', 'homepage' | - |
| `last_active_time` | TIMESTAMP | Last activity timestamp | 2024-05-04 10:30:00 | NOT NULL |
| `session_duration_minutes` | INT | Minutes in current session | 15 | >= 0 |
| `items_in_cart` | INT | Number of items in cart | 2 | >= 0 |

**Cassandra-Specific Details:**
- **Partition Key:** `customer_id` (ensures fast single-customer lookups)
- **Clustering Key:** None (one row per customer)
- **TTL:** Can be set to auto-expire old sessions
- **Write Pattern:** Frequent updates (every page view)
- **Read Pattern:** Single customer lookup by ID

**Business Rules:**
- One active session per customer
- `session_duration_minutes` resets on new session
- `items_in_cart` updated on cart modifications
- `last_active_time` updated on every interaction

**Typical Queries:**
- Get current customer activity
- Find customers at checkout
- Identify abandoned carts
- Real-time engagement metrics

**Page Values:**
- `homepage` - Landing page
- `product_page` - Viewing product details
- `search_results` - Search results page
- `cart` - Shopping cart page
- `checkout` - Checkout process
- `account` - Account management

---

### Table: `cassandra.customers.recent_transactions`

**Purpose:** Track recent transaction status for real-time monitoring

**Data Model:** Partition by `transaction_id` for transaction lookups

**Schema Definition:**

```sql
CREATE TABLE customers.recent_transactions (
    transaction_id TEXT PRIMARY KEY,
    customer_id TEXT,
    amount DOUBLE,
    transaction_time TIMESTAMP,
    status TEXT,
    payment_method TEXT
);
```

**Column Details:**

| Column Name | Data Type | Description | Example | Constraints |
|-------------|-----------|-------------|---------|-------------|
| `transaction_id` | TEXT | Unique transaction identifier (Partition Key) | 'T001' | PRIMARY KEY |
| `customer_id` | TEXT | Reference to customer | 'C001' | NOT NULL |
| `amount` | DOUBLE | Transaction amount in USD | 1599.98 | > 0 |
| `transaction_time` | TIMESTAMP | When transaction occurred | 2024-05-04 10:28:00 | NOT NULL |
| `status` | TEXT | Transaction status | 'Pending', 'Completed' | Enum-like |
| `payment_method` | TEXT | Payment method used | 'Credit Card' | NOT NULL |

**Cassandra-Specific Details:**
- **Partition Key:** `transaction_id` (unique transaction lookups)
- **Clustering Key:** None
- **Secondary Index:** Consider adding on `customer_id` for customer-based queries
- **Write Pattern:** Insert on transaction creation, update on status change
- **Read Pattern:** Lookup by transaction ID or customer ID

**Business Rules:**
- `status` values: Pending, Processing, Completed, Failed, Refunded
- `amount` must be positive
- `transaction_time` should be recent (within last 24-48 hours)
- Multiple transactions per customer allowed

**Typical Queries:**
- Check transaction status
- Find pending transactions
- Customer transaction history (recent)
- Payment method analysis

**Payment Method Values:**
- `Credit Card`
- `Debit Card`
- `PayPal`
- `UPI`
- `Net Banking`
- `Digital Wallet`

**Status Values:**
- `Pending` - Transaction initiated, awaiting processing
- `Processing` - Payment being processed
- `Completed` - Transaction successful
- `Failed` - Transaction failed
- `Refunded` - Transaction refunded

---

## Data Relationships

### Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Relationships                       │
└─────────────────────────────────────────────────────────────┘

Iceberg (Historical)                 Cassandra (Real-Time)
┌──────────────────┐                ┌──────────────────────┐
│   customers      │                │  customer_sessions   │
├──────────────────┤                ├──────────────────────┤
│ customer_id (PK) │◄───────────────│ customer_id (PK)     │
│ name             │                │ current_page         │
│ email            │                │ last_active_time     │
│ city             │                │ session_duration     │
│ country          │                │ items_in_cart        │
│ signup_date      │                └──────────────────────┘
│ customer_tier    │                         │
└────────┬─────────┘                         │
         │                                   │
         │ 1:N                               │
         │                                   │
┌────────▼─────────┐                ┌───────▼──────────────┐
│   orders         │                │ recent_transactions  │
├──────────────────┤                ├──────────────────────┤
│ order_id (PK)    │                │ transaction_id (PK)  │
│ customer_id (FK) │◄───────────────│ customer_id          │
│ product_name     │                │ amount               │
│ amount           │                │ transaction_time     │
│ order_date       │                │ status               │
│ status           │                │ payment_method       │
└──────────────────┘                └──────────────────────┘
```

### Join Keys

| Join Type | Left Table | Right Table | Join Key | Relationship |
|-----------|------------|-------------|----------|--------------|
| Historical Profile + Real-Time Activity | `iceberg_data.workshop.customers` | `cassandra.customers.customer_sessions` | `customer_id` | 1:1 |
| Historical Profile + Recent Transactions | `iceberg_data.workshop.customers` | `cassandra.customers.recent_transactions` | `customer_id` | 1:N |
| Historical Orders + Customer Profile | `iceberg_data.workshop.orders` | `iceberg_data.workshop.customers` | `customer_id` | N:1 |

---

## Query Mapping Examples

### Mapping 1: Customer 360 View

**Business Question:** "What is the complete view of a customer including history and current activity?"

**Data Sources:**
- Historical: `iceberg_data.workshop.customers` (profile)
- Historical: `iceberg_data.workshop.orders` (purchase history)
- Real-Time: `cassandra.customers.customer_sessions` (current activity)
- Real-Time: `cassandra.customers.recent_transactions` (latest transactions)

**Query:**
```sql
SELECT 
    -- Profile (Iceberg)
    c.customer_id,
    c.name,
    c.email,
    c.customer_tier,
    
    -- Historical Metrics (Iceberg)
    COUNT(o.order_id) AS total_orders,
    SUM(o.amount) AS lifetime_value,
    MAX(o.order_date) AS last_order_date,
    
    -- Real-Time Activity (Cassandra)
    s.current_page,
    s.session_duration_minutes,
    s.items_in_cart,
    
    -- Recent Transaction (Cassandra)
    t.transaction_id,
    t.status AS transaction_status,
    t.amount AS pending_amount
    
FROM iceberg_data.workshop.customers c
LEFT JOIN iceberg_data.workshop.orders o 
    ON c.customer_id = o.customer_id
LEFT JOIN cassandra.customers.customer_sessions s 
    ON c.customer_id = s.customer_id
LEFT JOIN cassandra.customers.recent_transactions t 
    ON c.customer_id = t.customer_id
WHERE c.customer_id = 'C001'
GROUP BY 
    c.customer_id, c.name, c.email, c.customer_tier,
    s.current_page, s.session_duration_minutes, s.items_in_cart,
    t.transaction_id, t.status, t.amount;
```

**Result Mapping:**

| Output Column | Source Table | Source Column | Data Type |
|---------------|--------------|---------------|-----------|
| customer_id | customers (Iceberg) | customer_id | VARCHAR |
| name | customers (Iceberg) | name | VARCHAR |
| email | customers (Iceberg) | email | VARCHAR |
| customer_tier | customers (Iceberg) | customer_tier | VARCHAR |
| total_orders | orders (Iceberg) | COUNT(order_id) | BIGINT |
| lifetime_value | orders (Iceberg) | SUM(amount) | DOUBLE |
| last_order_date | orders (Iceberg) | MAX(order_date) | DATE |
| current_page | customer_sessions (Cassandra) | current_page | TEXT |
| session_duration_minutes | customer_sessions (Cassandra) | session_duration_minutes | INT |
| items_in_cart | customer_sessions (Cassandra) | items_in_cart | INT |
| transaction_id | recent_transactions (Cassandra) | transaction_id | TEXT |
| transaction_status | recent_transactions (Cassandra) | status | TEXT |
| pending_amount | recent_transactions (Cassandra) | amount | DOUBLE |

---

### Mapping 2: High-Value Customers at Checkout

**Business Question:** "Which high-value customers are currently at checkout?"

**Data Sources:**
- Historical: `iceberg_data.workshop.customers` + `orders` (identify high-value)
- Real-Time: `cassandra.customers.customer_sessions` (current page)

**Query:**
```sql
SELECT 
    c.customer_id,
    c.name,
    c.customer_tier,
    SUM(o.amount) AS lifetime_value,
    s.current_page,
    s.items_in_cart
FROM iceberg_data.workshop.customers c
JOIN iceberg_data.workshop.orders o 
    ON c.customer_id = o.customer_id
JOIN cassandra.customers.customer_sessions s 
    ON c.customer_id = s.customer_id
WHERE s.current_page = 'checkout'
  AND c.customer_tier IN ('Gold', 'Platinum')
GROUP BY 
    c.customer_id, c.name, c.customer_tier,
    s.current_page, s.items_in_cart
HAVING SUM(o.amount) > 1000
ORDER BY lifetime_value DESC;
```

---

## Data Flow

### Write Patterns

```
┌─────────────────────────────────────────────────────────┐
│                    Data Write Flow                       │
└─────────────────────────────────────────────────────────┘

Customer Signs Up
    │
    ├──► Iceberg: customers table (batch insert)
    │
Customer Places Order
    │
    ├──► Iceberg: orders table (batch insert)
    │
Customer Browses Website
    │
    ├──► Cassandra: customer_sessions (real-time update)
    │
Customer Makes Payment
    │
    └──► Cassandra: recent_transactions (real-time insert)
```

### Read Patterns

```
┌─────────────────────────────────────────────────────────┐
│                    Data Read Flow                        │
└─────────────────────────────────────────────────────────┘

Support Agent Query
    │
    ├──► Presto Query Engine
    │       │
    │       ├──► Iceberg Connector
    │       │       │
    │       │       ├──► Read customers (historical)
    │       │       └──► Read orders (historical)
    │       │
    │       └──► Cassandra Connector
    │               │
    │               ├──► Read customer_sessions (real-time)
    │               └──► Read recent_transactions (real-time)
    │
    └──► Merged Results (federated query)
```

---

## Sample Data

### Sample: `iceberg_data.workshop.customers`

| customer_id | name | email | city | country | signup_date | customer_tier |
|-------------|------|-------|------|---------|-------------|---------------|
| C001 | Arjun Patel | arjun@example.com | Mumbai | India | 2022-01-15 | Gold |
| C002 | Sarah Johnson | sarah@example.com | New York | USA | 2021-06-20 | Platinum |
| C003 | Li Wei | liwei@example.com | Shanghai | China | 2022-03-10 | Silver |
| C004 | Maria Garcia | maria@example.com | Madrid | Spain | 2021-11-05 | Gold |
| C005 | James Smith | james@example.com | London | UK | 2022-02-28 | Bronze |

### Sample: `iceberg_data.workshop.orders`

| order_id | customer_id | product_name | amount | order_date | status |
|----------|-------------|--------------|--------|------------|--------|
| O001 | C001 | Laptop Pro | 1299.99 | 2023-01-10 | Delivered |
| O002 | C001 | Wireless Mouse | 29.99 | 2023-02-15 | Delivered |
| O003 | C001 | USB-C Hub | 49.99 | 2023-03-20 | Delivered |
| O004 | C002 | Monitor 4K | 599.99 | 2023-01-25 | Delivered |
| O005 | C002 | Keyboard Mechanical | 149.99 | 2023-02-10 | Delivered |

### Sample: `cassandra.customers.customer_sessions`

| customer_id | current_page | last_active_time | session_duration_minutes | items_in_cart |
|-------------|--------------|------------------|--------------------------|---------------|
| C1 | homepage | 2024-05-04 10:20:00 | 2 | 0 |
| C2 | product_page | 2024-05-04 10:25:00 | 5 | 2 |
| C3 | search_results | 2024-05-04 10:18:00 | 3 | 1 |
| C4 | cart | 2024-05-04 10:30:00 | 8 | 4 |
| C5 | checkout | 2024-05-04 10:35:00 | 10 | 3 |

### Sample: `cassandra.customers.recent_transactions`

| transaction_id | customer_id | amount | transaction_time | status | payment_method |
|----------------|-------------|--------|------------------|--------|----------------|
| T1 | C1 | 1500.00 | 2024-05-04 10:15:00 | pending | credit_card |
| T2 | C2 | 8000.00 | 2024-05-04 09:45:00 | completed | upi |
| T3 | C3 | 1200.00 | 2024-05-04 10:10:00 | failed | debit_card |
| T4 | C1 | 2200.00 | 2024-05-04 08:30:00 | completed | net_banking |
| T5 | C4 | 5000.00 | 2024-05-04 10:20:00 | pending | credit_card |

---

## Data Governance

### Data Retention Policies

| Table | Retention Period | Archival Strategy |
|-------|------------------|-------------------|
| `customers` (Iceberg) | Indefinite | None (master data) |
| `orders` (Iceberg) | 7 years | Partition by year |
| `customer_sessions` (Cassandra) | 24 hours | TTL auto-delete |
| `recent_transactions` (Cassandra) | 48 hours | Move to Iceberg for long-term |

### Data Quality Rules

1. **Referential Integrity:**
   - All `customer_id` in orders must exist in customers
   - All `customer_id` in sessions should exist in customers (soft constraint)

2. **Data Freshness:**
   - Cassandra data: Real-time (< 1 second lag)
   - Iceberg data: Batch updates (daily or on-demand)

3. **Data Completeness:**
   - Required fields must not be NULL
   - Email format validation
   - Amount values must be positive

---

## Performance Optimization

### Indexing Strategy

**Iceberg Tables:**
- Partitioned by date fields for time-based queries
- Sorted by customer_id for join optimization

**Cassandra Tables:**
- Partition key on customer_id for fast lookups
- Consider secondary index on status for transaction queries

### Query Optimization Tips

1. **Always filter on partition keys** when querying Cassandra
2. **Use date range filters** on Iceberg for better performance
3. **Limit result sets** in federated queries
4. **Push down predicates** to source systems

---

## Appendix: SQL Quick Reference

### Create All Tables

```sql
-- Iceberg Schema
CREATE SCHEMA IF NOT EXISTS iceberg_data.workshop;

-- Iceberg Tables
CREATE TABLE iceberg_data.workshop.customers (...);
CREATE TABLE iceberg_data.workshop.orders (...);

-- Cassandra Keyspace
CREATE KEYSPACE customers WITH replication = {...};

-- Cassandra Tables
CREATE TABLE customers.customer_sessions (...);
CREATE TABLE customers.recent_transactions (...);
```

### Drop All Tables (Cleanup)

```sql
-- Iceberg
DROP TABLE IF EXISTS iceberg_data.workshop.orders;
DROP TABLE IF EXISTS iceberg_data.workshop.customers;
DROP SCHEMA IF EXISTS iceberg_data.workshop;

-- Cassandra
DROP TABLE IF EXISTS customers.recent_transactions;
DROP TABLE IF EXISTS customers.customer_sessions;
DROP KEYSPACE IF EXISTS customers;
```

---

*Last Updated: 2024*
*Version: 1.0*