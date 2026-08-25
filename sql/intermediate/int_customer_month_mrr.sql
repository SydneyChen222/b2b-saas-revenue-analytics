-- Model: int_customer_month_mrr
-- Grain: one row per month x customer_id
-- Purpose:
-- Calculate each customer's total MRR as of the end of each reporting month.
-- Model: int_customer_month_mrr
-- Grain: one row per month x customer_id

WITH customer_month AS (

    SELECT
        m.month,
        m.month_end_date,
        c.customer_id
    FROM dim_month m
    CROSS JOIN dim_customer c
    WHERE m.month_end_date >= c.signup_date

)

SELECT
    cm.month,
    cm.customer_id,
    COALESCE(SUM(s.mrr), 0) AS monthly_mrr

FROM customer_month cm

LEFT JOIN stg_subscription_history s
    ON cm.customer_id = s.customer_id
    AND cm.month_end_date >= s.effective_at
    AND (
        cm.month_end_date < s.effective_until
        OR s.effective_until IS NULL
    )
    AND s.status = 'active'

GROUP BY
    cm.month,
    cm.customer_id;
