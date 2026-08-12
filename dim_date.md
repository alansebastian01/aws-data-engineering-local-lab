Instead of storing a raw date like:

```text
2026-08-11
```

inside every sales row, the warehouse can store a `date_key`:

```text
20260811
```

and then look up all the useful calendar information in `dw.dim_date`.

So one row in `dim_date` might conceptually look like:

```text
date_key      20260811
full_date     2026-08-11
day_name      Tuesday
month_name    August
month_number  8
quarter       3
year          2026
is_weekend    false
```

That means `dim_date` is not really “transaction data.” It is a **reference table describing every calendar day**.

In your screenshot, the pipeline only has **Execute SQL script** because this dimension can be generated entirely inside PostgreSQL. We don't need to read dates from MariaDB one-by-one. PostgreSQL can generate a whole range of calendar dates and calculate the attributes itself.

The flow is basically:

```text
Execute SQL script
       ↓
Generate dates
       ↓
Calculate calendar attributes
       ↓
Insert into dw.dim_date
```

For example, PostgreSQL can generate:

```text
2024-01-01
2024-01-02
2024-01-03
...
2026-08-11
...
```

and for each date determine:

```text
day of week
month
quarter
year
weekend or weekday
```

The reason we created `dim_date` **before `fact_sales`** is that the fact table needs a date reference. Your `fact_sales` rows contain a `date_key`, such as:

```text
20240331
```

and that key corresponds to:

```text
dw.dim_date

date_key = 20240331
full_date = 2024-03-31
```

So later a BI query can ask things like:

```text
Sales by year
Sales by month
Sales by quarter
Weekend vs weekday sales
Sales by day of week
```

without repeatedly calculating those date properties from timestamps.

The easiest mental model is:

```text
dim_date = calendar

dim_product = product dictionary

dim_customer = customer/history dictionary

fact_sales = actual business events
```

And the relationship looks like:

```text
             dim_date
                ↑
                │ date_key
                │
dim_customer ← fact_sales → dim_product
 customer_key             product_key
```

So your little one-box `dim_date` pipeline may **look** much simpler than `fact_sales`, but it plays an important role: it creates the calendar dimension that every sale can point to.

Your lab guide intentionally has `dim_date` first, followed by `dim_product`, `dim_customer`, and then `fact_sales`. 
