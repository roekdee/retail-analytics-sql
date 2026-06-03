-- 05_rfm_segment_summary.sql
-- Roll up the per-customer RFM view into a per-label summary: how many customers
-- sit in each segment and how much revenue they represent.
-- Demonstrates: building on a window-function-driven view (customer_rfm) and
-- using a window SUM to express each segment's share of total monetary value.
SET search_path TO retail, public;

SELECT
    rfm_label,
    COUNT(*)                                                       AS customers,
    SUM(monetary)                                                  AS segment_revenue,
    ROUND(AVG(frequency), 1)                                       AS avg_frequency,
    ROUND(AVG(recency_days), 1)                                    AS avg_recency_days,
    ROUND(
        100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1
    )                                                              AS pct_of_total_revenue
FROM customer_rfm
GROUP BY rfm_label
ORDER BY segment_revenue DESC;
