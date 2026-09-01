# dbt Project — Setup & Structure

This converts the SQL models in this repository into a runnable dbt
project with seeds, `ref()` lineage, a test suite, generated docs, and
CI.

## Run it locally

```bash
pip install dbt-duckdb
dbt deps
dbt build --profiles-dir .     # seeds + models + all tests
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
```

`dbt build` runs seeds, models, and tests in dependency order and exits
non-zero if any test fails.

## Layout

```
dbt_project.yml                  project config, materializations
profiles.yml                     DuckDB connection (local, no cloud cost)
packages.yml                     dbt_utils dependency

seeds/                           source data loaded as tables
  dim_customer.csv
  dim_plan.csv
  dim_month.csv
  subscription_history.csv
  schema.yml                     seed tests: PKs, FKs, accepted values

models/
  staging/
    stg_subscription_history.sql effective-dated validity intervals
  intermediate/
    int_customer_month_mrr.sql          grain: month x customer
    int_customer_plan_month_mrr.sql     grain: month x customer x plan
  marts/
    mart_customer_mrr_movement.sql      MRR movement classification
    mart_revenue_growth.sql             segment bridge + GRR/NRR

tests/                           singular (business-rule) tests
  assert_mrr_bridge_reconciles.sql
  assert_movement_classification_is_valid.sql
  assert_new_mrr_occurs_once_per_customer.sql
  assert_no_overlapping_subscription_states.sql
  assert_plan_grain_ties_to_customer_grain.sql

.github/workflows/dbt_ci.yml     build + test on every push and PR
```

## Test coverage

The validation SQL was converted into tests that block the build.

**Generic tests (schema.yml)** — primary key uniqueness and not-null on
every seed; referential integrity from subscriptions to customers and
plans; accepted values on segment and status; non-negative ranges on all
MRR columns; and grain uniqueness on every model via
`unique_combination_of_columns`.

**Singular tests (tests/)**

| Test | What it protects |
|---|---|
| `assert_mrr_bridge_reconciles` | Beginning + New + Expansion + Reactivation − Contraction − Churn = Ending, per month × segment |
| `assert_movement_classification_is_valid` | Each movement component only fires under its defining condition |
| `assert_new_mrr_occurs_once_per_customer` | New MRR fires once per customer; later returns are Reactivation |
| `assert_no_overlapping_subscription_states` | Effective-dated intervals don't overlap (would double-count MRR) |
| `assert_plan_grain_ties_to_customer_grain` | Customer-plan grain sums back to customer grain — guards against fan-out |

The last one is a cross-model consistency check: the two intermediate
models sit at different grains, and this proves the finer grain still
ties to the coarser one.

## Notes

- DuckDB is used so the project runs locally and in CI with no warehouse
  credentials. The SQL is standard and ports to Snowflake by changing
  the profile.
- `dbt docs generate` produces the lineage graph and column-level
  documentation; CI uploads it as an artifact.
