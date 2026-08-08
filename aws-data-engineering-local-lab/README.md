# AWS Data Engineering Local Lab
## Local End-to-End Data Engineering Lab: MariaDB -> Apache Hop -> MinIO -> PostgreSQL -> Apache Superset

This project is a complete local hands-on data engineering laboratory for a Windows laptop running Docker Desktop and WSL 2. It is designed to turn AWS Data Engineer certification knowledge into practical engineering experience: source-system extraction, object storage, ETL/ELT, dimensional modeling, incremental loading, slowly changing dimensions, data-quality quarantine, warehouse optimization, BI dashboards, auditability, and Git-based delivery.

The important architecture change in this edition is deliberate:

- **MariaDB is only the operational/source database.**
- **PostgreSQL is the dedicated analytical data warehouse.**
- **MinIO is the S3-compatible data lake.**
- **Apache Hop moves and transforms data.**
- **Apache Superset reads the PostgreSQL warehouse using a read-only BI account.**
- **Jupyter independently profiles and validates data.**

That separation makes the lab much closer to a real enterprise data platform than using one database for both source and analytics.

---

# 1. Target architecture

```text
                         LOCAL DATA ENGINEERING LAB

       Source / OLTP                              Data Lake
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ MariaDB                     │          │ MinIO                        │
│ source_db                   │          │ S3-compatible object store  │
│                             │          │                              │
│ customers                   │          │ raw/                         │
│ products                    │          │ curated/                     │
│ orders                      │          │ archive/                     │
│ order_items                 │          │ rejects/                     │
└──────────────┬───────────────┘          └──────────────┬───────────────┘
               │                                         │
               └────────────────┬────────────────────────┘
                                │
                                v
                    ┌────────────────────────┐
                    │ Apache Hop             │
                    │ ETL / ELT              │
                    │ validation             │
                    │ SCD Type 2             │
                    │ incremental loads      │
                    │ audit / reject routing │
                    └────────────┬───────────┘
                                 │
                                 v
                    ┌────────────────────────┐
                    │ PostgreSQL Warehouse   │
                    │ database: warehouse    │
                    │                        │
                    │ schema dw              │
                    │   dim_date             │
                    │   dim_customer         │
                    │   dim_product          │
                    │   fact_sales           │
                    │   v_sales_detail       │
                    │                        │
                    │ schema control         │
                    │   etl_watermark        │
                    │   etl_audit            │
                    │   data_quality_rejects │
                    │   v_etl_health         │
                    └────────────┬───────────┘
                                 │
                                 v
                    ┌────────────────────────┐
                    │ Apache Superset        │
                    │ dashboards / SQL Lab   │
                    │ read-only bi_reader    │
                    └────────────────────────┘

DBeaver -> inspect MariaDB and PostgreSQL
Jupyter -> profiling, reconciliation, validation
GitHub  -> version SQL, Hop pipelines, docs, notebooks
```

---

# 2. Why use PostgreSQL as the warehouse?

This lab intentionally gives the source and warehouse different database engines. That forces you to practice the kinds of issues a data engineer actually sees:

- data type mapping between systems;
- source-to-target column mapping;
- handling timestamps and numeric precision;
- surrogate keys;
- dimensional schemas;
- cross-engine SQL differences;
- incremental extraction from an OLTP source;
- bulk loading into an analytical target;
- permissions for ETL versus BI users;
- warehouse indexing and query plans;
- independent source/target reconciliation.

PostgreSQL is not a distributed MPP warehouse like Amazon Redshift, but it is an excellent local warehouse for learning SQL modeling, ETL design, permissions, indexing, query plans, constraints, and BI integration.

## AWS concept mapping

| Local component | AWS analogue | What you practice |
|---|---|---|
| MariaDB source | Amazon RDS / Aurora | operational relational ingestion |
| MinIO | Amazon S3 | buckets, prefixes, raw/curated zones |
| PostgreSQL warehouse | RDS PostgreSQL / Aurora PostgreSQL; conceptually a stepping stone to Redshift | analytical schemas and dimensional modeling |
| Apache Hop | AWS Glue / orchestration concepts | extraction, transformation, loading, workflows |
| Superset | Amazon QuickSight conceptually | semantic metrics, BI, dashboards |
| Jupyter | SageMaker / Glue notebooks conceptually | profiling and validation |
| Docker Compose | ECS/EKS concepts | service discovery, networking, volumes |
| `.env` | Secrets Manager / Parameter Store concept | externalized configuration |
| GitHub | CI/CD source control | versioned engineering delivery |

Later you can migrate components one by one instead of rebuilding the project from scratch.

---

# 3. Project contents

