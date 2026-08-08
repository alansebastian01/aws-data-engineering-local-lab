BEGIN;

CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS control;

CREATE TABLE IF NOT EXISTS dw.dim_date (
  date_key        integer PRIMARY KEY,
  full_date       date NOT NULL UNIQUE,
  year_num        smallint NOT NULL,
  quarter_num     smallint NOT NULL CHECK (quarter_num BETWEEN 1 AND 4),
  month_num       smallint NOT NULL CHECK (month_num BETWEEN 1 AND 12),
  month_name      varchar(12) NOT NULL,
  day_num         smallint NOT NULL CHECK (day_num BETWEEN 1 AND 31),
  day_name        varchar(12) NOT NULL,
  is_weekend      boolean NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.dim_customer (
  customer_key    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id     bigint NOT NULL,
  customer_name   varchar(120),
  city            varchar(80),
  state_code      varchar(20),
  effective_from  timestamp without time zone NOT NULL,
  effective_to    timestamp without time zone,
  is_current      boolean NOT NULL DEFAULT true,
  row_hash        varchar(64),
  CONSTRAINT uq_dim_customer_version UNIQUE (customer_id, effective_from),
  CONSTRAINT ck_customer_dates CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_customer_current
  ON dw.dim_customer(customer_id)
  WHERE is_current = true;

CREATE INDEX IF NOT EXISTS ix_dim_customer_lookup
  ON dw.dim_customer(customer_id, effective_from, effective_to);

CREATE TABLE IF NOT EXISTS dw.dim_product (
  product_key     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id      bigint NOT NULL UNIQUE,
  product_name    varchar(160),
  category        varchar(80),
  unit_cost       numeric(12,2),
  current_price   numeric(12,2),
  margin_pct      numeric(9,4),
  load_ts         timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dw.fact_sales (
  sales_key        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id         bigint NOT NULL,
  order_item_id    bigint NOT NULL UNIQUE,
  date_key         integer NOT NULL REFERENCES dw.dim_date(date_key),
  customer_key     bigint NOT NULL REFERENCES dw.dim_customer(customer_key),
  product_key      bigint NOT NULL REFERENCES dw.dim_product(product_key),
  quantity         integer NOT NULL CHECK (quantity > 0),
  gross_sales      numeric(14,2) NOT NULL,
  discount_amount  numeric(14,2) NOT NULL DEFAULT 0,
  net_sales        numeric(14,2) NOT NULL,
  cost_amount      numeric(14,2) NOT NULL,
  profit_amount    numeric(14,2) NOT NULL,
  order_status     varchar(30),
  payment_method   varchar(30),
  source_updated_at timestamp without time zone,
  load_ts          timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_fact_sales_date ON dw.fact_sales(date_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_customer ON dw.fact_sales(customer_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product ON dw.fact_sales(product_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_order ON dw.fact_sales(order_id);

CREATE TABLE IF NOT EXISTS control.etl_watermark (
  pipeline_name    varchar(120) PRIMARY KEY,
  last_success_ts  timestamp without time zone NOT NULL,
  updated_at       timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS control.etl_audit (
  audit_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  batch_id          varchar(80),
  pipeline_name     varchar(120) NOT NULL,
  run_start_ts      timestamp without time zone NOT NULL,
  run_end_ts        timestamp without time zone,
  status            varchar(20) NOT NULL,
  rows_read         bigint NOT NULL DEFAULT 0,
  rows_written      bigint NOT NULL DEFAULT 0,
  rows_rejected     bigint NOT NULL DEFAULT 0,
  watermark_before  timestamp without time zone,
  watermark_after   timestamp without time zone,
  message            text,
  CONSTRAINT ck_audit_status CHECK (status IN ('RUNNING','SUCCESS','FAILED','WARNING'))
);

CREATE INDEX IF NOT EXISTS ix_etl_audit_pipeline_start
  ON control.etl_audit(pipeline_name, run_start_ts DESC);

CREATE TABLE IF NOT EXISTS control.data_quality_rejects (
  reject_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  batch_id          varchar(80),
  pipeline_name     varchar(120) NOT NULL,
  source_entity     varchar(80),
  source_key        varchar(160),
  rule_name         varchar(160) NOT NULL,
  rejection_reason  text,
  rejected_at       timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dw.dim_customer
  (customer_id, customer_name, city, state_code, effective_from, effective_to, is_current, row_hash)
SELECT -1, 'Unknown Customer', NULL, NULL, TIMESTAMP '1900-01-01 00:00:00', NULL, true, 'UNKNOWN'
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_customer WHERE customer_id = -1);

INSERT INTO dw.dim_product
  (product_id, product_name, category, unit_cost, current_price, margin_pct)
SELECT -1, 'Unknown Product', 'Unknown', 0, 0, 0
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_product WHERE product_id = -1);

INSERT INTO control.etl_watermark(pipeline_name, last_success_ts)
VALUES ('sales_incremental', TIMESTAMP '1900-01-01 00:00:00')
ON CONFLICT (pipeline_name) DO NOTHING;

CREATE OR REPLACE VIEW dw.v_sales_detail AS
SELECT
  f.sales_key,
  f.order_id,
  f.order_item_id,
  d.full_date,
  d.year_num,
  d.quarter_num,
  d.month_num,
  d.month_name,
  c.customer_id,
  c.customer_name,
  c.city,
  c.state_code,
  p.product_id,
  p.product_name,
  p.category,
  f.quantity,
  f.gross_sales,
  f.discount_amount,
  f.net_sales,
  f.cost_amount,
  f.profit_amount,
  CASE WHEN f.net_sales = 0 THEN NULL
       ELSE ROUND((f.profit_amount / f.net_sales) * 100, 2)
  END AS profit_margin_pct,
  f.order_status,
  f.payment_method,
  f.load_ts
FROM dw.fact_sales f
JOIN dw.dim_date d ON d.date_key = f.date_key
JOIN dw.dim_customer c ON c.customer_key = f.customer_key
JOIN dw.dim_product p ON p.product_key = f.product_key;

CREATE OR REPLACE VIEW control.v_etl_health AS
SELECT
  pipeline_name,
  COUNT(*) AS run_count,
  COUNT(*) FILTER (WHERE status = 'SUCCESS') AS success_count,
  COUNT(*) FILTER (WHERE status = 'FAILED') AS failed_count,
  SUM(rows_read) AS rows_read,
  SUM(rows_written) AS rows_written,
  SUM(rows_rejected) AS rows_rejected,
  MAX(run_end_ts) FILTER (WHERE status = 'SUCCESS') AS last_success_ts,
  ROUND(AVG(EXTRACT(EPOCH FROM (run_end_ts - run_start_ts)))::numeric, 2) AS avg_duration_seconds
FROM control.etl_audit
GROUP BY pipeline_name;

COMMIT;
