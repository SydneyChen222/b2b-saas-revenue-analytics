-- Effective-dated intervals for a subscription must not overlap.
-- Overlap would double-count MRR in the point-in-time join.
select
    a.subscription_id,
    a.effective_at    as state_1_start,
    a.effective_until as state_1_end,
    b.effective_at    as state_2_start,
    b.effective_until as state_2_end

from {{ ref('stg_subscription_history') }} a
join {{ ref('stg_subscription_history') }} b
    on a.subscription_id = b.subscription_id
    and a.effective_at < b.effective_at
    and (
        a.effective_until is null
        or b.effective_at < a.effective_until
    )