```text
aws-data-engineering-local-lab/
│
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
│
├── drivers/
│   └── README.md
│
├── sql/
│   ├── mariadb/
│   │   └── 01-source-schema.sql
│   └── postgres/
│       ├── 00-create-bi-role.sh
│       ├── 01-warehouse-schema.sql
│       └── 99-grant-bi-role.sh
│
├── superset/
│   └── Dockerfile
│
├── scripts/
│   ├── generate_sales_data.py
│   ├── load_csv_to_mariadb.sql
│   └── postgres_validation.sql
│
├── datasets/
│   └── README.md
│
├── hop-project/
│   └── README.md
│
├── notebooks/
│   └── README.md
│
└── docs/
    ├── INSTALLATION_GUIDE.md
    └── LAB_CHECKLIST.md
```

For a clean-machine installation walkthrough, use **`docs/INSTALLATION_GUIDE.md`**. The README explains the architecture and labs; the installation guide is the reproducible setup runbook.

---

# 4. Laptop recommendations

A practical minimum is:

```text
RAM:       16 GB
CPU:       4 cores
Free disk: 25-40 GB
```

A more comfortable environment is:

```text
RAM:       32 GB
CPU:       6-8 cores
Free disk: 50+ GB
```

If your laptop has 16 GB RAM, avoid running a very large Jupyter job while Hop, Superset, DBeaver, MariaDB, PostgreSQL, and MinIO are all heavily active.

---

# 5. Windows and WSL 2 preparation

Use Docker Desktop with the WSL 2 backend.

Open PowerShell:

```powershell
wsl --version
wsl --update
wsl --status

docker version
docker compose version
```

Open your WSL distribution:

```powershell
wsl
```

Inside WSL:

```bash
mkdir -p ~/projects
cd ~/projects
```

Place or extract this project here:

```text
~/projects/aws-data-engineering-local-lab
```

Keeping active Docker development files inside the Linux filesystem generally gives a smoother WSL workflow than deeply nested Windows-mounted paths.

---

# 6. Configure credentials

From the project folder:

```bash
cp .env.example .env
```

Edit `.env`.

Example structure:

```dotenv
MARIADB_ROOT_PASSWORD=ChangeMe_Root_123!
MARIADB_USER=labuser
MARIADB_PASSWORD=ChangeMe_Source_123!

POSTGRES_DB=warehouse
POSTGRES_USER=dw_admin
POSTGRES_PASSWORD=ChangeMe_DW_Admin_123!
POSTGRES_BI_USER=bi_reader
POSTGRES_BI_PASSWORD=ChangeMe_BI_ReadOnly_123!

MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=ChangeMe_MinIO_123!

SUPERSET_ADMIN_USER=admin
SUPERSET_ADMIN_PASSWORD=ChangeMe_Superset_123!
SUPERSET_ADMIN_EMAIL=admin@example.local
SUPERSET_SECRET_KEY=replace-with-a-long-random-string-at-least-42-characters
```

Generate a strong Superset secret:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

Paste the output into:

```dotenv
SUPERSET_SECRET_KEY=...
```

Do not commit `.env` to GitHub.

---

# 7. Start the platform

First inspect the resolved Compose file:

```bash
docker compose config
```

Pull images:

```bash
docker compose pull
```

Build and start:

```bash
docker compose up -d --build
```

Check status:

```bash
docker compose ps
```

Expected containers:

```text
de-mariadb
de-postgres-dw
de-minio
de-minio-init
de-hop-web
de-superset
```

`de-hop-runner` is in an optional Compose profile and starts only when requested.

Watch logs:

```bash
docker compose logs -f mariadb postgres minio hop-web superset
```

Individual logs:

```bash
docker compose logs -f postgres
docker compose logs -f mariadb
docker compose logs -f hop-web
docker compose logs -f superset
```

---

# 8. Service endpoints

| Service | From Windows/WSL host | From another Docker container |
|---|---|---|
| MariaDB source | `localhost:3307` | `mariadb:3306` |
| PostgreSQL warehouse | `localhost:5433` | `postgres:5432` |
| MinIO API | `localhost:9000` | `minio:9000` |
| MinIO Console | `http://localhost:9001` | n/a |
| Hop Web | `http://localhost:8080` | n/a |
| Superset | `http://localhost:8088` | n/a |

The difference between host ports and container ports is essential.

For example:

```text
DBeaver -> PostgreSQL: localhost:5433
Hop     -> PostgreSQL: postgres:5432
Superset-> PostgreSQL: postgres:5432
```

Inside a container, `localhost` refers to that container itself.

---

# 9. Important first-run rule

MariaDB and PostgreSQL entrypoint initialization scripts run only when their data volumes are first created.

If you already started an older version of this lab using the same volumes and then changed the initialization SQL, the new schema scripts will not automatically rerun.

For a clean lab reset:

```bash
docker compose down -v
```

Then:

```bash
docker compose up -d --build
```

**Warning:** `down -v` deletes the lab database/object-storage volumes. Use it only when you want a clean reset.

