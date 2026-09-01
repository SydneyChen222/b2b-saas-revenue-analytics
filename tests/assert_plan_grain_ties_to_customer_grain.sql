-- Cross-model consistency: total MRR summed across the
-- customer-plan grain must tie to the customer grain for
-- every month. Guards against fan-out in the plan model.
with plan_level as (
    select month, customer_id, sum(plan_mrr) as plan_total_mrr
    from {{ ref('int_customer_plan_month_mrr') }}
    group by month, customer_id
)

select
    c.month,
    c.customer_id,
    c.monthly_mrr,
    p.plan_total_mrr,
    p.plan_total_mrr - c.monthly_mrr as difference

from {{ ref('int_customer_month_mrr') }} c
join plan_level p
    on c.month = p.month
    and c.customer_id = p.customer_id

where abs(p.plan_total_mrr - c.monthly_mrr) > 0.01
