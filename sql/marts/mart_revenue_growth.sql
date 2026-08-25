-- Model: mart_revenue_growth
-- Grain: one row per month x customer segment
-- Purpose:
-- Summarize recurring revenue movement and retention metrics
-- for business reporting.
SELECT
    m.month,
    c.segment,

    SUM(m.previous_mrr) AS beginning_mrr,
    SUM(m.current_mrr) AS ending_mrr,

    SUM(m.new_mrr) AS new_mrr,
    SUM(m.expansion_mrr) AS expansion_mrr,
    SUM(m.contraction_mrr) AS contraction_mrr,
    SUM(m.churn_mrr) AS churn_mrr,
    SUM(m.reactivation_mrr) AS reactivation_mrr,

    COUNT(DISTINCT CASE
        WHEN m.current_mrr > 0
        THEN m.customer_id
    END) AS active_customers,

    COUNT(DISTINCT CASE
        WHEN m.new_mrr > 0
        THEN m.customer_id
    END) AS new_customers,

    COUNT(DISTINCT CASE
        WHEN m.churn_mrr > 0
        THEN m.customer_id
    END) AS churned_customers

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

GROUP BY
    m.month,
    c.segment;
