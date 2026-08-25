-- Model: int_customer_month_mrr
-- Grain: one row per month x customer_id
-- Purpose:
-- Calculate each customer's total MRR as of the end of each reporting month.
SELECT
    m.month,
    s.customer_id,
    SUM(s.mrr) AS monthly_mrr
FROM dim_month m
JOIN stg_subscription_history s
    ON m.month_end_date >= s.effective_at
    AND (
        m.month_end_date < s.effective_until
        OR s.effective_until IS NULL
    )
WHERE s.status = 'active'
GROUP BY
    m.month,
    s.customer_id;
