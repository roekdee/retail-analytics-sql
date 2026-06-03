-- views.sql
-- Analytical views built on the core schema. Only revenue-bearing orders
-- (status = 'completed') count toward money; the rest are excluded explicitly.

SET search_path TO retail, public;

-- A reusable base: every line item of a completed order, with line revenue.
-- Centralising the "what counts as revenue" rule here avoids drift across views.
CREATE OR REPLACE VIEW v_completed_line_items AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price)::NUMERIC(12,2) AS line_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'completed';

-- monthly_revenue: revenue, order count and AOV bucketed by calendar month.
CREATE OR REPLACE VIEW monthly_revenue AS
SELECT
    date_trunc('month', order_date)::DATE       AS month,
    COUNT(DISTINCT order_id)                     AS order_count,
    SUM(line_revenue)                            AS revenue,
    ROUND(SUM(line_revenue) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_order_value
FROM v_completed_line_items
GROUP BY 1
ORDER BY 1;

-- top_customers: lifetime spend, order count and average order value per customer.
-- Ranked so the "top" is just a LIMIT away.
CREATE OR REPLACE VIEW top_customers AS
SELECT
    c.customer_id,
    c.full_name,
    c.segment,
    COUNT(DISTINCT li.order_id)                  AS lifetime_orders,
    COALESCE(SUM(li.line_revenue), 0)            AS lifetime_spend,
    ROUND(COALESCE(SUM(li.line_revenue), 0)
          / NULLIF(COUNT(DISTINCT li.order_id), 0), 2) AS avg_order_value,
    RANK() OVER (ORDER BY COALESCE(SUM(li.line_revenue), 0) DESC) AS spend_rank
FROM customers c
LEFT JOIN v_completed_line_items li ON li.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.segment
ORDER BY lifetime_spend DESC;

-- product_performance: units sold, revenue and order reach per product,
-- plus that product's revenue share within its category (window over category).
CREATE OR REPLACE VIEW product_performance AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    COALESCE(SUM(li.quantity), 0)                AS units_sold,
    COALESCE(SUM(li.line_revenue), 0)            AS revenue,
    COUNT(DISTINCT li.order_id)                  AS orders_with_product,
    ROUND(
        100.0 * COALESCE(SUM(li.line_revenue), 0)
        / NULLIF(SUM(SUM(li.line_revenue)) OVER (PARTITION BY p.category), 0), 2
    )                                            AS pct_of_category_revenue
FROM products p
LEFT JOIN v_completed_line_items li ON li.product_id = p.product_id
GROUP BY p.product_id, p.sku, p.product_name, p.category
ORDER BY revenue DESC;

-- customer_rfm: classic RFM segmentation.
--   Recency   = days since the customer's last completed order (lower is better).
--   Frequency = number of completed orders.
--   Monetary  = lifetime completed spend.
-- Each dimension is scored 1..4 with NTILE quartiles, then combined into a label.
-- The "as-of" date is the latest order date in the data, so the model is reproducible.
CREATE OR REPLACE VIEW customer_rfm AS
WITH bounds AS (
    SELECT MAX(order_date) AS as_of_date FROM v_completed_line_items
),
per_customer AS (
    SELECT
        li.customer_id,
        (SELECT as_of_date FROM bounds) - MAX(li.order_date) AS recency_days,
        COUNT(DISTINCT li.order_id)                          AS frequency,
        SUM(li.line_revenue)                                 AS monetary
    FROM v_completed_line_items li
    GROUP BY li.customer_id
),
scored AS (
    SELECT
        pc.*,
        -- Recency: fewer days => higher score, so order ascending.
        NTILE(4) OVER (ORDER BY recency_days ASC)  AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC)      AS m_score
    FROM per_customer pc
)
SELECT
    c.customer_id,
    c.full_name,
    c.segment,
    s.recency_days,
    s.frequency,
    s.monetary,
    s.r_score,
    s.f_score,
    s.m_score,
    (s.r_score::TEXT || s.f_score::TEXT || s.m_score::TEXT) AS rfm_cell,
    CASE
        WHEN s.r_score >= 3 AND s.f_score >= 3 AND s.m_score >= 3 THEN 'Champions'
        WHEN s.r_score >= 3 AND s.f_score >= 2                    THEN 'Loyal'
        WHEN s.r_score >= 3                                        THEN 'Recent'
        WHEN s.r_score = 2                                         THEN 'At Risk'
        ELSE 'Lost'
    END AS rfm_label
FROM scored s
JOIN customers c ON c.customer_id = s.customer_id
ORDER BY s.monetary DESC;
