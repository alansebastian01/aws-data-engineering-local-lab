# Data Engineering Lab Checklist — PostgreSQL Warehouse Edition

## Foundation
- [ ] Docker Desktop uses WSL 2 backend
- [ ] `docker version` and `docker compose version` work
- [ ] `.env` created from `.env.example` with all passwords changed
- [ ] `docker compose config` renders without errors
- [ ] `docker compose up -d --build` completes
- [ ] All core containers show healthy/running

## Connectivity
- [ ] MariaDB source reachable in DBeaver at `localhost:3307/source_db`
- [ ] PostgreSQL warehouse reachable at `localhost:5433/warehouse`
- [ ] MinIO Console reachable at `http://localhost:9001`
- [ ] Hop Web reachable at `http://localhost:8080`
- [ ] Superset reachable at `http://localhost:8088`
- [ ] MinIO buckets `raw`, `curated`, `archive`, `rejects` exist

## Source and warehouse
- [ ] Synthetic retail CSV files generated
- [ ] CSVs loaded into MariaDB `source_db`
- [ ] PostgreSQL schemas `dw` and `control` exist
- [ ] Warehouse tables and views exist
- [ ] `bi_reader` can SELECT but cannot INSERT/UPDATE warehouse tables

## Apache Hop
- [ ] Hop connection `lab_source_mariadb` works
- [ ] Hop connection `lab_dw_postgres` works
- [ ] Hop MinIO connection `lablake` works
- [ ] Raw ingestion workflow built
- [ ] `dim_date` load built
- [ ] `dim_product` load built
- [ ] SCD Type 2 `dim_customer` pipeline built
- [ ] `fact_sales` load built
- [ ] Incremental watermark pipeline built
- [ ] Reject/error path built
- [ ] ETL audit logging built
- [ ] Failed run does not advance watermark
- [ ] Rerun is idempotent

## Superset
- [ ] Superset connects with PostgreSQL read-only BI account
- [ ] `dw.v_sales_detail` registered as a dataset
- [ ] `control.v_etl_health` registered as a dataset
- [ ] Executive Sales dashboard built
- [ ] Operations/Data Quality dashboard built

## Advanced practice
- [ ] 500k-order scale test completed
- [ ] 1M-order scale test completed
- [ ] PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` used on dashboard queries
- [ ] Useful indexes added based on query plans rather than guesswork
- [ ] Olist dataset pipeline completed
- [ ] Large Parquet/MinIO exercise completed
- [ ] Git repository initialized and first release tagged
- [ ] Architecture diagram and screenshots added to portfolio README
