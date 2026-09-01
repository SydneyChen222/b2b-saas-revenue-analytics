{{
    config(materialized='view')
}}

-- ============================================================
-- Model: stg_subscription_history
--
-- Grain:
-- one row per subscription state change
--
-- Purpose:
-- Standardize subscription history and derive the effective
-- date range for each subscription state, converting an
-- effective-dated change log into a set of non-overlapping
-- validity intervals (SCD Type 2 style).
-- ============================================================

with source as (

    select * from {{ ref('subscription_history') }}

)

select
    subscription_id,
    customer_id,
    plan_id,
    mrr,
    seat_count,
    status,
    effective_at,

    -- The next state's start date closes the current interval.
    -- A null value means the state is still in effect.
    lead(effective_at) over (
        partition by subscription_id
        order by effective_at
    ) as effective_until

from source
