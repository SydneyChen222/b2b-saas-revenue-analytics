{{
    config(materialized='view')
}}

-- ============================================================
-- Model: int_customer_plan_month_mrr
--
-- Grain:
-- one row per month x customer x plan
--
-- Purpose:
-- Monthly customer-plan MRR state supporting plan mix, seat
-- movement, plan migration, and packaging analysis.
--
-- Important:
-- Customer lifecycle metrics (new, churn, reactivation) are
-- deliberately calculated at the CUSTOMER grain, not here.
-- A customer moving between plans must not be misread as
-- churn on one plan plus new business on another.
-- ============================================================

with customer_plan as (

    -- Every customer-plan relationship that has existed
    select distinct
        customer_id,
        plan_id
    from {{ ref('stg_subscription_history') }}

),

customer_plan_month as (

    -- Month scaffold per historical customer-plan combination
    select
        m.month,
        m.month_end_date,
        cp.customer_id,
        cp.plan_id

    from customer_plan cp
    inner join {{ ref('dim_customer') }} c
        on cp.customer_id = c.customer_id
    cross join {{ ref('dim_month') }} m
    where m.month_end_date >= c.signup_date

),

customer_plan_month_state as (

    -- Resolve subscription state effective at each month end.
    -- Multiple subscriptions on the same customer+plan are summed.
    select
        cpm.month,
        cpm.customer_id,
        cpm.plan_id,

        coalesce(sum(
            case when s.status = 'active' then s.mrr else 0 end
        ), 0) as plan_mrr,

        coalesce(sum(
            case when s.status = 'active' then s.seat_count else 0 end
        ), 0) as seat_count

    from customer_plan_month cpm

    left join {{ ref('stg_subscription_history') }} s
        on cpm.customer_id = s.customer_id
        and cpm.plan_id = s.plan_id
        and cpm.month_end_date >= s.effective_at
        and (
            cpm.month_end_date < s.effective_until
            or s.effective_until is null
        )

    group by
        cpm.month,
        cpm.customer_id,
        cpm.plan_id

)

select
    month,
    customer_id,
    plan_id,
    plan_mrr,
    seat_count
from customer_plan_month_state
