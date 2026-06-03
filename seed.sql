-- seed.sql
-- Deterministic sample data: 12 customers, 16 products across 5 categories,
-- and orders spread across Jan-Jun 2025 so the time-series views have something to chew on.
-- IDs are referenced explicitly via natural keys (email / sku) to stay insert-order independent.

SET search_path TO retail, public;

-- ---------- Customers ----------
INSERT INTO customers (full_name, email, country, segment, signup_date) VALUES
    ('Alice Nguyen',    'alice@example.com',   'US', 'consumer',   '2024-09-01'),
    ('Bruno Costa',     'bruno@example.com',   'BR', 'consumer',   '2024-10-12'),
    ('Chen Wei',        'chen@example.com',    'CN', 'business',   '2024-11-03'),
    ('Dara Singh',      'dara@example.com',    'IN', 'consumer',   '2024-11-20'),
    ('Elena Rossi',     'elena@example.com',   'IT', 'business',   '2024-12-05'),
    ('Farid Hassan',    'farid@example.com',   'EG', 'consumer',   '2025-01-08'),
    ('Grace Kim',       'grace@example.com',   'KR', 'enterprise', '2025-01-15'),
    ('Hiro Tanaka',     'hiro@example.com',    'JP', 'business',   '2025-02-01'),
    ('Ines Garcia',     'ines@example.com',    'ES', 'consumer',   '2025-02-18'),
    ('Jamal Okoye',     'jamal@example.com',   'NG', 'consumer',   '2025-03-02'),
    ('Klara Novak',     'klara@example.com',   'CZ', 'enterprise', '2025-03-22'),
    ('Liam Murphy',     'liam@example.com',    'IE', 'consumer',   '2025-04-10');

-- ---------- Products ----------
INSERT INTO products (sku, product_name, category, unit_price) VALUES
    ('ELEC-001', 'Wireless Mouse',        'Electronics', 24.99),
    ('ELEC-002', 'Mechanical Keyboard',   'Electronics', 89.00),
    ('ELEC-003', '27" Monitor',           'Electronics', 219.00),
    ('ELEC-004', 'USB-C Hub',             'Electronics', 39.50),
    ('HOME-001', 'Ceramic Mug Set',       'Home',        18.00),
    ('HOME-002', 'LED Desk Lamp',         'Home',        32.75),
    ('HOME-003', 'Throw Blanket',         'Home',        45.00),
    ('BOOK-001', 'SQL Antipatterns',      'Books',       34.99),
    ('BOOK-002', 'Designing Data Apps',   'Books',       49.99),
    ('BOOK-003', 'The Pragmatic Coder',   'Books',       42.00),
    ('APRL-001', 'Cotton T-Shirt',        'Apparel',     19.99),
    ('APRL-002', 'Hooded Sweatshirt',     'Apparel',     54.00),
    ('APRL-003', 'Running Socks 3pk',     'Apparel',     14.50),
    ('SPRT-001', 'Yoga Mat',              'Sports',      29.99),
    ('SPRT-002', 'Insulated Bottle',      'Sports',      27.00),
    ('SPRT-003', 'Resistance Bands',      'Sports',      21.50);

-- ---------- Orders + Items ----------
-- Helper inserts use subselects so the file is robust to identity sequencing.
-- Pattern: insert order header, then its line items keyed off the freshly-created order.

