
```text
Read Products
      ↓
Select values
      ↓
Clean Product Fields
      ↓
Filter rows
     ↙     ↘
Upsert     Rejected
dim_product Products
```

Here’s the same newcomer/baby-step documentation for rebuilding it.

## `dim_product` Pipeline — Beginner Guide

### What are we building?

The goal is simple:

> Read products from **MariaDB**, clean/check them, then load good products into PostgreSQL `dw.dim_product`.

Bad product rows go down a separate rejection path.

Your guide says `dim_product` is the second core dimension pipeline, before the SCD2 `dim_customer` and `fact_sales`. 

### Step 1 — Create the pipeline

Create a new Hop pipeline and save it as:

```text
/files/pipelines/dim_product.hpl
```

The finished pipeline should look like:

```text
Read Products
      ↓
Select values
      ↓
Clean Product Fields
      ↓
Filter rows
     ↙     ↘
Upsert     Rejected
dim_product Products
```

### Step 2 — `Read Products`

Add a **Table Input** transform.

Name:

```text
Read Products
```

Connection:

```text
lab_source_mariadb
```

This transform reads the product data from:

```text
source_db.products
```

The source `products` table is part of the MariaDB dataset loaded earlier in the lab. 

If you're rebuilding it, first inspect the source:

```sql
SELECT *
FROM source_db.products
LIMIT 20;
```

The idea is simply:

```text
MariaDB products
      ↓
Apache Hop
```

Preview `Read Products` before continuing. Make sure rows appear.

### Step 3 — `Select values`

Add a **Select Values** transform after `Read Products`.

Name:

```text
Select values
```

Connect:

```text
Read Products
      ↓
Select values
```

This transform's job is to keep the fields that belong in your product dimension and remove source fields you don't need.

Your PostgreSQL dimension contains:

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

But some of those are warehouse-generated fields.

The important incoming business fields are:

```text
product_id
product_name
category
unit_cost
current_price
```

You normally **do not create `product_key` here**. That's the warehouse surrogate key.

You also don't need to create `load_ts` if PostgreSQL supplies it automatically.

### Step 4 — `Clean Product Fields`

Next add the cleaning transform shown in your pipeline.

Name:

```text
Clean Product Fields
```

Connect:

```text
Select values
      ↓
Clean Product Fields
```

This step is basically:

> “Make the source product data safe and consistent before loading it.”

For text fields such as:

```text
product_name
category
```

you can clean whitespace/casing as your existing pipeline is configured to do.

For example, conceptually:

```text
"  Electronics  "
        ↓
"Electronics"
```

Don't change your working cleaning configuration just for the sake of changing it.

### Step 5 — `Filter rows`

Add **Filter Rows** after cleaning.

Name:

```text
Filter rows
```

This is the quality gate.

Think:

```text
                    Is this product valid?
                           |
                 ┌─────────┴─────────┐
                YES                  NO
                 ↓                    ↓
          Load product         Reject product
```

At minimum, a valid product should have the fields your dimension requires, especially its business key.

For example, the filter might require:

```text
product_id IS NOT NULL
```

and whatever other quality rules your existing pipeline uses.

### Step 6 — Create the two paths

This is the part shown clearly in your screenshot.

The **green/true** path goes to:

```text
Upsert dim_product
```

The **orange/false** path goes to:

```text
Rejected Products
```

So:

```text
                    Filter rows
                       /    \
                    TRUE    FALSE
                     /        \
                    ↓          ↓
              Upsert       Rejected
            dim_product     Products
```

This is a useful ETL pattern because bad data doesn't silently enter your warehouse.

### Step 7 — `Upsert dim_product`

The good rows go here.

Your PostgreSQL destination is:

```text
Connection: lab_dw_postgres
Schema:     dw
Table:      dim_product
```

Hop reaches PostgreSQL internally using `postgres:5432` through the warehouse connection. 

The important matching/business key is:

```text
product_id
```

Conceptually, an **upsert** means:

```text
Does product_id already exist?

        NO
        ↓
      INSERT

        YES
        ↓
      UPDATE
```

So if product `421` doesn't exist:

```text
INSERT new product 421
```

If product `421` already exists and its attributes changed:

```text
UPDATE product 421
```

Unlike `dim_customer`, we're **not keeping historical product versions here**. That's why `dim_product` is simpler than your SCD2 customer dimension.

### Step 8 — Map the warehouse fields

Your target dimension has:

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

The source-to-target idea is:

```text
Source/Hop           PostgreSQL
------------------------------------
product_id       →   product_id
product_name     →   product_name
category         →   category
unit_cost        →   unit_cost
current_price    →   current_price
margin_pct       →   margin_pct
```

If `margin_pct` is calculated in your cleaning/calculation step, map that calculated field.

Usually you should **not manually supply**:

```text
product_key
load_ts
```

when PostgreSQL is configured to generate/default them.

### Step 9 — `Rejected Products`

The FALSE side of `Filter rows` goes to:

```text
Rejected Products
```

This gives invalid rows somewhere to go instead of loading them into `dim_product`.

Your guide actually places full **data-quality reject routing** later in the project, after the basic fact load and audit logging. 

So at this stage, the important concept is simply:

```text
Good row → warehouse

Bad row → rejection path
```

You can make the reject handling more sophisticated later.

### Step 10 — Run the pipeline

Save first.

Then run `dim_product`.

Watch the Hop counters.

You want:

```text
Read Products
      ↓
Select values
      ↓
Clean Product Fields
      ↓
Filter rows
      ↓
Upsert dim_product
```

to complete without red errors.

### Step 11 — Validate PostgreSQL

In PostgreSQL DBeaver:

```sql
SELECT COUNT(*)
FROM dw.dim_product;
```

Then:

```sql
SELECT
    product_key,
    product_id,
    product_name,
    category,
    unit_cost,
    current_price,
    margin_pct,
    load_ts
FROM dw.dim_product
ORDER BY product_key
LIMIT 20;
```

Make sure actual products appear.

### Step 12 — Check for duplicate products

Because `product_id` is your business key, you don't want the same source product represented multiple times:

```sql
SELECT
    product_id,
    COUNT(*)
FROM dw.dim_product
GROUP BY product_id
HAVING COUNT(*) > 1;
```

Ideally:

```text
0 rows
```

### Step 13 — Check for broken/null keys

```sql
SELECT *
FROM dw.dim_product
WHERE product_key IS NULL
   OR product_id IS NULL;
```

Ideally:

```text
0 rows
```

### Step 14 — Understand the whole thing

The easiest way to remember this pipeline is:

```text
Read Products
      ↓
"What products exist in MariaDB?"

Select values
      ↓
"Which columns do I actually need?"

Clean Product Fields
      ↓
"Make the data clean."

Filter rows
      ↓
"Is this row valid?"

      YES                 NO
       ↓                   ↓
Upsert dim_product    Rejected Products
       ↓
"Put good products
 in PostgreSQL."
```

And that's why later, in your `fact_sales` pipeline, we were able to take:

```text
product_id = 421
```

and look up:

```text
product_key = 424
```

`dim_product` created that warehouse relationship first.

So the big picture is now:

```text
dim_date       ✅
dim_product    ✅
dim_customer   ✅ SCD2
fact_sales     ✅
```

Those are the four core warehouse pipelines your guide tells you to build first. 
