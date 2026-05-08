# 🔗 Integration Guide

Complete guide for integrating the federated query library with various tools, platforms, and workflows.

## 📋 Table of Contents

1. [Overview](#overview)
2. [BI Tools Integration](#bi-tools-integration)
3. [API Integration](#api-integration)
4. [Marketing Automation](#marketing-automation)
5. [CRM Integration](#crm-integration)
6. [Real-Time Alerting](#real-time-alerting)
7. [Data Pipeline Integration](#data-pipeline-integration)
8. [Custom Applications](#custom-applications)

---

## Overview

This guide shows how to integrate the query library with external systems to create automated workflows, dashboards, and applications.

### Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Integration Layer                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  BI Tools         APIs           Marketing      CRM         │
│  ├─ Tableau       ├─ REST        ├─ Mailchimp  ├─ Salesforce│
│  ├─ Power BI      ├─ GraphQL     ├─ SendGrid   ├─ HubSpot   │
│  └─ Looker        └─ WebSocket   └─ Braze      └─ Zendesk   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Presto Query Engine (watsonx.data)           │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                  │
│         ┌────────────────┴────────────────┐                 │
│         │                                 │                 │
│  ┌──────▼──────┐                  ┌───────▼──────┐          │
│  │   Iceberg   │                  │  Cassandra   │          │
│  │ (Historical)│                  │ (Real-time)  │          │
│  └─────────────┘                  └──────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

---

## BI Tools Integration

### Tableau Integration

#### Setup Connection

1. **Install Presto JDBC Driver**
   - Download from [Presto JDBC](https://prestodb.io/docs/current/installation/jdbc.html)
   - Place in Tableau drivers folder

2. **Create Data Source**
   ```
   Server: your-watsonx-host
   Port: 8080
   Catalog: iceberg_data
   Schema: customers_schema
   Authentication: Username/Password
   ```

3. **Create Custom SQL Connection**
   ```sql
   -- Use any query from the library
   -- Example: Customer 360 View
   <paste query from 01_customer_360_view.sql>
   ```

#### Create Dashboard

**Dashboard 1: Customer Analytics**
```yaml
Sheets:
  - Customer Segmentation (Pie Chart)
    - Dimension: rfm_segment
    - Measure: COUNT(customer_id)
  
  - Lifetime Value Distribution (Histogram)
    - Dimension: lifetime_value (bins)
    - Measure: COUNT(customer_id)
  
  - Geographic Distribution (Map)
    - Dimension: country, city
    - Measure: SUM(lifetime_value)
  
  - Real-Time Activity (Bar Chart)
    - Dimension: current_page
    - Measure: COUNT(customer_id)
    - Filter: activity_status = 'Active Now'
```

**Dashboard 2: Operations Monitor**
```yaml
Sheets:
  - Active Users (Big Number)
    - Measure: COUNT(DISTINCT customer_id)
    - Filter: minutes_since_active <= 5
  
  - Customers at Checkout (Big Number)
    - Measure: COUNT(customer_id)
    - Filter: current_page = 'checkout'
  
  - Alert Feed (Table)
    - Columns: customer_id, name, alert_priority, lifetime_value
    - Sort: alert_priority DESC
  
  - Conversion Funnel (Funnel Chart)
    - Stages: homepage → product_page → cart → checkout
```

#### Refresh Schedule

```python
# Tableau Server/Online refresh schedule
import tableauserverclient as TSC

server = TSC.Server('https://your-tableau-server')
server.auth.sign_in(TSC.TableauAuth('username', 'password'))

# Schedule refresh every hour
schedule = TSC.ScheduleItem('Hourly Refresh', 
                           priority=50,
                           schedule_type=TSC.ScheduleItem.Type.Hourly,
                           interval_item=TSC.IntervalItem(hours=1))
```

---

### Power BI Integration

#### Setup Connection

1. **Get Data → More → Presto**
2. Configure connection:
   ```
   Server: your-watsonx-host:8080
   Catalog: iceberg_data
   ```

3. **Advanced Options → SQL Statement**
   ```sql
   -- Paste query from library
   SELECT * FROM (
     <paste query here>
   ) AS query_result
   ```

#### Create Report

**Page 1: Executive Dashboard**
```
Visuals:
  - Card: Total Customers
  - Card: Active Users
  - Card: Revenue at Risk
  - Line Chart: Daily Active Users (last 30 days)
  - Donut Chart: Customer Tier Distribution
  - Table: Top 10 Customers by Lifetime Value
```

**Page 2: Churn Analysis**
```
Visuals:
  - Gauge: Churn Risk Score (average)
  - Bar Chart: Customers by Risk Level
  - Scatter Plot: Lifetime Value vs Days Since Last Order
  - Table: High-Risk Customers with Actions
```

#### Power BI Service Refresh

```powershell
# PowerShell script for scheduled refresh
$datasetId = "your-dataset-id"
$refreshUrl = "https://api.powerbi.com/v1.0/myorg/datasets/$datasetId/refreshes"

Invoke-RestMethod -Method Post -Uri $refreshUrl `
  -Headers @{Authorization = "Bearer $accessToken"}
```

---

### Looker Integration

#### Create LookML Model

```lookml
# customer_analytics.model.lkml
connection: "watsonx_presto"

include: "*.view.lkml"

explore: customer_360 {
  from: customer_360_view
  
  join: customer_sessions {
    sql_on: ${customer_360.customer_id} = ${customer_sessions.customer_id} ;;
    relationship: one_to_one
  }
}
```

#### Create View

```lookml
# customer_360_view.view.lkml
view: customer_360_view {
  sql_table_name: (
    SELECT * FROM (
      -- Paste query from 01_customer_360_view.sql
    ) AS customer_data
  ) ;;
  
  dimension: customer_id {
    type: string
    primary_key: yes
    sql: ${TABLE}.customer_id ;;
  }
  
  dimension: name {
    type: string
    sql: ${TABLE}.name ;;
  }
  
  measure: total_lifetime_value {
    type: sum
    sql: ${TABLE}.lifetime_value ;;
    value_format_name: usd
  }
}
```

---

## API Integration

### REST API with FastAPI

#### Setup

```python
# api/main.py
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional
import prestodb
from datetime import datetime

app = FastAPI(title="Customer Analytics API")

# Presto connection
def get_presto_connection():
    return prestodb.dbapi.connect(
        host='your-watsonx-host',
        port=8080,
        user='your-user',
        catalog='iceberg_data',
        schema='customers_schema'
    )

# Models
class Customer360(BaseModel):
    customer_id: str
    name: str
    customer_tier: str
    lifetime_value: float
    total_orders: int
    current_page: Optional[str]
    items_in_cart: Optional[int]
    last_active_time: Optional[datetime]

class ChurnRisk(BaseModel):
    customer_id: str
    name: str
    churn_risk_score: int
    churn_risk_level: str
    revenue_at_risk: float
    recommended_action: str
```

#### Endpoints

```python
@app.get("/api/v1/customer/{customer_id}", response_model=Customer360)
async def get_customer_360(customer_id: str):
    """Get complete customer 360 view"""
    
    query = f"""
    SELECT 
        c.customer_id,
        c.name,
        c.customer_tier,
        SUM(o.amount) AS lifetime_value,
        COUNT(o.order_id) AS total_orders,
        s.current_page,
        s.items_in_cart,
        s.last_active_time
    FROM iceberg_data.customers_schema.customers_details c
    LEFT JOIN iceberg_data.customers_schema.customers_orders o 
        ON c.customer_id = o.customer_id
    LEFT JOIN astradb_catalog.customers.customer_sessions s 
        ON c.customer_id = s.customer_id
    WHERE c.customer_id = '{customer_id}'
    GROUP BY c.customer_id, c.name, c.customer_tier, 
             s.current_page, s.items_in_cart, s.last_active_time
    """
    
    conn = get_presto_connection()
    cursor = conn.cursor()
    cursor.execute(query)
    result = cursor.fetchone()
    
    if not result:
        raise HTTPException(status_code=404, detail="Customer not found")
    
    return Customer360(**dict(zip([d[0] for d in cursor.description], result)))

@app.get("/api/v1/customers/at-checkout", response_model=List[Customer360])
async def get_customers_at_checkout(
    tier: Optional[str] = Query(None, description="Filter by customer tier")
):
    """Get customers currently at checkout"""
    
    # Use query from 02_high_value_customers_at_checkout.sql
    query = """
    SELECT 
        c.customer_id,
        c.name,
        c.customer_tier,
        SUM(o.amount) AS lifetime_value,
        COUNT(o.order_id) AS total_orders,
        s.current_page,
        s.items_in_cart,
        s.last_active_time
    FROM iceberg_data.customers_schema.customers_details c
    JOIN iceberg_data.customers_schema.customers_orders o 
        ON c.customer_id = o.customer_id
    JOIN astradb_catalog.customers.customer_sessions s 
        ON c.customer_id = s.customer_id
    WHERE LOWER(s.current_page) = 'checkout'
    """
    
    if tier:
        query += f" AND c.customer_tier = '{tier}'"
    
    query += """
    GROUP BY c.customer_id, c.name, c.customer_tier,
             s.current_page, s.items_in_cart, s.last_active_time
    ORDER BY lifetime_value DESC
    """
    
    conn = get_presto_connection()
    cursor = conn.cursor()
    cursor.execute(query)
    
    results = []
    for row in cursor.fetchall():
        results.append(Customer360(**dict(zip([d[0] for d in cursor.description], row))))
    
    return results

@app.get("/api/v1/churn-risk", response_model=List[ChurnRisk])
async def get_churn_risk(
    risk_level: Optional[str] = Query(None, description="Filter by risk level")
):
    """Get customers at risk of churning"""
    
    # Use query from 07_churn_risk_prediction.sql
    # (simplified for API response)
    
    conn = get_presto_connection()
    cursor = conn.cursor()
    cursor.execute(query)
    
    results = []
    for row in cursor.fetchall():
        results.append(ChurnRisk(**dict(zip([d[0] for d in cursor.description], row))))
    
    return results
```

#### Run API

```bash
# Install dependencies
pip install fastapi uvicorn prestodb

# Run server
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload

# Access API docs
# http://localhost:8000/docs
```

#### API Usage Examples

```bash
# Get customer 360 view
curl http://localhost:8000/api/v1/customer/C001

# Get customers at checkout
curl http://localhost:8000/api/v1/customers/at-checkout?tier=Platinum

# Get churn risk customers
curl http://localhost:8000/api/v1/churn-risk?risk_level=Critical
```

---

## Marketing Automation

### Mailchimp Integration

#### Abandoned Cart Campaign

```python
# marketing/abandoned_cart.py
import prestodb
import mailchimp_marketing as MailchimpMarketing
from mailchimp_marketing.api_client import ApiClientError

# Initialize Mailchimp
mailchimp = MailchimpMarketing.Client()
mailchimp.set_config({
    "api_key": "your-api-key",
    "server": "us1"
})

def get_abandoned_carts():
    """Query abandoned carts from 03_abandoned_cart_recovery.sql"""
    conn = prestodb.dbapi.connect(
        host='your-watsonx-host',
        port=8080,
        user='your-user'
    )
    
    cursor = conn.cursor()
    cursor.execute(open('queries/03_abandoned_cart_recovery.sql').read())
    
    return cursor.fetchall()

def send_recovery_email(customer):
    """Send personalized recovery email"""
    
    # Determine discount based on time since abandonment
    if customer['hours_since_active'] < 6:
        discount = 0
        subject = "You left items in your cart!"
    elif customer['hours_since_active'] < 24:
        discount = 10
        subject = "Complete your purchase and save 10%!"
    else:
        discount = 15
        subject = "Last chance - 15% off your cart!"
    
    try:
        response = mailchimp.messages.send({
            "message": {
                "subject": subject,
                "from_email": "support@yourcompany.com",
                "to": [{
                    "email": customer['email'],
                    "name": customer['name'],
                    "type": "to"
                }],
                "merge_vars": [{
                    "rcpt": customer['email'],
                    "vars": [
                        {"name": "FNAME", "content": customer['name']},
                        {"name": "CART_ITEMS", "content": customer['items_in_cart']},
                        {"name": "DISCOUNT", "content": discount},
                        {"name": "CART_VALUE", "content": customer['estimated_cart_value']}
                    ]
                }]
            }
        })
        print(f"Email sent to {customer['email']}: {response}")
    except ApiClientError as error:
        print(f"Error: {error.text}")

# Run campaign
if __name__ == "__main__":
    abandoned_carts = get_abandoned_carts()
    for cart in abandoned_carts:
        if cart['recovery_priority'] in ['High Priority', 'Medium Priority']:
            send_recovery_email(cart)
```

#### Schedule with Cron

```bash
# Run every hour
0 * * * * /usr/bin/python3 /path/to/marketing/abandoned_cart.py
```

---

### SendGrid Integration

#### Churn Prevention Campaign

```python
# marketing/churn_prevention.py
import prestodb
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Personalization

sg = SendGridAPIClient('your-sendgrid-api-key')

def get_churn_risk_customers():
    """Query from 07_churn_risk_prediction.sql"""
    conn = prestodb.dbapi.connect(
        host='your-watsonx-host',
        port=8080,
        user='your-user'
    )
    
    cursor = conn.cursor()
    # Filter for Critical and High risk only
    query = open('queries/07_churn_risk_prediction.sql').read()
    query += " AND churn_risk_level IN ('Critical', 'High')"
    
    cursor.execute(query)
    return cursor.fetchall()

def send_winback_email(customer):
    """Send personalized win-back email"""
    
    # Template based on risk level
    if customer['churn_risk_level'] == 'Critical':
        template_id = 'd-critical-winback-template'
        discount = 25
    else:
        template_id = 'd-high-winback-template'
        discount = 20
    
    message = Mail(
        from_email='retention@yourcompany.com',
        to_emails=customer['email']
    )
    
    message.template_id = template_id
    message.dynamic_template_data = {
        'customer_name': customer['name'],
        'customer_tier': customer['customer_tier'],
        'lifetime_value': customer['lifetime_value'],
        'discount_percentage': discount,
        'recommended_products': get_recommended_products(customer['customer_id'])
    }
    
    try:
        response = sg.send(message)
        print(f"Win-back email sent to {customer['email']}: {response.status_code}")
    except Exception as e:
        print(f"Error: {e}")

# Run campaign
if __name__ == "__main__":
    at_risk_customers = get_churn_risk_customers()
    for customer in at_risk_customers:
        send_winback_email(customer)
```

---

## CRM Integration

### Salesforce Integration

#### Sync Customer Data

```python
# crm/salesforce_sync.py
from simple_salesforce import Salesforce
import prestodb

# Salesforce connection
sf = Salesforce(
    username='your-username',
    password='your-password',
    security_token='your-token'
)

def sync_customer_360():
    """Sync customer 360 data to Salesforce"""
    
    # Get data from query
    conn = prestodb.dbapi.connect(
        host='your-watsonx-host',
        port=8080,
        user='your-user'
    )
    
    cursor = conn.cursor()
    cursor.execute(open('queries/01_customer_360_view.sql').read())
    
    for customer in cursor.fetchall():
        # Update or create Salesforce contact
        try:
            # Try to find existing contact
            contact = sf.Contact.get_by_custom_id('Customer_ID__c', customer['customer_id'])
            
            # Update
            sf.Contact.update(contact['Id'], {
                'Lifetime_Value__c': customer['lifetime_value'],
                'Total_Orders__c': customer['total_orders'],
                'Customer_Tier__c': customer['customer_tier'],
                'Current_Page__c': customer['current_page'],
                'Items_In_Cart__c': customer['items_in_cart'],
                'Last_Active__c': customer['last_active_time']
            })
            print(f"Updated contact: {customer['customer_id']}")
            
        except Exception:
            # Create new contact
            sf.Contact.create({
                'Customer_ID__c': customer['customer_id'],
                'FirstName': customer['name'].split()[0],
                'LastName': ' '.join(customer['name'].split()[1:]),
                'Email': customer['email'],
                'Lifetime_Value__c': customer['lifetime_value'],
                'Total_Orders__c': customer['total_orders'],
                'Customer_Tier__c': customer['customer_tier']
            })
            print(f"Created contact: {customer['customer_id']}")

# Schedule sync every 6 hours
if __name__ == "__main__":
    sync_customer_360()
```

#### Create Salesforce Tasks for High-Risk Customers

```python
def create_retention_tasks():
    """Create tasks for sales team to contact at-risk customers"""
    
    conn = prestodb.dbapi.connect(
        host='your-watsonx-host',
        port=8080,
        user='your-user'
    )
    
    cursor = conn.cursor()
    query = open('queries/07_churn_risk_prediction.sql').read()
    query += " AND churn_risk_level = 'Critical'"
    cursor.execute(query)
    
    for customer in cursor.fetchall():
        # Find Salesforce contact
        contact = sf.Contact.get_by_custom_id('Customer_ID__c', customer['customer_id'])
        
        # Create task
        sf.Task.create({
            'WhoId': contact['Id'],
            'Subject': f"URGENT: Retention call for {customer['name']}",
            'Description': f"""
                Customer at critical churn risk!
                
                Lifetime Value: ${customer['lifetime_value']}
                Risk Score: {customer['churn_risk_score']}
                Days Since Last Order: {customer['days_since_last_order']}
                
                Recommended Action: {customer['recommended_action']}
            """,
            'Priority': 'High',
            'Status': 'Not Started',
            'ActivityDate': datetime.now().date()
        })
        print(f"Created task for {customer['name']}")
```

---

## Real-Time Alerting

### Slack Integration

```python
# alerts/slack_alerts.py
import prestodb
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
import time

slack_client = WebClient(token='your-slack-token')

def check_vip_at_checkout():
    """Monitor VIP customers at checkout"""
    
    conn = prestodb.dbapi.connect(
        host='your-watsonx-host',
        port=8080,
        user='your-user'
    )
    
    cursor = conn.cursor()
    query = """
    SELECT 
        c.customer_id,
        c.name,
        c.customer_tier,
        SUM(o.amount) AS lifetime_value,
        s.session_duration_minutes,
        s.items_in_cart
    FROM iceberg_data.customers_schema.customers_details c
    JOIN iceberg_data.customers_schema.customers_orders o ON c.customer_id = o.customer_id
    JOIN astradb_catalog.customers.customer_sessions s ON c.customer_id = s.customer_id
    WHERE LOWER(s.current_page) = 'checkout'
      AND c.customer_tier IN ('Platinum', 'Gold')
      AND s.session_duration_minutes > 5
    GROUP BY c.customer_id, c.name, c.customer_tier, s.session_duration_minutes, s.items_in_cart
    """
    
    cursor.execute(query)
    
    for customer in cursor.fetchall():
        send_slack_alert(customer)

def send_slack_alert(customer):
    """Send alert to Slack channel"""
    
    message = f"""
    🚨 *VIP CUSTOMER NEEDS HELP AT CHECKOUT* 🚨
    
    *Customer:* {customer['name']} ({customer['customer_tier']})
    *Lifetime Value:* ${customer['lifetime_value']:,.2f}
    *Time at Checkout:* {customer['session_duration_minutes']} minutes
    *Items in Cart:* {customer['items_in_cart']}
    
    *Action Required:* Initiate live chat or phone call immediately!
    """
    
    try:
        response = slack_client.chat_postMessage(
            channel='#customer-support',
            text=message,
            username='Customer Analytics Bot'
        )
        print(f"Alert sent for {customer['name']}")
    except SlackApiError as e:
        print(f"Error sending alert: {e}")

# Run continuously
if __name__ == "__main__":
    while True:
        check_vip_at_checkout()
        time.sleep(30)  # Check every 30 seconds
```

---

## Data Pipeline Integration

### Apache Airflow DAG

```python
# dags/customer_analytics_dag.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.presto.operators.presto import PrestoOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'customer_analytics_pipeline',
    default_args=default_args,
    description='Daily customer analytics pipeline',
    schedule_interval='0 8 * * *',  # Daily at 8 AM
    catchup=False
)

# Task 1: Calculate engagement scores
calculate_engagement = PrestoOperator(
    task_id='calculate_engagement_scores',
    sql='queries/04_customer_engagement_score.sql',
    presto_conn_id='watsonx_presto',
    dag=dag
)

# Task 2: Run RFM segmentation
run_rfm_segmentation = PrestoOperator(
    task_id='run_rfm_segmentation',
    sql='queries/05_rfm_segmentation.sql',
    presto_conn_id='watsonx_presto',
    dag=dag
)

# Task 3: Identify churn risk
identify_churn_risk = PrestoOperator(
    task_id='identify_churn_risk',
    sql='queries/07_churn_risk_prediction.sql',
    presto_conn_id='watsonx_presto',
    dag=dag
)

# Task 4: Send reports
def send_daily_report():
    # Implementation here
    pass

send_report = PythonOperator(
    task_id='send_daily_report',
    python_callable=send_daily_report,
    dag=dag
)

# Define task dependencies
calculate_engagement >> run_rfm_segmentation >> identify_churn_risk >> send_report
```

---

## Custom Applications

### React Dashboard

```javascript
// src/components/CustomerDashboard.jsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';

function CustomerDashboard() {
  const [customersAtCheckout, setCustomersAtCheckout] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await axios.get('http://localhost:8000/api/v1/customers/at-checkout');
        setCustomersAtCheckout(response.data);
        setLoading(false);
      } catch (error) {
        console.error('Error fetching data:', error);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 30000); // Refresh every 30 seconds

    return () => clearInterval(interval);
  }, []);

  if (loading) return <div>Loading...</div>;

  return (
    <div className="dashboard">
      <h1>Customers at Checkout</h1>
      <table>
        <thead>
          <tr>
            <th>Customer</th>
            <th>Tier</th>
            <th>Lifetime Value</th>
            <th>Items in Cart</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {customersAtCheckout.map(customer => (
            <tr key={customer.customer_id}>
              <td>{customer.name}</td>
              <td>{customer.customer_tier}</td>
              <td>${customer.lifetime_value.toFixed(2)}</td>
              <td>{customer.items_in_cart}</td>
              <td>
                <button onClick={() => initiateChat(customer.customer_id)}>
                  Start Chat
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default CustomerDashboard;
```

---

## Best Practices

### 1. Error Handling
- Always wrap API calls in try-catch blocks
- Implement retry logic for transient failures
- Log errors for debugging

### 2. Performance
- Cache frequently accessed data
- Use connection pooling
- Implement rate limiting

### 3. Security
- Store credentials in environment variables
- Use API keys with limited scope
- Implement authentication/authorization

### 4. Monitoring
- Track API response times
- Monitor query execution times
- Set up alerts for failures

---

## Next Steps

1. ✅ Choose integration platform
2. ✅ Set up authentication
3. ✅ Test with sample data
4. 🚀 Deploy to production
5. 📊 Monitor and optimize

---

*Last Updated: 2024*
*Version: 1.0*