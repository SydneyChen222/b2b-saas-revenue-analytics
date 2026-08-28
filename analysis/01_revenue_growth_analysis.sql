-- ============================================================
-- Analysis 01: Overall MRR Growth
--
-- Business Question:
-- Is recurring revenue growth slowing, and what is driving
-- the change?
--
-- Source:
-- mart_revenue_growth
--
-- Analysis Grain:
-- one row per month
-- ============================================================
/*
output should looks like sth like:
| Month | Beginning MRR | Ending MRR | Net Change | Growth % |   New | Expansion | Contraction | Churn |  NRR |
| ----- | ------------: | ---------: | ---------: | -------: | ----: | --------: | ----------: | ----: | ---: |
| Feb   |        36,000 |     38,000 |     +2,000 |     5.6% | 2,300 |       500 |           0 |   800 |  99% |
| Mar   |        38,000 |     39,000 |     +1,000 |     2.6% |   600 |     1,500 |         500 |   600 | 101% |
| Apr   |        39,000 |     39,500 |       +500 |     1.3% |   400 |       800 |         700 |     0 | 100% |
| May   |        39,500 |     39,200 |       -300 |    -0.8% |     0 |       200 |         500 |   400 |  97% |
Then we start asking:

MRR is still growing, but is the growth rate declining?

And if yes:

Is that because New MRR is declining?

or:

Is Expansion weakening?

or:

Are Contraction and Churn increasing?
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
