Yes. Since you now have a working `fact_sales` pipeline, I can give you a clean **newcomer version** that explains what each box does and exactly how to rebuild it from scratch.

Your lab guide says the build order is `dim_date` → `dim_product` → `dim_customer` as SCD Type 2 → `fact_sales`, so this pipeline is the fourth core warehouse step. 

For a beginner, think of the pipeline like this:

```text
MariaDB sales data
      ↓
Calculate sales money
      ↓
Find warehouse product key
      ↓
Find correct historical customer key
      ↓
Find product cost
      ↓
Calculate cost + profit
      ↓
Write everything into PostgreSQL fact_sales
```

Here are the complete baby steps.

1. Create a new Hop pipeline and save it as:

```text
/files/pipelines/fact_sales.hpl
```

2. Add a **Table Input** transform and call it:

```text
Read Sales
```

Use the MariaDB connection:

```text
lab_source_mariadb
```

Use this SQL:

```sql
SELECT
    o.order_id,
    oi.order_item_id,
    o.customer_id,
    CAST(oi.product_id AS SIGNED) AS product_id,
    o.order_ts,
    CAST(DATE_FORMAT(o.order_ts, '%Y%m%d') AS UNSIGNED) AS date_key,
    o.status,
    o.payment_method,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount
FROM source_db.orders o
INNER JOIN source_db.order_items oi
    ON o.order_id = oi.order_id;
```

This gives you one row per order item. That is the grain of the fact table.

Preview it. You should see fields like:

```text
order_id
order_item_id
customer_id
product_id
order_ts
date_key
status
payment_method
quantity
unit_price
discount_amount
```

3. Add a **Calculator** after `Read Sales`.

Call it:

```text
Calculate Sales Amounts
```

Add:

```text
gross_sales = quantity * unit_price
```

and:

```text
net_sales = gross_sales - discount_amount
```

Preview it and make sure `gross_sales` and `net_sales` have numbers.

4. Add a **Database Join** after that.

Call it:

```text
Get Product Key
```

Use:

```text
Connection: lab_dw_postgres
```

SQL:

```sql
SELECT product_key
FROM dw.dim_product
WHERE product_id = ?;
```

Parameter:

```text
product_id
```

This changes a source `product_id` into the warehouse surrogate `product_key`.

Preview it. `product_key` should not be null.

5. Add another **Database Join**.

Call it:

```text
Get Customer Key
```

Use:

```text
Connection: lab_dw_postgres
```

SQL:

```sql
SELECT customer_key
FROM dw.dim_customer
WHERE customer_id = ?
  AND ? >= effective_from
  AND ? < effective_to;
```

Parameters, in this exact order:

```text
customer_id
order_ts
order_ts
```

This is the important SCD2 part.

It means:

> Find the customer version that was valid when the order happened.

That way an old sale keeps pointing to the old historical customer version.

6. Add another **Database Join**.

Call it:

```text
Get Product Cost
```

SQL:

```sql
SELECT unit_cost
FROM dw.dim_product
WHERE product_key = ?;
```

Parameter:

```text
product_key
```

Preview it and make sure `unit_cost` appears.

7. Add another **Calculator**.

Call it:

```text
Calculate Cost and Profit
```

Add:

```text
cost_amount = quantity * unit_cost
```

Then:

```text
profit_amount = net_sales - cost_amount
```

Preview it and confirm both are numbers.

8. Add a **Table Output** transform.

Call it:

```text
Write Fact Sales
```

Use:

```text
Connection: lab_dw_postgres
Schema:     dw
Table:      fact_sales
```

Map these fields:

```text
PostgreSQL field    Hop stream field
------------------------------------
order_id            order_id
order_item_id       order_item_id
date_key            date_key
customer_key        customer_key
product_key         product_key
quantity            quantity
gross_sales         gross_sales
discount_amount     discount_amount
net_sales           net_sales
cost_amount         cost_amount
profit_amount       profit_amount
order_status        status
payment_method      payment_method
```

Do not map:

```text
sales_key
load_ts
```

because PostgreSQL handles those automatically.

And do not map these source/helper fields:

```text
customer_id
product_id
order_ts
unit_price
unit_cost
```

They help build the fact row, but they are not stored directly in the final fact table.

Your final canvas should look like this:

```text
Read Sales
    ↓
Calculate Sales Amounts
    ↓
Get Product Key
    ↓
Get Customer Key
    ↓
Get Product Cost
    ↓
Calculate Cost and Profit
    ↓
Write Fact Sales
```

Then run it once.

After the run, validate in PostgreSQL:

```sql
SELECT COUNT(*)
FROM dw.fact_sales;
```

And compare it to MariaDB:

```sql
SELECT COUNT(*)
FROM source_db.order_items;
```

For your current dataset, both came out to:

```text
249417
```

That means one fact row was loaded for every source order item.

Finally, verify no duplicates:

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_item_id) AS unique_order_items,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicates
FROM dw.fact_sales;
```

And verify no missing dimension keys:

```sql
SELECT
    COUNT(*) FILTER (WHERE date_key IS NULL) AS missing_dates,
    COUNT(*) FILTER (WHERE customer_key IS NULL) AS missing_customers,
    COUNT(*) FILTER (WHERE product_key IS NULL) AS missing_products
FROM dw.fact_sales;
```

If duplicates are `0` and all missing-key counts are `0`, the basic `fact_sales` pipeline is validated.

One caution: don’t casually rerun the full-load pipeline again until you add incremental/idempotent logic, because the guide places watermark/incremental loading later in the project. 
