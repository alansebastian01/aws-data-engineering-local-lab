USE source_db;

CREATE TABLE IF NOT EXISTS customers (
  customer_id BIGINT PRIMARY KEY,
  customer_name VARCHAR(120) NOT NULL,
  email VARCHAR(160),
  city VARCHAR(80),
  state_code VARCHAR(20),
  signup_date DATE NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_customers_updated (updated_at)
);

CREATE TABLE IF NOT EXISTS products (
  product_id BIGINT PRIMARY KEY,
  product_name VARCHAR(160) NOT NULL,
  category VARCHAR(80) NOT NULL,
  unit_cost DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_products_updated (updated_at)
);

CREATE TABLE IF NOT EXISTS orders (
  order_id BIGINT PRIMARY KEY,
  customer_id BIGINT NOT NULL,
  order_ts DATETIME(6) NOT NULL,
  status VARCHAR(30) NOT NULL,
  payment_method VARCHAR(30),
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_orders_customer (customer_id),
  INDEX idx_orders_updated (updated_at)
);

CREATE TABLE IF NOT EXISTS order_items (
  order_item_id BIGINT PRIMARY KEY,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_items_order (order_id),
  INDEX idx_items_product (product_id),
  INDEX idx_items_updated (updated_at)
);
