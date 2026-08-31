-- ============================================================
-- Analysis 04: Plan & Packaging Analysis
--
-- Business Questions:
-- 1. How is MRR distributed across plans?
-- 2. Which plans are growing or shrinking?
-- 3. Are seat counts changing within plans?
-- 4. Are customers moving between plan tiers?
--
-- Important:
-- Plan-level MRR movement is descriptive.
-- Plan migration should not automatically be interpreted as
-- customer churn or customer acquisition.
-- ============================================================



-- ============================================================
-- 1. PLAN MRR TREND
-- ============================================================


WITH plan_monthly AS (

    SELECT
        pm.month,
        pm.plan_id,
        p.plan_name,
        p.plan_tier,

        SUM(pm.plan_mrr) AS total_plan_mrr,

        SUM(pm.seat_count) AS total_seats,

        COUNT(
            DISTINCT CASE
                WHEN pm.plan_mrr > 0
                THEN pm.customer_id
            END
        ) AS active_customers

    FROM int_customer_plan_month_mrr pm

    LEFT JOIN dim_plan p
        ON pm.plan_id = p.plan_id

    GROUP BY
        pm.month,
        pm.plan_id,
        p.plan_name,
        p.plan_tier

),


plan_growth AS (

    SELECT
        *,

        LAG(total_plan_mrr) OVER (
            PARTITION BY plan_id
            ORDER BY month
        ) AS previous_plan_mrr,

        LAG(total_seats) OVER (
            PARTITION BY plan_id
            ORDER BY month
        ) AS previous_seats

    FROM plan_monthly

)


SELECT
    month,
    plan_id,
    plan_name,
    plan_tier,

    total_plan_mrr,

    previous_plan_mrr,

    total_plan_mrr
        - previous_plan_mrr
        AS plan_mrr_change,

    (
        total_plan_mrr
        - previous_plan_mrr
    ) * 1.0
    / NULLIF(previous_plan_mrr, 0)
        AS plan_mrr_growth_rate,

    active_customers,

    total_seats,

    total_seats
        - previous_seats
        AS seat_change

FROM plan_growth

ORDER BY
    month,
    plan_tier;



-- ============================================================
-- 2. PLAN MIX
-- ============================================================
-- What percentage of company MRR comes from each plan?
-- ============================================================


WITH plan_mrr AS (

    SELECT
        pm.month,
        pm.plan_id,
        p.plan_name,

        SUM(pm.plan_mrr) AS total_plan_mrr

    FROM int_customer_plan_month_mrr pm

    LEFT JOIN dim_plan p
        ON pm.plan_id = p.plan_id

    GROUP BY
        pm.month,
        pm.plan_id,
        p.plan_name

),


company_mrr AS (

    SELECT
        month,
        SUM(total_plan_mrr) AS company_mrr

    FROM plan_mrr

    GROUP BY month

)


SELECT
    p.month,
    p.plan_id,
    p.plan_name,
    p.total_plan_mrr,

    p.total_plan_mrr * 1.0
        / NULLIF(c.company_mrr, 0)
        AS share_of_company_mrr

FROM plan_mrr p

LEFT JOIN company_mrr c
    ON p.month = c.month

ORDER BY
    p.month,
    p.total_plan_mrr DESC;



-- ============================================================
-- 3. CUSTOMER-PLAN MRR CHANGES
-- ============================================================
-- Identify where MRR entered or left a specific plan.
--
-- Important:
-- A plan-level decrease does NOT necessarily mean customer churn.
-- The customer may simply have migrated to another plan.
-- ============================================================


WITH plan_history AS (

    SELECT
        pm.month,
        pm.customer_id,
        pm.plan_id,
        p.plan_name,
        p.plan_tier,

        pm.plan_mrr AS current_plan_mrr,

        LAG(pm.plan_mrr) OVER (
            PARTITION BY
                pm.customer_id,
                pm.plan_id
            ORDER BY pm.month
        ) AS previous_plan_mrr

    FROM int_customer_plan_month_mrr pm

    LEFT JOIN dim_plan p
        ON pm.plan_id = p.plan_id

)


SELECT
    month,
    customer_id,
    plan_id,
    plan_name,
    plan_tier,

    previous_plan_mrr,
    current_plan_mrr,

    current_plan_mrr
        - previous_plan_mrr
        AS plan_mrr_change

FROM plan_history

WHERE current_plan_mrr <> previous_plan_mrr

ORDER BY
    month,
    customer_id;



-- ============================================================
-- 4. SEAT MOVEMENT
-- ============================================================
-- Investigate whether changes in recurring revenue are
-- associated with customers adding or reducing seats.
-- ============================================================


WITH seat_history AS (

    SELECT
        pm.month,
        pm.customer_id,
        pm.plan_id,
        p.plan_name,

        pm.plan_mrr,
        pm.seat_count,

        LAG(pm.seat_count) OVER (
            PARTITION BY
                pm.customer_id,
                pm.plan_id
            ORDER BY pm.month
        ) AS previous_seats,

        LAG(pm.plan_mrr) OVER (
            PARTITION BY
                pm.customer_id,
                pm.plan_id
            ORDER BY pm.month
        ) AS previous_plan_mrr

    FROM int_customer_plan_month_mrr pm

    LEFT JOIN dim_plan p
        ON pm.plan_id = p.plan_id

)


SELECT
    month,
    customer_id,
    plan_id,
    plan_name,

    previous_seats,
    seat_count,

    seat_count
        - previous_seats
        AS seat_change,

    previous_plan_mrr,
    plan_mrr,

    plan_mrr
        - previous_plan_mrr
        AS plan_mrr_change

FROM seat_history

WHERE
    seat_count <> previous_seats
    OR plan_mrr <> previous_plan_mrr

ORDER BY
    month,
    customer_id;
