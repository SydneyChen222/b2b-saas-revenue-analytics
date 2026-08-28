-- 1. Grain / uniqueness checks
-- 2. Referential integrity
-- 3. Business-rule checks
-- 4. Financial reconciliation
-- ============================================================
-- Model Validation: B2B SaaS Revenue Analytics
-- Purpose:
-- Validate grains, relationships, business rules,
-- and MRR financial reconciliation.
-- ============================================================


-- ============================================================
-- 1. GRAIN / UNIQUENESS CHECKS
-- ============================================================


-- dim_customer should contain one row per customer_id
SELECT
    customer_id,
    COUNT(*) AS row_count
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- dim_plan should contain one row per plan_id
SELECT
    plan_id,
    COUNT(*) AS row_count
FROM dim_plan
GROUP BY plan_id
HAVING COUNT(*) > 1;


-- subscription history should contain one row per
-- subscription_id + effective_at
SELECT
    subscription_id,
    effective_at,
    COUNT(*) AS row_count
FROM stg_subscription_history
GROUP BY
    subscription_id,
    effective_at
HAVING COUNT(*) > 1;


-- intermediate model should contain one row per month x customer
SELECT
    month,
    customer_id,
    COUNT(*) AS row_count
FROM int_customer_month_mrr
GROUP BY
    month,
    customer_id
HAVING COUNT(*) > 1;


-- movement mart should contain one row per month x customer
SELECT
    month,
    customer_id,
    COUNT(*) AS row_count
FROM mart_customer_mrr_movement
GROUP BY
    month,
    customer_id
HAVING COUNT(*) > 1;


-- revenue growth mart should contain one row per month x segment
SELECT
    month,
    segment,
    COUNT(*) AS row_count
FROM mart_revenue_growth
GROUP BY
    month,
    segment
HAVING COUNT(*) > 1;



-- ============================================================
-- 2. REFERENTIAL INTEGRITY
-- ============================================================


-- Every subscription customer should exist in dim_customer
SELECT DISTINCT
    s.customer_id
FROM stg_subscription_history s
LEFT JOIN dim_customer c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- Every subscription plan should exist in dim_plan
SELECT DISTINCT
    s.plan_id
FROM stg_subscription_history s
LEFT JOIN dim_plan p
    ON s.plan_id = p.plan_id
WHERE p.plan_id IS NULL;



-- ============================================================
-- 3. BUSINESS RULE CHECKS
-- ============================================================


-- MRR should never be negative
SELECT *
FROM int_customer_month_mrr
WHERE monthly_mrr < 0;


-- A customer should have New MRR only once
SELECT
    customer_id,
    COUNT(*) AS new_mrr_months
FROM mart_customer_mrr_movement
WHERE new_mrr > 0
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- Churn should only happen when:
-- previous MRR > 0 and current MRR = 0
SELECT *
FROM mart_customer_mrr_movement
WHERE churn_mrr > 0
  AND NOT (
        previous_mrr > 0
        AND current_mrr = 0
  );


-- Expansion should only happen when
-- current MRR > previous MRR > 0
SELECT *
FROM mart_customer_mrr_movement
WHERE expansion_mrr > 0
  AND NOT (
        previous_mrr > 0
        AND current_mrr > previous_mrr
  );


-- Contraction should only happen when
-- previous MRR > current MRR > 0
SELECT *
FROM mart_customer_mrr_movement
WHERE contraction_mrr > 0
  AND NOT (
        previous_mrr > current_mrr
        AND current_mrr > 0
  );


-- Reactivation should only happen when:
-- current MRR > 0
-- previous month MRR = 0
SELECT *
FROM mart_customer_mrr_movement
WHERE reactivation_mrr > 0
  AND NOT (
        previous_mrr = 0
        AND current_mrr > 0
  );


-- Check for overlapping subscription states
SELECT
    a.subscription_id,
    a.effective_at AS state_1_start,
    a.effective_until AS state_1_end,
    b.effective_at AS state_2_start,
    b.effective_until AS state_2_end
FROM stg_subscription_history a
JOIN stg_subscription_history b
    ON a.subscription_id = b.subscription_id
    AND a.effective_at < b.effective_at
    AND (
        a.effective_until IS NULL
        OR b.effective_at < a.effective_until
    );



-- ============================================================
-- 4. FINANCIAL RECONCILIATION
-- ============================================================


-- Beginning MRR
-- + New
-- + Expansion
-- + Reactivation
-- - Contraction
-- - Churn
-- should equal Ending MRR

SELECT
    month,
    segment,

    beginning_mrr,

    new_mrr,
    expansion_mrr,
    reactivation_mrr,

    contraction_mrr,
    churn_mrr,

    ending_mrr,

    beginning_mrr
        + new_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
        AS calculated_ending_mrr,

    (
        beginning_mrr
        + new_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) - ending_mrr AS reconciliation_difference

FROM mart_revenue_growth

WHERE ABS(
    (
        beginning_mrr
        + new_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) - ending_mrr
) > 0.01
--For all of these validation queries, the ideal result is generally: 0 rows returned
--Also manual reconciliation query specifically for a few demo customers
SELECT
    month,
    customer_id,
    previous_mrr,
    current_mrr,
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churn_mrr,
    reactivation_mrr
FROM mart_customer_mrr_movement
WHERE customer_id IN ('C002', 'C003', 'C005')
ORDER BY
    customer_id,
    month;
