-- Model: mart_customer_mrr_movement
-- Grain: one row per month x customer_id
-- Purpose:
-- Classify monthly customer MRR movement into
-- new, expansion, contraction, churn, and reactivation.
WITH customer_history AS (

    SELECT
        month,
        customer_id,
        monthly_mrr,

        LAG(monthly_mrr) OVER (
            PARTITION BY customer_id
            ORDER BY month
        ) AS previous_mrr,

        MIN(
            CASE
                WHEN monthly_mrr > 0 THEN month
            END
        ) OVER (
            PARTITION BY customer_id
        ) AS first_positive_mrr_month

    FROM int_customer_month_mrr

)

SELECT
    month,
    customer_id,
    monthly_mrr AS current_mrr,
    COALESCE(previous_mrr, 0) AS previous_mrr,

    CASE
        WHEN month = first_positive_mrr_month
        THEN monthly_mrr
        ELSE 0
    END AS new_mrr,

    CASE
        WHEN previous_mrr > 0
         AND monthly_mrr > previous_mrr
        THEN monthly_mrr - previous_mrr
        ELSE 0
    END AS expansion_mrr,

    CASE
        WHEN previous_mrr > monthly_mrr
         AND monthly_mrr > 0
        THEN previous_mrr - monthly_mrr
        ELSE 0
    END AS contraction_mrr,

    CASE
        WHEN previous_mrr > 0
         AND monthly_mrr = 0
        THEN previous_mrr
        ELSE 0
    END AS churn_mrr,

    CASE
        WHEN monthly_mrr > 0
         AND previous_mrr = 0
         AND month > first_positive_mrr_month
        THEN monthly_mrr
        ELSE 0
    END AS reactivation_mrr

FROM customer_history;