A normal stop that keeps data is:

```bash
docker compose down
```

---

# 10. MariaDB source database

MariaDB represents an operational/OLTP source.

Connect with DBeaver:

```text
Database type: MariaDB
Host:          localhost
Port:          3307
Database:      source_db
Username:      labuser
Password:      value from MARIADB_PASSWORD
```

The source contains:

```text
source_db.customers
source_db.products
source_db.orders
source_db.order_items
```

Validate:

```sql
USE source_db;
SHOW TABLES;

SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
```

MariaDB should contain source data only. Do not create the dimensional warehouse there.

---

# 11. PostgreSQL data warehouse

Create a new PostgreSQL connection in DBeaver:

```text
Database type: PostgreSQL
Host:          localhost
Port:          5433
Database:      warehouse
Username:      dw_admin
Password:      value from POSTGRES_PASSWORD
```

Test:

```sql
SELECT current_database();
SELECT current_user;
SELECT version();
```

List warehouse objects:

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('dw','control')
ORDER BY table_schema, table_name;
```

Expected schemas:

```text
dw
control
```

## `dw` schema

```text
dw.dim_date
dw.dim_customer
dw.dim_product
dw.fact_sales
dw.v_sales_detail
```

## `control` schema

```text
control.etl_watermark
control.etl_audit
control.data_quality_rejects
control.v_etl_health
```

Run the included validation file:

```text
scripts/postgres_validation.sql
```

---

# 12. Warehouse security model

There are two PostgreSQL users with intentionally different responsibilities.

## ETL / owner account

```text
User: dw_admin
```

Use this account from Apache Hop for warehouse writes during the lab.

It owns the warehouse objects and can:

```text
INSERT
UPDATE
DELETE
CREATE
ALTER
SELECT
```

## BI read-only account

```text
User: bi_reader
```

Use this account from Superset.

It receives:

```text
CONNECT on warehouse
USAGE on dw and control schemas
SELECT on warehouse/control tables and views
```

This is much better practice than letting your dashboard tool use the ETL administrator account.

Test the read-only account in DBeaver:

```sql
SELECT * FROM dw.dim_product LIMIT 10;
```

Then deliberately confirm that this fails:

```sql
DELETE FROM dw.dim_product WHERE product_id = -99999;
```

Do not grant Superset write privileges just to make setup easier.

---

# 13. Generate synthetic source data

The included generator produces a realistic relational retail dataset.

Generate 100,000 orders:

```bash
python3 scripts/generate_sales_data.py --orders 100000
```

Expected output:

```text
datasets/generated/customers.csv
datasets/generated/products.csv
datasets/generated/orders.csv
datasets/generated/order_items.csv
```

A typical run includes approximately:

```text
12,000 customers
800 products
100,000 orders
200k-400k order items
```

Larger exercises:

```bash
python3 scripts/generate_sales_data.py \
  --orders 500000 \
  --customers 50000 \
  --products 3000 \
  --out datasets/generated_500k
```

Then:

```bash
python3 scripts/generate_sales_data.py \
  --orders 1000000 \
  --customers 100000 \
  --products 5000 \
  --out datasets/generated_1m
```

Do not begin with one million rows. First make correctness, auditability, and reruns work on 100k orders.

---

# 14. Load CSV data into MariaDB

Use DBeaver's Import Data wizard for the first exercise.

Map:

```text
customers.csv   -> source_db.customers
products.csv    -> source_db.products
orders.csv      -> source_db.orders
order_items.csv -> source_db.order_items
```

Why use DBeaver first?

It avoids Windows/WSL file-path confusion and lets you inspect data types and column mappings manually before automating ingestion.

After import, use:

```text
scripts/load_csv_to_mariadb.sql
```

for validation queries.

---

# 15. MinIO data lake

Open:

```text
http://localhost:9001
```

Use credentials from `.env`.

The setup creates:

```text
raw
curated
archive
rejects
```

Recommended logical paths:

```text
raw/
  retail/
    customers/
      ingest_date=YYYY-MM-DD/
    products/
    orders/
    order_items/

curated/
  retail/
    sales/
      year=YYYY/
        month=MM/

archive/
  retail/

rejects/
  retail/
    pipeline=<pipeline-name>/
      ingest_date=YYYY-MM-DD/
