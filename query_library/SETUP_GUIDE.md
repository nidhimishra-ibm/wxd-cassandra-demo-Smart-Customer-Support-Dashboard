# 🛠️ Environment Setup Guide

Complete guide for setting up your environment to run the federated queries in this library.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [watsonx.data Setup](#watsonxdata-setup)
3. [AstraDB Setup](#astradb-setup)
4. [Connection Configuration](#connection-configuration)
5. [Data Population](#data-population)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts

- **IBM Cloud Account** (for watsonx.data via TechZone)
- **DataStax Astra Account** (free tier available)
- **SSH Client** (for VM access)

### Required Knowledge

- Basic SQL
- Understanding of data catalogs
- Familiarity with Iceberg and Cassandra concepts

### Tools Needed

- Web browser (Chrome, Firefox, Safari)
- Terminal/Command line access
- Text editor for SQL queries

---

## watsonx.data Setup

### Step 1: Provision watsonx.data Environment

#### 1.1 Access IBM TechZone

1. Navigate to [IBM TechZone](https://techzone.ibm.com/)
2. Search for "watsonx.data"
3. Select the appropriate environment image

#### 1.2 Create Reservation

1. Click "Reserve"
2. Fill in reservation details:
   - **Purpose:** Education/Demo/PoC
   - **Duration:** Select appropriate timeframe
   - **Region:** Choose closest region
3. Submit reservation
4. Wait for approval email (usually within 1 hour)

#### 1.3 Access Your Environment

Once provisioned, you'll receive:
- **VM IP Address**
- **SSH Credentials**
- **watsonx.data UI URL**
- **Presto Endpoint**

#### 1.4 Pre-configured Components

Your environment includes:
- Presto query engine
- Iceberg catalog (MinIO storage)
- Hive Metastore
- Infrastructure Manager

### Step 2: Create Iceberg Schema and Tables

#### 2.1 Access watsonx.data UI

```
URL: https://<your-vm-ip>:9443
Username: <provided-username>
Password: <provided-password>
```

#### 2.2 Navigate to Query Workspace

1. Click "Query workspace" in left menu
2. Select Presto engine
3. Choose `iceberg_data` catalog

#### 2.3 Create Schema

```sql
CREATE SCHEMA IF NOT EXISTS iceberg_data.customers_schema
WITH (location = 's3a://iceberg-bucket/customers_schema');
```

#### 2.4 Create Customers Table

```sql
CREATE TABLE iceberg_data.customers_schema.customers_details (
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

#### 2.5 Create Orders Table

```sql
CREATE TABLE iceberg_data.customers_schema.customers_orders (
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

#### 2.6 Insert Sample Data

**Customers:**
```sql
INSERT INTO iceberg_data.customers_schema.customers_details VALUES
('C001', 'Arjun Patel', 'arjun@example.com', 'Mumbai', 'India', DATE '2022-01-15', 'Gold'),
('C002', 'Sarah Johnson', 'sarah@example.com', 'New York', 'USA', DATE '2021-06-20', 'Platinum'),
('C003', 'Li Wei', 'liwei@example.com', 'Shanghai', 'China', DATE '2022-03-10', 'Silver'),
('C004', 'Maria Garcia', 'maria@example.com', 'Madrid', 'Spain', DATE '2021-11-05', 'Gold'),
('C005', 'James Smith', 'james@example.com', 'London', 'UK', DATE '2022-02-28', 'Bronze');
```

**Orders:**
```sql
INSERT INTO iceberg_data.customers_schema.customers_orders VALUES
('O001', 'C001', 'Laptop Pro', 1299.99, DATE '2023-01-10', 'Delivered'),
('O002', 'C001', 'Wireless Mouse', 29.99, DATE '2023-02-15', 'Delivered'),
('O003', 'C001', 'USB-C Hub', 49.99, DATE '2023-03-20', 'Delivered'),
('O004', 'C002', 'Monitor 4K', 599.99, DATE '2023-01-25', 'Delivered'),
('O005', 'C002', 'Keyboard Mechanical', 149.99, DATE '2023-02-10', 'Delivered');
```

---

## AstraDB Setup

### Step 1: Create AstraDB Account

1. Go to [astra.datastax.com](https://astra.datastax.com/)
2. Sign up for free account
3. Verify email address

### Step 2: Create Database

1. Click "Create Database"
2. Configure:
   - **Database name:** `customer_analytics`
   - **Keyspace name:** `customers`
   - **Provider:** AWS/GCP/Azure
   - **Region:** Choose closest region
3. Click "Create Database"
4. Wait for database to become Active (~2-3 minutes)

### Step 3: Generate Token

1. Go to database settings
2. Click "Generate Token"
3. Select role: "Database Administrator"
4. Save the token securely (you'll need it later)
5. Download the Secure Connect Bundle

### Step 4: Create Tables

#### 4.1 Access CQL Console

1. In AstraDB UI, click "CQL Console"
2. Select your keyspace: `customers`

#### 4.2 Create customer_sessions Table

```sql
CREATE TABLE customers.customer_sessions (
    customer_id TEXT PRIMARY KEY,
    current_page TEXT,
    last_active_time TIMESTAMP,
    session_duration_minutes INT,
    items_in_cart INT
);
```

#### 4.3 Create recent_transactions Table

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

#### 4.4 Insert Sample Data

**Sessions:**
```sql
INSERT INTO customers.customer_sessions (customer_id, current_page, last_active_time, session_duration_minutes, items_in_cart)
VALUES ('C001', 'homepage', toTimestamp(now()), 2, 0);

INSERT INTO customers.customer_sessions (customer_id, current_page, last_active_time, session_duration_minutes, items_in_cart)
VALUES ('C002', 'product_page', toTimestamp(now()), 5, 2);

INSERT INTO customers.customer_sessions (customer_id, current_page, last_active_time, session_duration_minutes, items_in_cart)
VALUES ('C003', 'search_results', toTimestamp(now()), 3, 1);

INSERT INTO customers.customer_sessions (customer_id, current_page, last_active_time, session_duration_minutes, items_in_cart)
VALUES ('C004', 'cart', toTimestamp(now()), 8, 4);

INSERT INTO customers.customer_sessions (customer_id, current_page, last_active_time, session_duration_minutes, items_in_cart)
VALUES ('C005', 'checkout', toTimestamp(now()), 10, 3);
```

**Transactions:**
```sql
INSERT INTO customers.recent_transactions (transaction_id, customer_id, amount, transaction_time, status, payment_method)
VALUES ('T001', 'C001', 1500.00, toTimestamp(now()), 'pending', 'credit_card');

INSERT INTO customers.recent_transactions (transaction_id, customer_id, amount, transaction_time, status, payment_method)
VALUES ('T002', 'C002', 8000.00, toTimestamp(now()), 'completed', 'upi');
```

---

## Connection Configuration

### Step 1: Setup CQL Proxy

CQL Proxy bridges AstraDB to watsonx.data's Presto engine.

#### 1.1 SSH into watsonx.data VM

```bash
ssh <username>@<vm-ip-address>
```

#### 1.2 Start CQL Proxy Container

```bash
docker run -d \
  --name cqlproxy \
  -p 9042:9042 \
  -v /path/to/secure-connect-bundle.zip:/bundle/secure-connect-bundle.zip \
  -e ASTRA_TOKEN="<your-astra-token>" \
  -e ASTRA_BUNDLE="/bundle/secure-connect-bundle.zip" \
  datastax/cql-proxy:latest
```

#### 1.3 Verify CQL Proxy

```bash
docker ps | grep cqlproxy
docker logs cqlproxy
```

### Step 2: Add Cassandra Catalog to watsonx.data

#### 2.1 Access Infrastructure Manager

1. In watsonx.data UI, click "Infrastructure manager"
2. Click "Add component" → "Add catalog"

#### 2.2 Configure Cassandra Catalog

```yaml
Catalog name: astradb_catalog
Catalog type: Cassandra
Connection properties:
  - cassandra.contact-points: <vm-ip-address>
  - cassandra.native-protocol-port: 9042
  - cassandra.load-policy.dc-aware.local-dc: datacenter1
  - cassandra.username: token
  - cassandra.password: <your-astra-token>
```

#### 2.3 Associate with Presto Engine

1. Click on Presto engine
2. Click "Associate catalog"
3. Select `astradb_catalog`
4. Click "Associate"

---

## Data Population

### Automated Data Loading Script

Create a script to populate both systems:

```python
# populate_data.py
import prestodb
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider

# Presto connection for Iceberg
presto_conn = prestodb.dbapi.connect(
    host='your-watsonx-host',
    port=8080,
    user='your-user',
    catalog='iceberg_data',
    schema='customers_schema'
)

# Cassandra connection for AstraDB
cloud_config = {'secure_connect_bundle': '/path/to/bundle.zip'}
auth_provider = PlainTextAuthProvider('token', 'YOUR_TOKEN')
cluster = Cluster(cloud=cloud_config, auth_provider=auth_provider)
cassandra_session = cluster.connect('customers')

# Insert data functions here...
```

---

## Verification

### Step 1: Verify Iceberg Tables

```sql
-- Check customers
SELECT COUNT(*) FROM iceberg_data.customers_schema.customers_details;

-- Check orders
SELECT COUNT(*) FROM iceberg_data.customers_schema.customers_orders;

-- Sample data
SELECT * FROM iceberg_data.customers_schema.customers_details LIMIT 5;
```

### Step 2: Verify Cassandra Tables

```sql
-- Check sessions
SELECT COUNT(*) FROM astradb_catalog.customers.customer_sessions;

-- Check transactions
SELECT COUNT(*) FROM astradb_catalog.customers.recent_transactions;

-- Sample data
SELECT * FROM astradb_catalog.customers.customer_sessions LIMIT 5;
```

### Step 3: Test Federated Query

```sql
-- Simple join across both systems
SELECT 
    c.customer_id,
    c.name,
    c.customer_tier,
    s.current_page,
    s.items_in_cart
FROM iceberg_data.customers_schema.customers_details c
LEFT JOIN astradb_catalog.customers.customer_sessions s
    ON c.customer_id = s.customer_id
LIMIT 10;
```

**Expected Result:** Should return customer data with session information

---

## Troubleshooting

### Issue 1: Cannot Connect to CQL Proxy

**Symptoms:**
- Cassandra catalog shows as disconnected
- Queries fail with connection error

**Solutions:**
1. Check CQL Proxy is running:
   ```bash
   docker ps | grep cqlproxy
   ```

2. Verify port 9042 is accessible:
   ```bash
   netstat -an | grep 9042
   ```

3. Check CQL Proxy logs:
   ```bash
   docker logs cqlproxy
   ```

4. Restart CQL Proxy:
   ```bash
   docker restart cqlproxy
   ```

### Issue 2: Customer ID Mismatch

**Symptoms:**
- Federated queries return NULL for Cassandra columns
- JOIN produces no matches

**Solutions:**
1. Check customer_id format in both systems:
   ```sql
   -- Iceberg
   SELECT DISTINCT customer_id FROM iceberg_data.customers_schema.customers_details ORDER BY customer_id;
   
   -- Cassandra
   SELECT DISTINCT customer_id FROM astradb_catalog.customers.customer_sessions ORDER BY customer_id;
   ```

2. Standardize format (e.g., C001 vs C1)

3. Update data to match:
   ```sql
   -- See queries/README.md for update scripts
   ```

### Issue 3: Slow Query Performance

**Symptoms:**
- Queries take > 30 seconds
- Timeout errors

**Solutions:**
1. Add WHERE clause to filter data:
   ```sql
   WHERE c.customer_id = 'C001'
   ```

2. Use LIMIT during testing:
   ```sql
   LIMIT 100
   ```

3. Check Presto query plan:
   ```sql
   EXPLAIN SELECT ...
   ```

4. Verify indexes on Cassandra partition keys

### Issue 4: Authentication Errors

**Symptoms:**
- "Authentication failed" errors
- Token expired messages

**Solutions:**
1. Regenerate AstraDB token
2. Update CQL Proxy environment variables
3. Restart CQL Proxy container
4. Update Cassandra catalog configuration

### Issue 5: Schema Not Found

**Symptoms:**
- "Schema does not exist" error
- Tables not visible

**Solutions:**
1. Verify schema creation:
   ```sql
   SHOW SCHEMAS IN iceberg_data;
   ```

2. Check catalog association:
   - Infrastructure Manager → Presto → Associated catalogs

3. Refresh metadata:
   ```sql
   CALL system.sync_partition_metadata('iceberg_data', 'customers_schema', 'customers_details');
   ```

---

## Performance Tuning

### Iceberg Optimization

```sql
-- Partition by date for better performance
CREATE TABLE iceberg_data.customers_schema.orders_partitioned (
    order_id VARCHAR,
    customer_id VARCHAR,
    amount DOUBLE,
    order_date DATE
) WITH (
    format = 'PARQUET',
    partitioning = ARRAY['order_date']
);
```

### Cassandra Optimization

```sql
-- Add secondary index for frequent queries
CREATE INDEX ON customers.customer_sessions (current_page);
```

### Query Optimization

```sql
-- Use predicate pushdown
WHERE o.order_date >= DATE '2024-01-01'  -- Pushed to Iceberg
  AND s.current_page = 'checkout'        -- Pushed to Cassandra
```

---

## Next Steps

1. ✅ Complete environment setup
2. ✅ Verify all connections
3. ✅ Test sample queries
4. 📖 Review [Query Library README](README.md)
5. 🚀 Run queries from the library
6. 🔗 Set up [integrations](INTEGRATION_GUIDE.md)

---

## Additional Resources

- [watsonx.data Documentation](https://www.ibm.com/docs/en/watsonxdata)
- [AstraDB Documentation](https://docs.datastax.com/en/astra/)
- [Presto Documentation](https://prestodb.io/docs/current/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)

---

*Last Updated: 2024*
*Version: 1.0*