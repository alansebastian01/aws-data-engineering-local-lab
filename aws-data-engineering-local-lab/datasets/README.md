# Dataset practice menu

1. **Generated retail (included generator)** — start here. Relational CSVs with 100k orders by default. Increase to 1,000,000 orders when ready.
2. **Olist Brazilian E-Commerce** — ~100k anonymized real orders spread across customers, orders, items, products, payments, reviews, sellers, and geolocation. Excellent for joins, star schemas, delivery KPIs, and SCD exercises.
3. **NYC Taxi / TLC Trip Record data** — large monthly Parquet files. Use it for object storage, partitioning, schema evolution, predicate pushdown, and performance labs.
4. **Superset examples** — the official Superset Docker setup can load example datasets. Use these for visualization-only practice after your ETL stack is working.
5. **Your own GitHub datasets** — keep raw files immutable in `raw/`, write standardized data to `curated/`, and warehouse aggregates in MariaDB.

Suggested MinIO object layout:

```
raw/<dataset>/ingest_date=YYYY-MM-DD/<file>
curated/<dataset>/year=YYYY/month=MM/<file>
archive/<dataset>/<timestamp>/<file>
rejects/<pipeline>/<run_id>/<file>
```
