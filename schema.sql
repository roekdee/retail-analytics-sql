-- schema.sql
-- Retail analytics database schema (PostgreSQL 16).
-- Everything lives in a dedicated `retail` schema so the public schema stays clean.
-- Run order: schema.sql -> seed.sql -> views.sql -> queries/*.sql -> tests/run.sql

DROP SCHEMA IF EXISTS retail CASCADE;
CREATE SCHEMA retail;
SET search_path TO retail, public;

-- Customers: one row per account, with the marketing segment they belong to.
CREATE TABLE customers (
    customer_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name     TEXT        NOT NULL,
    email         TEXT        NOT NULL UNIQUE,
    country       TEXT        NOT NULL,
    segment       TEXT        NOT NULL DEFAULT 'consumer'
                      CHECK (segment IN ('consumer', 'business', 'enterprise')),
    signup_date   DATE        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Products: catalog with category and the current list price.
CREATE TABLE products (
    product_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku           TEXT        NOT NULL UNIQUE,
    product_name  TEXT        NOT NULL,
    category      TEXT        NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Orders: the header of a purchase. Status drives which orders count as revenue.
CREATE TABLE orders (
    order_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   BIGINT      NOT NULL REFERENCES customers(customer_id),
    order_date    DATE        NOT NULL,
    status        TEXT        NOT NULL DEFAULT 'completed'
                      CHECK (status IN ('completed', 'pending', 'cancelled', 'returned')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Order items: the line items. order_total revenue is derived from these.
-- A product can appear at most once per order (composite uniqueness via PK pattern + UNIQUE).
CREATE TABLE order_items (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      BIGINT      NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id    BIGINT      NOT NULL REFERENCES products(product_id),
    quantity      INTEGER     NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),  -- price captured at sale time
    UNIQUE (order_id, product_id)
);

-- Indexes that match the analytical access patterns below.
CREATE INDEX idx_orders_customer        ON orders (customer_id);
CREATE INDEX idx_orders_order_date      ON orders (order_date);
CREATE INDEX idx_orders_status          ON orders (status);
CREATE INDEX idx_order_items_order      ON order_items (order_id);
CREATE INDEX idx_order_items_product    ON order_items (product_id);
CREATE INDEX idx_products_category      ON products (category);
CREATE INDEX idx_customers_segment      ON customers (segment);
