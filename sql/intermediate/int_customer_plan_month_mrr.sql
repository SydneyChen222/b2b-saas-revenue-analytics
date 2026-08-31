-- ============================================================
-- Model: int_customer_plan_month_mrr
--
-- Grain:
-- one row per month x customer x plan
--
-- Purpose:
-- Create a monthly customer-plan MRR state that supports
-- plan mix, seat movement, plan migration, and packaging
-- analysis.
--
-- Important:
-- Customer lifecycle metrics such as New, Churn, and
-- Reactivation are calculated at the customer level.
--
-- A customer moving from one plan to another should not
-- automatically be interpreted as customer churn or
-- new customer acquisition.
--
-- Sources:
--   stg_subscription_history
--   dim_customer
--   dim_month
-- ============================================================


WITH customer_plan AS (

    -- --------------------------------------------------------
    -- Identify every customer-plan relationship that has
    -- existed historically.
    --
    -- A customer can have multiple subscriptions and may
    -- therefore have multiple plans.
    -- --------------------------------------------------------

    SELECT DISTINCT
        customer_id,
        plan_id

    FROM stg_subscription_history

),


customer_plan_month AS (

    -- --------------------------------------------------------
    -- Create a month scaffold for every historical
    -- customer-plan combination.
    --
    -- Months before the customer signed up are excluded.
    -- --------------------------------------------------------

    SELECT
        m.month,
        m.month_end_date,

        cp.customer_id,
        cp.plan_id

    FROM customer_plan cp

    INNER JOIN dim_customer c
        ON cp.customer_id = c.customer_id

    CROSS JOIN dim_month m

    WHERE m.month_end_date >= c.signup_date

),


customer_plan_month_state AS (

    -- --------------------------------------------------------
    -- Resolve the subscription state that was effective at
    -- each month-end.
    --
    -- Multiple subscriptions belonging to the same customer
    -- and plan are summed together.
    -- --------------------------------------------------------

    SELECT
        cpm.month,
        cpm.customer_id,
        cpm.plan_id,

        COALESCE(
            SUM(
                CASE
                    WHEN s.status = 'active'
                    THEN s.mrr
                    ELSE 0
                END
            ),
            0
        ) AS plan_mrr,

        COALESCE(
            SUM(
                CASE
                    WHEN s.status = 'active'
                    THEN s.seat_count
                    ELSE 0
                END
            ),
            0
        ) AS seat_count

    FROM customer_plan_month cpm

    LEFT JOIN stg_subscription_history s

        ON cpm.customer_id = s.customer_id

        AND cpm.plan_id = s.plan_id

        -- State must already be effective
        AND cpm.month_end_date >= s.effective_at

        -- State must not yet have expired
        AND (
            cpm.month_end_date < s.effective_until
            OR s.effective_until IS NULL
        )

    GROUP BY
        cpm.month,
        cpm.customer_id,
        cpm.plan_id

)


SELECT
    month,
    customer_id,
    plan_id,
    plan_mrr,
    seat_count

FROM customer_plan_month_state

ORDER BY
    month,
    customer_id,
    plan_id;
