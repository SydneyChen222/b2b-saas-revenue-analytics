-- ============================================================
-- Model: mart_revenue_growth
--
-- Grain:
-- one row per month x customer segment
--
-- Purpose:
-- Aggregate customer-level MRR movement into a business-facing
-- monthly revenue growth view for Finance, GTM, and Customer
-- Success reporting.
--
-- Sources:
--   mart_customer_mrr_movement
--   dim_customer
--
-- Key Metrics:
--   beginning_mrr
--   ending_mrr
--   new_mrr
--   expansion_mrr
--   contraction_mrr
--   churn_mrr
--   reactivation_mrr
--   grr
--   nrr
--   logo_churn_rate
-- ============================================================


WITH segment_monthly_mrr AS (

    SELECT
        m.month,
        c.segment,

        -- ----------------------------------------------------
        -- MRR balances
        -- ----------------------------------------------------

        SUM(m.previous_mrr) AS beginning_mrr,

        SUM(m.current_mrr) AS ending_mrr,


        -- ----------------------------------------------------
        -- MRR movement
        -- ----------------------------------------------------

        SUM(m.new_mrr) AS new_mrr,

        SUM(m.expansion_mrr) AS expansion_mrr,

        SUM(m.contraction_mrr) AS contraction_mrr,

        SUM(m.churn_mrr) AS churn_mrr,

        SUM(m.reactivation_mrr) AS reactivation_mrr,


        -- ----------------------------------------------------
        -- Customer counts
        -- ----------------------------------------------------

        COUNT(
            DISTINCT CASE
                WHEN m.previous_mrr > 0
                THEN m.customer_id
            END
        ) AS beginning_customers,

        COUNT(
            DISTINCT CASE
                WHEN m.current_mrr > 0
                THEN m.customer_id
            END
        ) AS active_customers,

        COUNT(
            DISTINCT CASE
                WHEN m.new_mrr > 0
                THEN m.customer_id
            END
        ) AS new_customers,

        COUNT(
            DISTINCT CASE
                WHEN m.expansion_mrr > 0
                THEN m.customer_id
            END
        ) AS expanding_customers,

        COUNT(
            DISTINCT CASE
                WHEN m.contraction_mrr > 0
                THEN m.customer_id
            END
        ) AS contracting_customers,

        COUNT(
            DISTINCT CASE
                WHEN m.churn_mrr > 0
                THEN m.customer_id
            END
        ) AS churned_customers,

        COUNT(
            DISTINCT CASE
                WHEN m.reactivation_mrr > 0
                THEN m.customer_id
            END
        ) AS reactivated_customers

    FROM mart_customer_mrr_movement m

    LEFT JOIN dim_customer c
        ON m.customer_id = c.customer_id

    GROUP BY
        m.month,
        c.segment

)


SELECT
    month,
    segment,

    -- MRR balances
    beginning_mrr,
    ending_mrr,

    -- Net MRR movement
    ending_mrr - beginning_mrr AS net_mrr_change,

    -- MRR movement components
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churn_mrr,
    reactivation_mrr,

    -- Customer counts
    beginning_customers,
    active_customers,
    new_customers,
    expanding_customers,
    contracting_customers,
    churned_customers,
    reactivated_customers,


    -- --------------------------------------------------------
    -- Monthly MRR Growth Rate
    -- --------------------------------------------------------

    (
        ending_mrr - beginning_mrr
    ) * 1.0
    / NULLIF(beginning_mrr, 0)
        AS mrr_growth_rate,


    -- --------------------------------------------------------
    -- Gross Revenue Retention
    --
    -- Measures how much beginning MRR remains after
    -- contraction and churn.
    --
    -- Expansion, reactivation, and new MRR are excluded.
    -- --------------------------------------------------------

    (
        beginning_mrr
        - contraction_mrr
        - churn_mrr
    ) * 1.0
    / NULLIF(beginning_mrr, 0)
        AS grr,


    -- --------------------------------------------------------
    -- Net Revenue Retention
    --
    -- Measures revenue change from the existing customer base
    -- after expansion, contraction, churn, and reactivation.
    --
    -- New MRR is intentionally excluded because those
    -- customers were not part of beginning MRR.
    -- --------------------------------------------------------

    (
        beginning_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) * 1.0
    / NULLIF(beginning_mrr, 0)
        AS nrr,


    -- --------------------------------------------------------
    -- Logo Churn Rate
    --
    -- Churned customers divided by customers that were active
    -- at the beginning of the month.
    -- --------------------------------------------------------

    churned_customers * 1.0
    / NULLIF(beginning_customers, 0)
        AS logo_churn_rate


FROM segment_monthly_mrr

ORDER BY
    month,
    segment;
