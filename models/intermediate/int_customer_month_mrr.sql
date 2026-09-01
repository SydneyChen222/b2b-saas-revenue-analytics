{{
    config(materialized='view')
}}

-- ============================================================
-- Model: int_customer_month_mrr
--
-- Grain:
-- one row per month x customer
--
-- Purpose:
-- Resolve each customer's total MRR as of the end of every
-- reporting month, using a point-in-time join against the
-- effective-dated subscription history.
-- ============================================================

with customer_month as (

    -- Month scaffold: every customer, every month on or after
    -- the month in which they signed up.
    select
        m.month,
        m.month_end_date,
        c.customer_id

    from {{ ref('dim_month') }} m
    cross join {{ ref('dim_customer') }} c
    where m.month_end_date >= c.signup_date

)

select
    cm.month,
    cm.customer_id,
    coalesce(sum(s.mrr), 0) as monthly_mrr

from customer_month cm

left join {{ ref('stg_subscription_history') }} s
    on cm.customer_id = s.customer_id
    -- State must already be effective at month end
    and cm.month_end_date >= s.effective_at
    -- State must not yet have been superseded
    and (
        cm.month_end_date < s.effective_until
        or s.effective_until is null
    )
    and s.status = 'active'

group by
    cm.month,
    cm.customer_id
