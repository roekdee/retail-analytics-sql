-- 04_aov_by_segment.sql
-- Average order value (AOV) by customer segment, with each segment's AOV
-- compared against the overall average.
-- Demonstrates: aggregation per group alongside a global window aggregate
-- (AVG ... OVER ()) in the same query, plus an index/ratio against the mean.
SET search_path TO retail, public;

WITH order_totals AS (
    SELECT
        o.order_id,
        c.segment,
        SUM(li.line_revenue) AS order_value
    FROM v_completed_line_items li
    JOIN orders o     ON o.order_id = li.order_id
    JOIN customers c  ON c.customer_id = li.customer_id
    GROUP BY o.order_id, c.segment
),
by_segment AS (
    SELECT
        segment,
        COUNT(*)                       AS orders,
        ROUND(AVG(order_value), 2)     AS segment_aov
    FROM order_totals
    GROUP BY segment
)
SELECT
    segment,
    orders,
    segment_aov,
    ROUND(AVG(segment_aov) OVER (), 2)                          AS overall_aov,
    ROUND(segment_aov / NULLIF(AVG(segment_aov) OVER (), 0), 2) AS aov_vs_overall_index
FROM by_segment
ORDER BY segment_aov DESC;