```

## Zone rules

### Raw

Treat raw as immutable source history.

Do not silently overwrite it.

### Curated

Contains standardized, validated, typed data ready for analytics or further loading.

### Rejects

Contains records that failed rules, together with enough information to explain why.

### Archive

Contains processed source files if your ingestion pattern moves completed files.

---

# 16. Apache Hop connections

Open:

```text
http://localhost:8080
```

Keep project files under `/files`, which maps to the host `hop-project/` directory.

Create two relational connections.

## Source connection: MariaDB

```text
Name:     lab_source_mariadb
Type:     MariaDB
Host:     mariadb
Port:     3306
Database: source_db
Username: labuser
Password: MARIADB_PASSWORD
```

MariaDB's JDBC driver is not bundled in the standard Hop distribution. Download MariaDB Connector/J and place the jar in the repository `drivers/` directory before testing the MariaDB connection. The Compose services set `HOP_SHARED_JDBC_FOLDERS=/drivers`, so Hop will scan that mounted directory for the driver. See `docs/INSTALLATION_GUIDE.md` for the exact steps.

## Warehouse connection: PostgreSQL

```text
Name:     lab_dw_postgres
Type:     PostgreSQL
Host:     postgres
Port:     5432
Database: warehouse
Username: dw_admin
Password: POSTGRES_PASSWORD
```

PostgreSQL JDBC support is included in the standard Hop distribution, so this is the cleaner of the two database connections.

Test both connections before building pipelines.

---

# 17. Apache Hop MinIO connection

Create a MinIO metadata connection:

```text
Name:              lablake
Access key:        MINIO_ROOT_USER
Secret key:        MINIO_ROOT_PASSWORD
Endpoint hostname: minio
Endpoint port:     9000
Secure:            false
Region:            us-east-1
```

Use logical locations such as:

```text
lablake:///raw/retail/
lablake:///curated/retail/
lablake:///archive/retail/
lablake:///rejects/retail/
```

---

# 18. Project 1 — raw ingestion workflow

Create:

```text
wf_01_raw_ingestion.hwf
```

Create pipelines:

```text
pl_customers_raw.hpl
pl_products_raw.hpl
pl_orders_raw.hpl
pl_order_items_raw.hpl
```

Suggested flow:

```text
CSV / source extract
       |
       v
Validate schema
       |
       +------ invalid ------> MinIO rejects/
       |
       v
Standardize types
       |
       v
Add technical metadata
       |
       v
MinIO raw/curated
       |
       v
Write audit metrics to PostgreSQL control.etl_audit
```

Add technical columns such as:

```text
batch_id
source_system
source_entity
source_filename
ingest_ts
pipeline_name
```

Acceptance criteria:

- every run has a batch ID;
- accepted and rejected counts reconcile;
- rejected rows are retained;
- source files are traceable;
- a rerun does not silently duplicate warehouse data.

---

# 19. Project 2 — load `dw.dim_date`

Build a date dimension from:

```text
2020-01-01
through
2030-12-31
```

Columns:

```text
date_key
full_date
year_num
quarter_num
month_num
month_name
day_num
day_name
is_weekend
```

Use integer date keys:

```text
20260808
```

Target:

```text
dw.dim_date
```

PostgreSQL stores `is_weekend` as a real `BOOLEAN`.

Validation:

```sql
SELECT MIN(full_date), MAX(full_date), COUNT(*)
FROM dw.dim_date;
```

---

# 20. Project 3 — load `dw.dim_product`

Source:

```text
MariaDB source_db.products
```

Target:

```text
PostgreSQL dw.dim_product
```

Calculate:

```text
margin_pct =
(unit_price - unit_cost) / NULLIF(unit_price, 0) * 100
```

Target fields include:

```text
product_key
product_id
product_name
category
unit_cost
current_price
margin_pct
load_ts
```

The table already includes an Unknown Product row using natural key `-1`.

---

# 21. Project 4 — SCD Type 2 customer dimension

Target:

```text
dw.dim_customer
```

Tracked attributes:

```text
customer_name
city
state_code
```

Columns:

```text
customer_key
customer_id
customer_name
city
state_code
effective_from
effective_to
is_current
row_hash
```

## Required SCD2 behavior

For each source customer:

```text
No warehouse record
    -> INSERT current row

Warehouse current row + no tracked change
    -> NO ACTION

Warehouse current row + tracked change
    -> expire current row
    -> INSERT new current version
```

Test:

```sql
UPDATE source_db.customers
SET
  city='Portland',
  state_code='OR',
  updated_at=NOW()
WHERE customer_id=10;
```

Rerun your SCD2 pipeline.

Validate in PostgreSQL:

```sql
SELECT
  customer_key,
  customer_id,
  city,
  state_code,
  effective_from,
  effective_to,
  is_current
