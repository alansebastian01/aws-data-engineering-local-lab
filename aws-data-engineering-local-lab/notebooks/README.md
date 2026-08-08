# Notebook exercises

Use Jupyter as an independent validation and profiling environment.

Suggested packages:

```bash
python -m pip install pandas pyarrow sqlalchemy pymysql psycopg2-binary boto3 s3fs duckdb matplotlib
```

Use MariaDB (`localhost:3307/source_db`) as the source and PostgreSQL
(`localhost:5433/warehouse`) as the analytical target. Useful notebook topics:

- source/warehouse row-count reconciliation;
- revenue and profit reconciliation;
- duplicate and null profiling;
- watermark/freshness checks;
- rejected-row analysis;
- MinIO object inspection;
- warehouse query performance comparisons.
