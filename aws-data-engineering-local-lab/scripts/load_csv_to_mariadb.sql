-- Run from DBeaver after importing the generated CSV files with its Import Data wizard.
-- This file contains validation queries rather than LOAD DATA because host paths vary on Windows/WSL.
USE source_db;
SELECT 'customers' table_name, COUNT(*) row_count FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

SELECT MIN(order_ts) min_order_ts, MAX(order_ts) max_order_ts, COUNT(*) orders FROM orders;
SELECT status, COUNT(*) FROM orders GROUP BY status ORDER BY 2 DESC;
