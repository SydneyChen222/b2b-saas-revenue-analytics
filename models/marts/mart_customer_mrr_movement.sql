{{
    config(materialized='table')
}}

-- ============================================================
-- Model: mart_customer_mrr_movement
--
-- Grain:
-- one row per month x customer
--
-- Purpose:
-- Classify monthly customer MRR movement into new, expansion,
-- contraction, churn, and reactivation. These five components
-- form the MRR bridge that reconciles beginning to ending MRR.
-- ============================================================

with customer_history as (

    select
        month,
        customer_id,
        monthly_mrr,

        lag(monthly_mrr) over (
            partition by customer_id
            order by month
        ) as previous_mrr,

        -- First month the customer ever had positive MRR.
        -- Used to separate New from Reactivation.
        min(case when monthly_mrr > 0 then month end) over (
            partition by customer_id
        ) as first_positive_mrr_month

    from {{ ref('int_customer_month_mrr') }}

)

select
    month,
    customer_id,
    monthly_mrr as current_mrr,
    coalesce(previous_mrr, 0) as previous_mrr,

    -- New: the customer's first-ever month with positive MRR
    case
        when month = first_positive_mrr_month
        then monthly_mrr
        else 0
    end as new_mrr,

    -- Expansion: existing active customer increases MRR
    case
        when previous_mrr > 0 and monthly_mrr > previous_mrr
        then monthly_mrr - previous_mrr
        else 0
    end as expansion_mrr,

    -- Contraction: MRR decreases but customer stays active
    case
        when previous_mrr > monthly_mrr and monthly_mrr > 0
        then previous_mrr - monthly_mrr
        else 0
    end as contraction_mrr,

    -- Churn: customer goes from positive MRR to zero
    case
        when previous_mrr > 0 and monthly_mrr = 0
        then previous_mrr
        else 0
    end as churn_mrr,

    -- Reactivation: returns to positive MRR after a zero month,
    -- but is not the customer's first-ever positive month
    case
        when monthly_mrr > 0
         and previous_mrr = 0
         and month > first_positive_mrr_month
        then monthly_mrr
        else 0
    end as reactivation_mrr

from customer_history
