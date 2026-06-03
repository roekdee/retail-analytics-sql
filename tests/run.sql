-- tests/run.sql
-- Assertion suite. Each DO block raises an exception (failing the psql run, and
-- therefore CI) if an invariant about the seeded data / views does not hold.
-- Run after schema.sql, seed.sql and views.sql.

SET search_path TO retail, public;

-- 1. Row counts of base tables match the seed.
DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM customers;
    ASSERT n = 12, format('expected 12 customers, got %s', n);

    SELECT COUNT(*) INTO n FROM products;
    ASSERT n = 16, format('expected 16 products, got %s', n);

    SELECT COUNT(*) INTO n FROM orders;
    ASSERT n = 30, format('expected 30 orders, got %s', n);
END $$;

-- 2. monthly_revenue spans exactly the 6 seeded months (Jan-Jun 2025)
--    and every month has positive revenue.
DO $$
DECLARE
    months INT;
    bad    INT;
BEGIN
    SELECT COUNT(*) INTO months FROM monthly_revenue;
    ASSERT months = 6, format('expected 6 months of revenue, got %s', months);

    SELECT COUNT(*) INTO bad FROM monthly_revenue WHERE revenue <= 0;
    ASSERT bad = 0, format('found %s month(s) with non-positive revenue', bad);
END $$;

-- 3. Cancelled / returned / pending orders must NOT contribute revenue:
--    the completed-line-items view must exclude them.
DO $$
DECLARE leaked INT;
BEGIN
    SELECT COUNT(*) INTO leaked
    FROM v_completed_line_items li
    JOIN orders o ON o.order_id = li.order_id
    WHERE o.status <> 'completed';
    ASSERT leaked = 0, format('non-completed orders leaked into revenue: %s rows', leaked);
END $$;

-- 4. top_customers: ranking is dense-free contiguous and the #1 customer
--    has the maximum lifetime spend.
DO $$
DECLARE
    top_spend   NUMERIC;
    max_spend   NUMERIC;
BEGIN
    SELECT lifetime_spend INTO top_spend FROM top_customers WHERE spend_rank = 1 LIMIT 1;
    SELECT MAX(lifetime_spend) INTO max_spend FROM top_customers;
    ASSERT top_spend = max_spend,
        format('rank-1 spend %s != max spend %s', top_spend, max_spend);
END $$;

-- 5. product_performance: per-category revenue shares sum to ~100%
--    for categories that have any revenue.
DO $$
DECLARE off_by INT;
BEGIN
    SELECT COUNT(*) INTO off_by
    FROM (
        SELECT category, SUM(pct_of_category_revenue) AS total_pct
        FROM product_performance
        WHERE revenue > 0
        GROUP BY category
    ) s
    WHERE ABS(total_pct - 100.0) > 0.5;  -- allow tiny rounding drift
    ASSERT off_by = 0,
        format('%s category(ies) have revenue shares not summing to 100%%', off_by);
END $$;

-- 6. customer_rfm: scores are bounded 1..4 and every purchasing customer is labelled.
DO $$
DECLARE
    bad_score INT;
    expected  INT;
    got       INT;
BEGIN
    SELECT COUNT(*) INTO bad_score
    FROM customer_rfm
    WHERE r_score NOT BETWEEN 1 AND 4
       OR f_score NOT BETWEEN 1 AND 4
       OR m_score NOT BETWEEN 1 AND 4;
    ASSERT bad_score = 0, format('%s RFM rows have out-of-range scores', bad_score);

    -- Every customer with a completed order should appear in the RFM view.
    SELECT COUNT(DISTINCT customer_id) INTO expected FROM v_completed_line_items;
    SELECT COUNT(*) INTO got FROM customer_rfm;
    ASSERT expected = got,
        format('RFM customer count %s != purchasing customers %s', got, expected);
END $$;

-- If we got here, every assertion passed.
DO $$ BEGIN RAISE NOTICE 'All assertions passed.'; END $$;
