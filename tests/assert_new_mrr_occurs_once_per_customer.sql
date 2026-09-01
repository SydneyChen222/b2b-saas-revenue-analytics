-- A customer can only have New MRR in one month (their first
-- ever positive-MRR month). Later returns are Reactivation.
select
    customer_id,
    count(*) as new_mrr_months
from {{ ref('mart_customer_mrr_movement') }}
where new_mrr > 0
group by customer_id
having count(*) > 1
