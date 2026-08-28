-- ============================================================
-- Analysis 02: Segment Revenue Performance
--
-- Business Question:
-- Which customer segments are driving MRR growth,
-- contraction, churn, and retention performance?
--
-- Source:
-- mart_revenue_growth
--
-- Grain:
-- one row per month x segment
-- ============================================================


WITH segment_metrics AS (

    SELECT
        month,
        segment,

        beginning_mrr,
        ending_mrr,

        ending_mrr - beginning_mrr AS net_mrr_change,

        new_mrr,
        expansion_mrr,
        contraction_mrr,
        churn_mrr,
        reactivation_mrr,

        active_customers,
        new_customers,
        churned_customers,
        expanding_customers,
        contracting_customers,
        reactivated_customers,

        -- Monthly MRR growth rate
        (
            ending_mrr - beginning_mrr
        ) * 1.0
        / NULLIF(beginning_mrr, 0) AS mrr_growth_rate,

        -- Gross Revenue Retention
        (
            beginning_mrr
            - contraction_mrr
            - churn_mrr
        ) * 1.0
        / NULLIF(beginning_mrr, 0) AS grr,

        -- Net Revenue Retention
        (
            beginning_mrr
            + expansion_mrr
            + reactivation_mrr
            - contraction_mrr
            - churn_mrr
        ) * 1.0
        / NULLIF(beginning_mrr, 0) AS nrr

    FROM mart_revenue_growth

),


company_total AS (

    SELECT
        month,
        SUM(ending_mrr) AS company_ending_mrr,
        SUM(
            ending_mrr - beginning_mrr
        ) AS company_net_mrr_change

    FROM mart_revenue_growth

    GROUP BY month

)


SELECT
    s.month,
    s.segment,

    s.beginning_mrr,
    s.ending_mrr,
    s.net_mrr_change,
    s.mrr_growth_rate,

    s.new_mrr,
    s.expansion_mrr,
    s.reactivation_mrr,
    s.contraction_mrr,
    s.churn_mrr,

    s.grr,
    s.nrr,

    s.active_customers,
    s.new_customers,
    s.churned_customers,
    s.expanding_customers,
    s.contracting_customers,

    -- Share of company MRR
    s.ending_mrr * 1.0
        / NULLIF(c.company_ending_mrr, 0)
        AS share_of_company_mrr,

    -- Contribution to company MRR change
    s.net_mrr_change * 1.0
        / NULLIF(c.company_net_mrr_change, 0)
        AS share_of_net_mrr_change

FROM segment_metrics s

LEFT JOIN company_total c
    ON s.month = c.month

ORDER BY
    s.month,
    s.segment;
