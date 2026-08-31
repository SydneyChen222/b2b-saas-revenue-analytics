-- ============================================================
-- Analysis 03: Customer Revenue Movement
--
-- Business Questions:
-- 1. Which customers are driving expansion and contraction?
-- 2. Which customers show repeated revenue deterioration?
-- 3. Which customers recently churned or reactivated?
-- 4. Which accounts may deserve deeper CS or GTM review?
--
-- Sources:
--   mart_customer_mrr_movement
--   dim_customer
-- ============================================================



-- ============================================================
-- 1. CUSTOMER MOVEMENT HISTORY
-- ============================================================
-- Detailed monthly movement for each customer.
-- Useful for drilling into individual account behavior.


SELECT
    m.month,
    m.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    c.industry,

    m.previous_mrr,
    m.current_mrr,

    m.new_mrr,
    m.expansion_mrr,
    m.contraction_mrr,
    m.churn_mrr,
    m.reactivation_mrr,

    CASE
        WHEN m.new_mrr > 0
            THEN 'New'

        WHEN m.reactivation_mrr > 0
            THEN 'Reactivated'

        WHEN m.churn_mrr > 0
            THEN 'Churned'

        WHEN m.expansion_mrr > 0
            THEN 'Expanded'

        WHEN m.contraction_mrr > 0
            THEN 'Contracted'

        WHEN m.current_mrr > 0
            THEN 'Stable'

        ELSE 'Inactive'
    END AS movement_type

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

ORDER BY
    m.customer_id,
    m.month;



-- ============================================================
-- 2. CUSTOMER-LEVEL SUMMARY
-- ============================================================
-- Aggregate movement across the full analysis period.
--
-- This helps identify:
--   - customers generating the most expansion
--   - customers losing the most MRR
--   - repeated contraction
--   - customers that churned / reactivated
-- ============================================================


WITH customer_summary AS (

    SELECT
        m.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        c.industry,

        SUM(m.expansion_mrr) AS total_expansion_mrr,
        SUM(m.contraction_mrr) AS total_contraction_mrr,
        SUM(m.churn_mrr) AS total_churn_mrr,
        SUM(m.reactivation_mrr) AS total_reactivation_mrr,

        COUNT(
            CASE
                WHEN m.expansion_mrr > 0 THEN 1
            END
        ) AS expansion_months,

        COUNT(
            CASE
                WHEN m.contraction_mrr > 0 THEN 1
            END
        ) AS contraction_months,

        COUNT(
            CASE
                WHEN m.churn_mrr > 0 THEN 1
            END
        ) AS churn_events,

        COUNT(
            CASE
                WHEN m.reactivation_mrr > 0 THEN 1
            END
        ) AS reactivation_events

    FROM mart_customer_mrr_movement m

    LEFT JOIN dim_customer c
        ON m.customer_id = c.customer_id

    GROUP BY
        m.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        c.industry

)

SELECT
    *,

    total_expansion_mrr
        + total_reactivation_mrr
        - total_contraction_mrr
        - total_churn_mrr
        AS net_existing_customer_mrr_change

FROM customer_summary

ORDER BY net_existing_customer_mrr_change;



-- ============================================================
-- 3. REPEATED CONTRACTION
-- ============================================================
-- Customers with more than one contraction event may warrant
-- deeper investigation by Customer Success.
--
-- Repeated contraction does not automatically mean the account
-- will churn. It is a signal for further investigation.
-- ============================================================


SELECT
    m.customer_id,
    c.customer_name,
    c.segment,

    COUNT(*) AS contraction_events,

    SUM(m.contraction_mrr) AS total_contraction_mrr,

    MAX(m.contraction_mrr) AS largest_single_contraction

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

WHERE m.contraction_mrr > 0

GROUP BY
    m.customer_id,
    c.customer_name,
    c.segment

HAVING COUNT(*) > 1

ORDER BY total_contraction_mrr DESC;



-- ============================================================
-- 4. LARGEST CUSTOMER MRR LOSSES
-- ============================================================
-- Identify the largest individual contraction and churn events.
-- ============================================================


SELECT
    m.month,
    m.customer_id,
    c.customer_name,
    c.segment,

    m.previous_mrr,
    m.current_mrr,

    m.contraction_mrr,
    m.churn_mrr,

    m.contraction_mrr + m.churn_mrr AS total_mrr_loss

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

WHERE
    m.contraction_mrr > 0
    OR m.churn_mrr > 0

ORDER BY
    total_mrr_loss DESC;



-- ============================================================
-- 5. LARGEST EXPANSION OPPORTUNITIES / WINS
-- ============================================================
-- Identify customers producing the largest expansion MRR.
-- This can help GTM understand where existing-customer
-- expansion is strongest.
-- ============================================================


SELECT
    m.month,
    m.customer_id,
    c.customer_name,
    c.segment,

    m.previous_mrr,
    m.current_mrr,
    m.expansion_mrr

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

WHERE m.expansion_mrr > 0

ORDER BY
    m.expansion_mrr DESC;



-- ============================================================
-- 6. CHURNED CUSTOMERS
-- ============================================================


SELECT
    m.month AS churn_month,
    m.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    c.industry,

    m.previous_mrr AS mrr_lost

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

WHERE m.churn_mrr > 0

ORDER BY
    m.churn_mrr DESC;



-- ============================================================
-- 7. REACTIVATED CUSTOMERS
-- ============================================================


SELECT
    m.month AS reactivation_month,
    m.customer_id,
    c.customer_name,
    c.segment,

    m.reactivation_mrr

FROM mart_customer_mrr_movement m

LEFT JOIN dim_customer c
    ON m.customer_id = c.customer_id

WHERE m.reactivation_mrr > 0

ORDER BY
    m.reactivation_mrr DESC;
