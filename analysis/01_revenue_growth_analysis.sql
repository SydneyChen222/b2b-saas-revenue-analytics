-- Business Question:
-- Is recurring revenue growth slowing, and what is driving the change?

-- Grain:
-- one row per month
*/


WITH company_monthly AS (

    SELECT
        month,

        SUM(beginning_mrr) AS beginning_mrr,
        SUM(ending_mrr) AS ending_mrr,

        SUM(new_mrr) AS new_mrr,
        SUM(expansion_mrr) AS expansion_mrr,
        SUM(contraction_mrr) AS contraction_mrr,
        SUM(churn_mrr) AS churn_mrr,
        SUM(reactivation_mrr) AS reactivation_mrr,

        SUM(active_customers) AS active_customers,
        SUM(new_customers) AS new_customers,
        SUM(churned_customers) AS churned_customers

    FROM mart_revenue_growth

    GROUP BY month

),


revenue_metrics AS (

    SELECT
        month,

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

    FROM company_monthly

)


SELECT
    month,

    beginning_mrr,
    ending_mrr,

    net_mrr_change,
    mrr_growth_rate,

    new_mrr,
    expansion_mrr,
    reactivation_mrr,
    contraction_mrr,
    churn_mrr,

    grr,
    nrr,

    active_customers,
    new_customers,
    churned_customers

FROM revenue_metrics

ORDER BY month;
