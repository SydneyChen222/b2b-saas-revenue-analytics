{{
    config(materialized='table')
}}

-- ============================================================
-- Model: mart_revenue_growth
--
-- Grain:
-- one row per month x customer segment
--
-- Purpose:
-- Business-facing monthly revenue growth view for Finance,
-- GTM, and Customer Success, exposing the MRR bridge plus
-- GRR, NRR, growth rate, and logo churn.
-- ============================================================

with segment_monthly_mrr as (

    select
        m.month,
        c.segment,

        -- MRR balances
        sum(m.previous_mrr) as beginning_mrr,
        sum(m.current_mrr)  as ending_mrr,

        -- MRR movement components
        sum(m.new_mrr)           as new_mrr,
        sum(m.expansion_mrr)     as expansion_mrr,
        sum(m.contraction_mrr)   as contraction_mrr,
        sum(m.churn_mrr)         as churn_mrr,
        sum(m.reactivation_mrr)  as reactivation_mrr,

        -- Customer counts
        count(distinct case when m.previous_mrr > 0 then m.customer_id end)      as beginning_customers,
        count(distinct case when m.current_mrr > 0 then m.customer_id end)       as active_customers,
        count(distinct case when m.new_mrr > 0 then m.customer_id end)           as new_customers,
        count(distinct case when m.expansion_mrr > 0 then m.customer_id end)     as expanding_customers,
        count(distinct case when m.contraction_mrr > 0 then m.customer_id end)   as contracting_customers,
        count(distinct case when m.churn_mrr > 0 then m.customer_id end)         as churned_customers,
        count(distinct case when m.reactivation_mrr > 0 then m.customer_id end)  as reactivated_customers

    from {{ ref('mart_customer_mrr_movement') }} m

    left join {{ ref('dim_customer') }} c
        on m.customer_id = c.customer_id

    group by
        m.month,
        c.segment

)

select
    month,
    segment,

    beginning_mrr,
    ending_mrr,
    ending_mrr - beginning_mrr as net_mrr_change,

    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churn_mrr,
    reactivation_mrr,

    beginning_customers,
    active_customers,
    new_customers,
    expanding_customers,
    contracting_customers,
    churned_customers,
    reactivated_customers,

    -- Monthly MRR growth rate
    (ending_mrr - beginning_mrr) * 1.0
        / nullif(beginning_mrr, 0) as mrr_growth_rate,

    -- Gross Revenue Retention: beginning MRR retained after
    -- contraction and churn. Excludes expansion/reactivation/new.
    (
        beginning_mrr
        - contraction_mrr
        - churn_mrr
    ) * 1.0 / nullif(beginning_mrr, 0) as grr,

    -- Net Revenue Retention: existing-base revenue change after
    -- expansion, contraction, churn, and reactivation.
    -- New MRR excluded: those customers were not in beginning MRR.
    (
        beginning_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) * 1.0 / nullif(beginning_mrr, 0) as nrr,

    -- Logo churn: churned customers over customers active at
    -- the start of the month.
    churned_customers * 1.0
        / nullif(beginning_customers, 0) as logo_churn_rate

from segment_monthly_mrr
