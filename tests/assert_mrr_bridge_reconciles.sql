-- ============================================================
-- Financial reconciliation control
--
-- Beginning MRR + New + Expansion + Reactivation
--                - Contraction - Churn
-- must equal Ending MRR for every month x segment.
--
-- This is the same bridge Finance reports on, enforced as a
-- build-blocking test. Returns rows only on failure.
-- ============================================================

select
    month,
    segment,
    beginning_mrr,
    ending_mrr,
    (
        beginning_mrr
        + new_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) as calculated_ending_mrr,
    (
        beginning_mrr
        + new_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) - ending_mrr as reconciliation_difference

from {{ ref('mart_revenue_growth') }}

where abs(
    (
        beginning_mrr
        + new_mrr
        + expansion_mrr
        + reactivation_mrr
        - contraction_mrr
        - churn_mrr
    ) - ending_mrr
) > 0.01
