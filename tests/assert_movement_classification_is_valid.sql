-- ============================================================
-- Business-rule integrity for MRR movement classification.
-- Each component may only fire under its defining condition.
-- ============================================================

select 'churn' as rule_violated, month, customer_id, previous_mrr, current_mrr
from {{ ref('mart_customer_mrr_movement') }}
where churn_mrr > 0
  and not (previous_mrr > 0 and current_mrr = 0)

union all

select 'expansion', month, customer_id, previous_mrr, current_mrr
from {{ ref('mart_customer_mrr_movement') }}
where expansion_mrr > 0
  and not (previous_mrr > 0 and current_mrr > previous_mrr)

union all

select 'contraction', month, customer_id, previous_mrr, current_mrr
from {{ ref('mart_customer_mrr_movement') }}
where contraction_mrr > 0
  and not (previous_mrr > current_mrr and current_mrr > 0)

union all

select 'reactivation', month, customer_id, previous_mrr, current_mrr
from {{ ref('mart_customer_mrr_movement') }}
where reactivation_mrr > 0
  and not (previous_mrr = 0 and current_mrr > 0)