FROM dw.dim_customer
WHERE customer_id=10
ORDER BY effective_from;
```

The PostgreSQL warehouse has a filtered unique index that allows only one current version per customer:

```text
customer_id where is_current = true
```

That gives your ETL an extra integrity guard.

---

# 22. Project 5 — fact table

Build:

```text
dw.fact_sales
```

Sources:

```text
source_db.orders
source_db.order_items
source_db.products
```

Lookup surrogate keys from:

```text
dw.dim_date
dw.dim_customer
dw.dim_product
```

Calculations:

```text
gross_sales     = quantity * unit_price
net_sales       = gross_sales - discount_amount
cost_amount     = quantity * unit_cost
profit_amount   = net_sales - cost_amount
profit_margin   = profit_amount / NULLIF(net_sales, 0)
```

Target columns:

```text
sales_key
order_id
order_item_id
date_key
customer_key
product_key
quantity
gross_sales
discount_amount
net_sales
cost_amount
profit_amount
order_status
payment_method
source_updated_at
load_ts
```

Use `order_item_id` as the source uniqueness key.

Unknown/missing dimension lookups should map to the explicit unknown dimension members rather than disappearing from the fact load.

---

# 23. PostgreSQL loading strategies to practice

Start with Hop `Table Output` for correctness.

Then compare it with PostgreSQL-specific bulk loading for large files.

A useful progression is:

```text
1. Row-by-row / batched Table Output
2. Larger commit sizes
3. PostgreSQL Bulk Loader / COPY pattern
4. Staging table + set-based MERGE/UPSERT strategy
```

Measure each approach rather than assuming one is faster.

Record:

```text
row count
elapsed seconds
rows/second
CPU behavior
warehouse table size
```

---

# 24. Project 6 — incremental ETL

The warehouse contains:

```text
control.etl_watermark
```

Initial row:

```sql
SELECT *
FROM control.etl_watermark
WHERE pipeline_name='sales_incremental';
```

The first watermark is:

```text
1900-01-01 00:00:00
```

## Incremental pattern

At pipeline start:

```text
Read last_success_ts from PostgreSQL
```

Extract from MariaDB:

```sql
SELECT *
FROM orders
WHERE updated_at > ?;
```

Repeat the same idea for affected source entities.

After a successful load:

```text
new watermark = maximum successfully processed source updated_at
```

On failure:

```text
DO NOT advance the watermark
```

Update example in PostgreSQL:

```sql
UPDATE control.etl_watermark
SET
  last_success_ts = TIMESTAMP '2026-08-08 12:00:00',
  updated_at = CURRENT_TIMESTAMP
WHERE pipeline_name='sales_incremental';
```

Your Hop workflow should parameterize the timestamp rather than hard-code it.

---

# 25. Simulate source changes / CDC

In MariaDB:

```sql
UPDATE source_db.products
SET
  unit_price = unit_price * 1.05,
  updated_at = NOW()
WHERE product_id BETWEEN 1 AND 25;
```

Then:

```sql
UPDATE source_db.orders
SET
  status='RETURNED',
  updated_at=NOW()
WHERE order_id BETWEEN 100 AND 120;
```

Run the incremental pipeline.

Expected behavior:

```text
Only changed data should be processed.
```

Immediately rerun without new source changes.

Expected behavior:

```text
Approximately zero changed source rows.
```

That tests idempotency and watermark correctness.

---

# 26. Project 7 — ETL audit logging

Use:

```text
control.etl_audit
```

At workflow start, insert:

```text
batch_id
pipeline_name
run_start_ts
status = RUNNING
watermark_before
```

At success, update:

```text
run_end_ts
status = SUCCESS
rows_read
rows_written
rows_rejected
watermark_after
message
```

At failure:

```text
status = FAILED
run_end_ts
message = error summary
```

Do not delete failed audit rows.

They are part of your operational history.

---

# 27. Project 8 — data quality and quarantine

Create bad source data intentionally.

MariaDB examples:

```sql
UPDATE source_db.order_items
SET quantity=-2, updated_at=NOW()
WHERE order_item_id=25;
```

```sql
UPDATE source_db.products
SET unit_price=0, updated_at=NOW()
WHERE product_id=30;
```

Create rules such as:

```text
primary key not null
quantity > 0
unit price >= 0
cost >= 0
order timestamp is reasonable
customer reference resolves
product reference resolves
natural keys are unique
required strings are not blank
```

Bad rows should go to MinIO:

```text
rejects/
```

Also insert reject metadata into:

```text
control.data_quality_rejects
```

Capture:

```text
batch_id
pipeline_name
source_entity
source_key
rule_name
rejection_reason
rejected_at
```

This gives you both:

```text
full rejected payload -> object storage
searchable reject metadata -> PostgreSQL
```

---

# 28. Superset warehouse connection

Open:

```text
http://localhost:8088
```

Sign in with the Superset admin credentials from `.env`.

Go to:

```text
Settings
-> Data
-> Database Connections
-> + Database
```

Create a PostgreSQL connection.

Inside Docker use:

```text
postgres:5432
```

not:

```text
localhost:5433
```

Recommended SQLAlchemy URI:

```text
postgresql+psycopg2://bi_reader:<POSTGRES_BI_PASSWORD>@postgres:5432/warehouse
```

Use the read-only BI user, not `dw_admin`.

The custom Superset Dockerfile installs PostgreSQL support explicitly for reproducibility.

---

# 29. Superset datasets

Register at least these views:

```text
dw.v_sales_detail
control.v_etl_health
```

The sales view already joins the dimensional model into a BI-friendly shape.

Example query:

```sql
SELECT
  month_name,
  SUM(net_sales) AS net_sales,
  SUM(profit_amount) AS profit
