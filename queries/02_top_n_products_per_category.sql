-- 02_top_n_products_per_category.sql
-- Top 2 products by revenue within each category.
-- Demonstrates: ROW_NUMBER() partitioned by category to rank inside groups,
-- then filtering the ranked set in an outer query (can't filter window fns in WHERE).
SET search_path TO retail, public;

WITH ranked AS (
    SELECT
        category,
        product_name,
        revenue,
        units_sold,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rn
    FROM product_performance
)
SELECT
    category,
    product_name,
    revenue,
    units_sold,
    rn AS rank_in_category
FROM ranked
WHERE rn <= 2
ORDER BY category, rn;
