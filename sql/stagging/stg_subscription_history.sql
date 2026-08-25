-- Model: stg_subscription_history
-- Grain: one row per subscription state change
-- Purpose:
-- Standardize subscription history and derive the effective
-- date range for each subscription state.
SELECT
    subscription_id,
    customer_id,
    plan_id,
    mrr,
    seat_count,
    status,
    effective_at,
    LEAD(effective_at) OVER (
        PARTITION BY subscription_id
        ORDER BY effective_at
    ) AS effective_until
FROM subscription_history;