FROM dw.v_sales_detail
GROUP BY month_num, month_name
ORDER BY month_num;
```

---

# 30. Dashboard A — Executive Sales

Build KPI cards:

```text
Net Sales
Gross Profit
Order Count
Average Order Value
Profit Margin %
```

Build visualizations:

```text
Monthly revenue trend
Monthly profit trend
Sales by category
Profit by category
Sales by state
Top 20 customers
Top 20 products
Payment method distribution
Returned order trend
Cancelled order trend
```

Filters:

```text
Date
State
Category
Order status
Payment method
```

A good dashboard should answer business questions, not merely show every available column.

---

# 31. Dashboard B — Data Engineering Operations

Use:

```text
control.etl_audit
control.v_etl_health
control.data_quality_rejects
```

Build:

```text
ETL runs by status
Success percentage
Failure count
Rows read
Rows written
Rows rejected
Reject percentage
Average pipeline duration
Latest successful load
Data freshness
Rejects by validation rule
Rejects by source entity
```

This makes observability part of the project rather than an afterthought.

---

# 32. PostgreSQL performance lab

Once the dashboards work, begin warehouse optimization.

Start with a query:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  p.category,
  SUM(f.net_sales) AS net_sales
FROM dw.fact_sales f
JOIN dw.dim_product p
  ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY net_sales DESC;
```

Study:

```text
Seq Scan
Index Scan
Hash Join
Nested Loop
Sort
Aggregate
actual time
rows
buffers
```

Do not add random indexes.

Use a query plan to identify a problem, add/change an index, rerun the same plan, and record the difference.

Useful warehouse experiments:

```text
fact index on date_key
fact index on product_key
multi-column indexes
ANALYZE
VACUUM ANALYZE
materialized views
partitioning by date
COPY vs normal inserts
```

For this lab, indexing and query-plan literacy are more important than trying to imitate Redshift internals.

---

# 33. Optional staging schema exercise

After the basic project works, introduce:

```text
stg
```

Architecture:

```text
MariaDB
  |
  v
PostgreSQL stg
  |
  v
set-based SQL transforms
  |
  v
PostgreSQL dw
```

Example tables:

```text
stg.customers
stg.products
stg.orders
stg.order_items
```

Then practice:

```text
TRUNCATE + reload staging
COPY into staging
MERGE-style logic
set-based dimension loading
transaction boundaries
```

This is a good bridge from ETL-tool-centric development to ELT-style warehouse development.

---

# 34. Optional PostgreSQL partitioning exercise

Do not partition the small fact table immediately.

First scale to at least hundreds of thousands or millions of rows.

Then create an alternate fact table partitioned by date, for example monthly or yearly.

Compare:

```text
unpartitioned query plan
partitioned query plan
load performance
maintenance complexity
```

The learning goal is understanding when partition pruning helps, not checking a box that says “used partitions.”

---

# 35. Jupyter setup

Install useful packages in your existing Python environment:

```bash
python -m pip install \
  pandas \
  pyarrow \
  sqlalchemy \
  pymysql \
  psycopg2-binary \
  boto3 \
  s3fs \
  duckdb \
  matplotlib
```

## Connect to MariaDB source

```python
from sqlalchemy import create_engine

source_engine = create_engine(
    "mysql+pymysql://labuser:YOUR_SOURCE_PASSWORD@localhost:3307/source_db"
)
```

## Connect to PostgreSQL warehouse

```python
warehouse_engine = create_engine(
    "postgresql+psycopg2://dw_admin:YOUR_DW_PASSWORD@localhost:5433/warehouse"
)
```

## Connect to MinIO

```python
import boto3

s3 = boto3.client(
    "s3",
    endpoint_url="http://localhost:9000",
    aws_access_key_id="minioadmin",
    aws_secret_access_key="YOUR_MINIO_PASSWORD",
)

print([b["Name"] for b in s3.list_buckets()["Buckets"]])
```

Expected:

```text
raw
curated
archive
rejects
```

---

# 36. Jupyter reconciliation exercises

Do not use Jupyter only to draw charts.

Use it as an independent validation tool.

Examples:

```text
source order count vs fact order count
source order-item count vs fact row count
source gross sales vs warehouse gross sales
NULL percentages
duplicate natural keys
orphan dimensions
unknown-dimension usage
minimum/maximum dates
latest source updated_at vs warehouse watermark
ETL rejects by rule
```

Example conceptual reconciliation:

