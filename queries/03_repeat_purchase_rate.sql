-- 03_repeat_purchase_rate.sql
-- Repeat-purchase rate: share of customers with more than one completed order.
-- Demonstrates: CTE aggregation + FILTER clause for conditional counts, and
-- computing a ratio in a single pass without a self-join.
SET search_path TO retail, public;

WITH per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
    FROM v_completed_line_items
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                              AS purchasing_customers,
    COUNT(*) FILTER (WHERE order_count > 1)               AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE order_count > 1) / NULLIF(COUNT(*), 0), 1
    )                                                     AS repeat_purchase_rate_pct
FROM per_customer;