-- A small helper function keeps the seed readable; dropped at the end.
CREATE OR REPLACE FUNCTION _seed_order(
    p_email TEXT, p_date DATE, p_status TEXT,
    p_items JSONB  -- array of {sku, qty} objects; price snapshotted from products
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_order_id BIGINT;
    v_item     JSONB;
BEGIN
    INSERT INTO orders (customer_id, order_date, status)
    SELECT customer_id, p_date, p_status FROM customers WHERE email = p_email
    RETURNING order_id INTO v_order_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        SELECT v_order_id, p.product_id, (v_item->>'qty')::INT, p.unit_price
        FROM products p
        WHERE p.sku = (v_item->>'sku');
    END LOOP;
END;
$$;

-- January
SELECT _seed_order('alice@example.com', '2025-01-05', 'completed', '[{"sku":"ELEC-001","qty":2},{"sku":"ELEC-004","qty":1}]');
SELECT _seed_order('bruno@example.com', '2025-01-09', 'completed', '[{"sku":"BOOK-001","qty":1},{"sku":"BOOK-003","qty":1}]');
SELECT _seed_order('chen@example.com',  '2025-01-15', 'completed', '[{"sku":"ELEC-003","qty":3}]');
SELECT _seed_order('dara@example.com',  '2025-01-22', 'cancelled', '[{"sku":"HOME-002","qty":1}]');
SELECT _seed_order('elena@example.com', '2025-01-28', 'completed', '[{"sku":"APRL-002","qty":2},{"sku":"APRL-003","qty":3}]');

-- February
SELECT _seed_order('alice@example.com', '2025-02-03', 'completed', '[{"sku":"HOME-001","qty":1},{"sku":"HOME-003","qty":1}]');
SELECT _seed_order('farid@example.com', '2025-02-07', 'completed', '[{"sku":"SPRT-001","qty":1},{"sku":"SPRT-002","qty":2}]');
SELECT _seed_order('grace@example.com', '2025-02-14', 'completed', '[{"sku":"ELEC-002","qty":5},{"sku":"ELEC-001","qty":5}]');
SELECT _seed_order('chen@example.com',  '2025-02-19', 'completed', '[{"sku":"ELEC-004","qty":4}]');
SELECT _seed_order('hiro@example.com',  '2025-02-25', 'returned',  '[{"sku":"BOOK-002","qty":1}]');

-- March
SELECT _seed_order('bruno@example.com', '2025-03-04', 'completed', '[{"sku":"BOOK-002","qty":1},{"sku":"BOOK-001","qty":1}]');
SELECT _seed_order('ines@example.com',  '2025-03-11', 'completed', '[{"sku":"APRL-001","qty":3}]');
SELECT _seed_order('grace@example.com', '2025-03-18', 'completed', '[{"sku":"ELEC-003","qty":4},{"sku":"ELEC-002","qty":2}]');
SELECT _seed_order('jamal@example.com', '2025-03-23', 'completed', '[{"sku":"SPRT-003","qty":2},{"sku":"SPRT-001","qty":1}]');
SELECT _seed_order('klara@example.com', '2025-03-29', 'completed', '[{"sku":"HOME-002","qty":3},{"sku":"HOME-003","qty":2}]');

-- April
SELECT _seed_order('alice@example.com', '2025-04-02', 'completed', '[{"sku":"ELEC-002","qty":1}]');
SELECT _seed_order('farid@example.com', '2025-04-08', 'pending',   '[{"sku":"SPRT-002","qty":1}]');
SELECT _seed_order('chen@example.com',  '2025-04-14', 'completed', '[{"sku":"ELEC-001","qty":10}]');
SELECT _seed_order('liam@example.com',  '2025-04-19', 'completed', '[{"sku":"BOOK-003","qty":1},{"sku":"HOME-001","qty":2}]');
SELECT _seed_order('elena@example.com', '2025-04-26', 'completed', '[{"sku":"APRL-002","qty":1},{"sku":"APRL-001","qty":2}]');

-- May
SELECT _seed_order('grace@example.com', '2025-05-05', 'completed', '[{"sku":"ELEC-003","qty":6}]');
SELECT _seed_order('ines@example.com',  '2025-05-12', 'completed', '[{"sku":"APRL-003","qty":4},{"sku":"SPRT-003","qty":1}]');
SELECT _seed_order('bruno@example.com', '2025-05-17', 'completed', '[{"sku":"BOOK-001","qty":1}]');
SELECT _seed_order('klara@example.com', '2025-05-23', 'completed', '[{"sku":"ELEC-004","qty":5},{"sku":"ELEC-002","qty":3}]');
SELECT _seed_order('jamal@example.com', '2025-05-30', 'completed', '[{"sku":"HOME-003","qty":1}]');

-- June
SELECT _seed_order('alice@example.com', '2025-06-03', 'completed', '[{"sku":"SPRT-001","qty":1},{"sku":"SPRT-002","qty":1}]');
SELECT _seed_order('chen@example.com',  '2025-06-09', 'completed', '[{"sku":"ELEC-003","qty":2},{"sku":"ELEC-004","qty":2}]');
SELECT _seed_order('grace@example.com', '2025-06-15', 'completed', '[{"sku":"ELEC-001","qty":8},{"sku":"ELEC-002","qty":4}]');
SELECT _seed_order('liam@example.com',  '2025-06-20', 'completed', '[{"sku":"BOOK-002","qty":1}]');
SELECT _seed_order('hiro@example.com',  '2025-06-27', 'completed', '[{"sku":"HOME-001","qty":2},{"sku":"HOME-002","qty":1}]');

DROP FUNCTION _seed_order(TEXT, DATE, TEXT, JSONB);