```python
import pandas as pd

src = pd.read_sql(
    "SELECT COUNT(*) AS cnt FROM order_items WHERE quantity > 0",
    source_engine,
)

dw = pd.read_sql(
    "SELECT COUNT(*) AS cnt FROM dw.fact_sales",
    warehouse_engine,
)

print(src)
print(dw)
```

The exact counts may differ if your quality rules intentionally reject rows; document the difference rather than forcing counts to match blindly.

---

# 37. Real dataset project — Olist e-commerce

After the synthetic retail project, use a real multi-table e-commerce dataset such as Olist.

Model something like:

```text
                 dim_date
                    |
                    |
dim_customer -- fact_order_items -- dim_product
                    |
                    |
                dim_seller

fact_payments
fact_reviews
```

Business questions:

```text
Which categories create the most revenue?
Which categories have the worst review scores?
Which sellers have the most late deliveries?
Which states have the longest shipping times?
How much does freight affect purchase value?
Which customers repeat purchase?
Which categories have the highest cancellation/return risk?
```

Add warehouse-specific work:

```text
surrogate keys
SCD2 customer/location history
incremental ingestion
quality checks
indexes
query plans
Superset dashboards
```

---

# 38. Large-file project — Parquet and MinIO

Use a large public dataset such as taxi/trip data after the relational project.

Store detail in MinIO:

```text
raw/
  trips/
    year=YYYY/
      month=MM/
```

Practice:

```text
Parquet
partitioned object paths
schema evolution
large-file processing
predicate filtering
aggregations
incremental files
quality checks
```

A practical architecture is:

```text
MinIO
millions of detailed rows
        |
        v
Apache Hop / DuckDB / Python aggregation
        |
        v
PostgreSQL
summary / dimensional tables
        |
        v
Superset
```

That teaches why data lakes and relational analytical stores can coexist.

---

# 39. GitHub repository practices

Initialize:

```bash
git init
git add .
git commit -m "build local data engineering platform with PostgreSQL warehouse"
git branch -M main
```

Suggested branches:

```text
feature/raw-ingestion
feature/postgres-warehouse
feature/customer-scd2
feature/fact-sales
feature/incremental-etl
feature/data-quality
feature/superset-dashboard
feature/postgres-performance
```

Never commit:

```text
.env
passwords
access keys
huge generated datasets
local database volumes
```

Useful portfolio additions:

```text
architecture diagram
screenshots of Hop pipelines
screenshots of Superset dashboards
sample EXPLAIN ANALYZE before/after tuning
reconciliation notebook
failure/recovery example
README section describing engineering decisions
```

---

# 40. Suggested Hop project structure

As your work grows, organize:

```text
hop-project/
  metadata/
  pipelines/
    01_ingestion/
    02_dimensions/
    03_facts/
    04_incremental/
    05_quality/
  workflows/
  sql/
  config/
```

Suggested names:

```text
wf_01_raw_ingestion.hwf
wf_02_full_warehouse_load.hwf
wf_03_incremental_sales.hwf

pl_extract_customers.hpl
pl_extract_products.hpl
pl_load_dim_date.hpl
pl_load_dim_product.hpl
pl_load_dim_customer_scd2.hpl
pl_load_fact_sales.hpl
pl_write_etl_audit.hpl
pl_write_rejects.hpl
```

Naming becomes important as the number of pipelines grows.

---

# 41. Recommended implementation order

Complete the lab in this sequence:

```text
1. Docker / WSL networking
2. MariaDB source
3. PostgreSQL warehouse
4. MinIO buckets
5. Generate and load synthetic source data
6. Hop MariaDB connection
7. Hop PostgreSQL connection
8. Hop MinIO connection
9. Raw ingestion
10. dim_date
11. dim_product
12. dim_customer SCD2
13. fact_sales
14. ETL audit
15. incremental watermark
16. bad-data/reject flow
17. Superset warehouse connection
18. Executive Sales dashboard
19. Data Engineering Operations dashboard
20. Jupyter reconciliation
21. PostgreSQL EXPLAIN ANALYZE tuning
22. 500k scale test
23. 1M scale test
24. Olist project
25. large Parquet/MinIO project
26. migrate pieces to AWS
```

Do not add Airflow, Kafka, Spark, dbt, and six other technologies before you can explain every component in this architecture and recover it from a failed run.

---

# 42. AWS migration path

## Stage 1 — replace MinIO with S3

```text
MariaDB source
      |
      v
Apache Hop
      |
      v
Amazon S3
      |
      v
PostgreSQL warehouse
```

Practice:

```text
IAM
bucket policies
prefix conventions
encryption
lifecycle rules
```

## Stage 2 — move source to RDS/Aurora

```text
Amazon RDS / Aurora
        |
        v
Hop / Glue
        |
        v
S3
```

Practice:

```text
security groups
subnets
credentials
JDBC connectivity
incremental extraction
```

## Stage 3 — move PostgreSQL warehouse to managed PostgreSQL

