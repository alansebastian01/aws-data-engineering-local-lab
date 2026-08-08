-- Run in DBeaver against localhost:5433 / warehouse.
SELECT current_database(), current_user, version();

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('dw','control')
ORDER BY table_schema, table_name;

SELECT 'dim_date' AS object_name, COUNT(*) AS row_count FROM dw.dim_date
UNION ALL
SELECT 'dim_customer', COUNT(*) FROM dw.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dw.dim_product
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM dw.fact_sales;

SELECT * FROM control.etl_watermark ORDER BY pipeline_name;
SELECT * FROM control.etl_audit ORDER BY audit_id DESC LIMIT 20;
