
Your pipeline is:

```text
Read Customers
      ↓
Select Customer Fields
      ↓
Dimension Lookup/Update
```

The important thing is that `dim_customer` is **SCD Type 2**, meaning:

> When a customer's information changes, we keep the old information AND create a new version.

### 1. `Read Customers` — get the customers

The first box reads customer data from the MariaDB source database.

Think:

```text
MariaDB
source_db.customers
        ↓
Read Customers
```

A source customer might look like:

```text
customer_id:   1
customer_name: Mateo Johnson
city:          Seattle
state_code:    WA
```

So this transform basically says:

> "MariaDB, give me the customer records."

Nothing fancy yet.

### 2. `Select Customer Fields` — keep what we need

The next box receives all those customer records.

Its job is basically:

> "From the customer data I received, which fields do I actually want to send into my warehouse dimension?"

For our dimension, the important business fields are things like:

```text
customer_id
customer_name
city
state_code
```

So conceptually:

```text
Read Customers
      ↓
lots of source information
      ↓
Select Customer Fields
      ↓
only the fields we care about
```

This is also a convenient place to rename fields or clean up metadata if necessary.

### 3. `Dimension Lookup/Update` — the important box

This is where the SCD Type 2 magic happens.

Hop receives a customer, for example:

```text
customer_id = 1
Mateo Johnson
Seattle
WA
```

Then it looks inside PostgreSQL:

```text
dw.dim_customer
```

and asks:

> "Do I already know customer 1?"

There are three basic possibilities.

### Situation A — brand-new customer

Suppose MariaDB has:

```text
customer_id = 500
John Smith
San Diego
CA
```

but customer 500 doesn't exist in PostgreSQL.

Hop says:

> "New customer! I'll insert him."

PostgreSQL gets something conceptually like:

```text
customer_key:    501
customer_id:     500
customer_name:   John Smith
city:            San Diego
state_code:      CA
version_number:  1
is_current:      true
```

The important distinction is:

```text
customer_id
```

comes from the source system.

But:

```text
customer_key
```

is the warehouse's own surrogate key.

That's why we configured Hop to let PostgreSQL automatically generate `customer_key`.

---

### Situation B — existing customer, nothing changed

Suppose Hop reads:

```text
Mateo Johnson
Seattle
WA
```

and PostgreSQL already contains:

```text
Mateo Johnson
Seattle
WA
```

Hop compares them and basically says:

> "Same person. Same information. Nothing to do."

No new row.

That's exactly what we tested when your count stayed:

```text
12001
```

after running the pipeline again.

That's important because otherwise every pipeline run would duplicate every customer.

---

### Situation C — existing customer changed

This is the fun one.

Originally PostgreSQL had:

```text
Mateo Johnson
Seattle
WA
```

Then you changed Mateo's source information to:

```text
Mateo Johnson
San Jose
CA
```

Hop saw:

> "Customer 1 already exists... but his information changed."

With SCD Type 2, we **do not overwrite Seattle**.

Instead, Hop closes the old version.

You actually got:

```text
customer_key:   5
customer_id:    1
city:           Seattle
state_code:     WA
version_number: 1
is_current:     false
```

Then Hop created a brand-new row:

```text
customer_key:   12006
customer_id:    1
city:           San Jose
state_code:     CA
version_number: 2
is_current:     true
```

So PostgreSQL remembers both:

```text
Mateo
│
├── Version 1 → Seattle, WA  → OLD
│
└── Version 2 → San Jose, CA → CURRENT
```

That's **Slowly Changing Dimension Type 2**.

### What are `effective_from` and `effective_to`?

These tell us **when each version was valid**.

Your actual test produced approximately:

```text
Version 1
Seattle, WA
1900-01-01
      ↓
2026-08-11 22:01:59
```

Then:

```text
Version 2
San Jose, CA
2026-08-11 22:01:59
      ↓
2199-12-31
```

Think of `2199-12-31` as:

> "This version is still active."

So:

```text
effective_from = when this version became valid
effective_to   = when this version stopped being valid
```

### What does `is_current` mean?

Super simple:

```text
false = old historical version
true  = current version
```

For Mateo:

```text
Seattle   → false
San Jose  → true
```

That gives us an easy query for all current customers:

```sql
SELECT *
FROM dw.dim_customer
WHERE is_current = true;
```

### What does `version_number` mean?

It simply counts the versions of that customer:

```text
Customer 1

Seattle       → version 1
San Jose      → version 2
Future move   → version 3
Another move  → version 4
```

### Why do we even want the old information?

Imagine Mateo bought something while he lived in Seattle.

Later he moves to San Jose.

If we simply overwrite:

```text
Seattle → San Jose
```

our historical reporting could make it look like Mateo was in San Jose when he made the old purchase.

SCD2 allows the warehouse to understand:

```text
Old sale
   ↓
Mateo version 1
Seattle
```

while newer sales can point to:

```text
New sale
   ↓
Mateo version 2
San Jose
```

That's also why, when we built your `fact_sales` pipeline, we looked up the customer using both `customer_id` **and the order timestamp**.

### The whole pipeline in baby language

You can explain your three boxes like this:

```text
1. Read Customers
   ↓
"Get customers from MariaDB."


2. Select Customer Fields
   ↓
"Keep the customer information I need."


3. Dimension Lookup/Update
   ↓
"Check PostgreSQL."

   Is customer new?
        ↓
      INSERT

   Customer exists and didn't change?
        ↓
     DO NOTHING

   Customer exists but changed?
        ↓
   CLOSE OLD VERSION
        +
   CREATE NEW VERSION
```

And the shortest explanation you could give someone is:

> **My `dim_customer` pipeline reads customers from MariaDB, selects the fields needed by the warehouse, and uses Hop's Dimension Lookup/Update transform to implement SCD Type 2. New customers are inserted, unchanged customers are left alone, and changed customers get a new version while the previous version is preserved as history.**

That's the core idea of your entire `dim_customer` pipeline.