Use:

```text
RDS PostgreSQL
or
Aurora PostgreSQL
```

This is the smallest conceptual migration because your SQL model can remain close to the local version.

## Stage 4 — replace ETL portions with AWS Glue

```text
RDS source
   |
   v
Glue
   |
   v
S3
   |
   v
warehouse
```

Compare:

```text
Hop pipeline
vs
Glue job
```

for the same transformation.

## Stage 5 — add Glue Data Catalog and Athena

```text
S3
 |
 v
Glue Catalog
 |
 v
Athena
```

Keep PostgreSQL for curated marts while querying detailed lake files with Athena.

## Stage 6 — move the analytical warehouse to Redshift

Target architecture:

```text
RDS / Aurora
      |
      v
Glue / Hop
      |
      v
S3
      |
      v
Redshift
      |
      v
BI
```

Then compare PostgreSQL concepts with Redshift-specific design:

```text
distribution
sort keys
columnar storage
MPP execution
COPY from S3
warehouse workload management
```

## Stage 7 — orchestration and observability

Introduce as appropriate:

```text
EventBridge
Step Functions
Lambda
CloudWatch
SNS
SQS
Secrets Manager
IAM
Kinesis
```

---

# 43. Tools to add later

Once this platform is comfortable, consider:

```text
Apache Airflow
  orchestration and scheduling

dbt
  SQL transformations and tests

DuckDB
  local analytics directly over files

Kafka / Redpanda
  streaming event ingestion

Spark
  distributed processing

Great Expectations / Soda
  formal data-quality frameworks

Prometheus + Grafana
  infrastructure/operational observability

LocalStack
  selected local AWS API simulations
```

The core project is already large enough to demonstrate real data-engineering ability without these additions.

---

# 44. Troubleshooting

## PostgreSQL does not contain the new tables

If you previously ran an old volume:

```bash
docker compose down -v
docker compose up -d --build
```

Remember that this deletes local lab volumes.

## DBeaver cannot reach PostgreSQL

Check:

```bash
docker compose ps postgres
docker compose logs postgres
```

Use:

```text
Host: localhost
Port: 5433
```

not container port 5432 from the Windows host.

## Hop cannot reach PostgreSQL

Use:

```text
Host: postgres
Port: 5432
```

not `localhost:5433`.

## Superset cannot reach PostgreSQL

Use:

```text
postgresql+psycopg2://bi_reader:PASSWORD@postgres:5432/warehouse
```

The hostname must be `postgres` inside the Docker network.

## Hop cannot connect to MariaDB

PostgreSQL's Hop JDBC driver is bundled, but MariaDB's is not necessarily bundled.

If needed, install a MariaDB JDBC jar using a reproducible custom image or a configured shared JDBC folder. Avoid manually copying files into a running container because that change disappears when the container is rebuilt.

## Port already in use

Current host mappings:

```text
3307 MariaDB
5433 PostgreSQL
8080 Hop Web
8088 Superset
9000 MinIO API
9001 MinIO Console
```

Use:

```powershell
netstat -ano | findstr :5433
```

or in WSL:

```bash
ss -ltnp | grep 5433
```

## Reset only PostgreSQL

If you want to rebuild just the PostgreSQL warehouse volume, inspect your Docker volume names first:

```bash
docker volume ls
```

For a learning lab, the simplest safe documented reset is usually the full:

```bash
docker compose down -v
```

followed by a rebuild.

---

# 45. Completion criteria

You should consider the core project complete only when you can demonstrate all of the following:

```text
MariaDB has operational source data
MinIO has raw/curated/reject zones
PostgreSQL has dimensional warehouse objects
Hop can read MariaDB and write PostgreSQL
Hop can read/write MinIO
SCD2 preserves customer history
fact_sales uses surrogate dimension keys
incremental runs use a watermark
failed runs do not advance the watermark
bad records are quarantined
ETL audit rows explain each run
Superset uses a read-only PostgreSQL account
business dashboard works
engineering operations dashboard works
Jupyter reconciles source and warehouse
EXPLAIN ANALYZE is used to tune at least one query
500k+ row scale test is documented
Git history shows incremental engineering work
```

At that point this is not merely a software installation exercise. It is a portfolio-grade local data engineering project.

---

# 46. First commands summary

```bash
cd ~/projects/aws-data-engineering-local-lab
cp .env.example .env
# edit .env

docker compose pull
docker compose up -d --build
docker compose ps

python3 scripts/generate_sales_data.py --orders 100000
```

Then connect:

```text
MariaDB source:
localhost:3307 / source_db

PostgreSQL warehouse:
localhost:5433 / warehouse

MinIO:
http://localhost:9001

Hop Web:
http://localhost:8080

Superset:
http://localhost:8088
```

Use `docs/LAB_CHECKLIST.md` as your implementation tracker.
