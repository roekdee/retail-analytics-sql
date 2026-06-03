-- 01_month_over_month_growth.sql
-- Month-over-month revenue growth.
-- Demonstrates: LAG() window function to reach the previous row, and a guarded
-- percentage change. Reads from the monthly_revenue view.
SET search_path TO retail, public;

WITH m AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS prev_revenue
    FROM monthly_revenue
)
SELECT
    month,
    revenue,
    prev_revenue,
    (revenue - prev_revenue)                                   AS revenue_delta,
    ROUND(
        100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 1
    )                                                          AS mom_growth_pct
FROM m
ORDER BY month;
