# B2B SaaS Revenue Analytics

An end-to-end analytics project modeling Monthly Recurring Revenue (MRR), customer revenue movement, and revenue retention for a fictional B2B SaaS company.

The project demonstrates how an ambiguous business question can be translated into:

**business requirements → metric definitions → data modeling → SQL transformations → validation → business analysis → recommendations**

---

## 1. Project Overview

Leadership has noticed that recurring revenue is still growing, but the rate of growth appears to be slowing.

Total MRR alone does not explain why.

For example, two months could show similar MRR growth while having very different underlying business dynamics:

- growth driven by strong expansion from existing customers,
- growth driven primarily by new customer acquisition,
- increasing contraction from existing customers,
- or rising customer churn.

The goal of this project is to build a trusted recurring revenue data foundation that helps the business answer:

> **What is driving recurring revenue growth, where is revenue being lost, and where should the company focus next?**

The project builds customer-level monthly MRR, classifies revenue movement, and creates business-facing metrics for Finance, GTM, and Customer Success.

---

## 2. Business Context

The fictional company is a B2B SaaS business serving three primary customer segments:

- SMB
- Mid-Market
- Enterprise

Customers may:

- hold one or multiple subscriptions,
- upgrade or downgrade plans,
- add or remove seats,
- cancel subscriptions,
- or reactivate after previously churning.

Subscription attributes can therefore change over time.

This creates an important modeling challenge:

> The business needs the correct subscription state at each historical month-end rather than simply using the customer's current subscription state.

---

## 3. Initial Business Request

The project begins with an intentionally ambiguous request from Finance leadership:

> **"Recurring revenue is still growing, but growth appears to be slowing. We need to understand what is driving the change and where the business should focus."**

Rather than immediately building a dashboard, the request is translated into specific analytical requirements.

---

## 4. Stakeholders & Business Decisions

### Finance / FP&A

Finance needs to explain changes in recurring revenue and understand the quality of revenue growth.

Key questions:

- What are beginning and ending MRR each month?
- How much MRR comes from new customers?
- How much comes from expansion?
- How much is lost through contraction?
- How much is lost through churn?
- How much revenue returns through reactivation?
- How are Gross Revenue Retention (GRR) and Net Revenue Retention (NRR) trending?

**Decisions supported:**

- financial planning,
- recurring revenue forecasting,
- identifying weakening or improving revenue trends.

---

### Sales / GTM

GTM wants to understand where existing-customer growth opportunities are strongest.

Key questions:

- Which segments generate the strongest expansion?
- Which customer groups have the strongest NRR?
- Which existing customers are consistently increasing recurring spend?
- Where should expansion efforts be prioritized?

**Decisions supported:**

- account prioritization,
- upsell strategy,
- segment-level GTM investment.

---

### Customer Success

Customer Success wants to identify revenue deterioration before a customer fully churns.

Key questions:

- Which customers are contracting?
- Which segments have elevated churn?
- Which customers show repeated MRR declines?
- Which previously churned customers have reactivated?

**Decisions supported:**

- retention prioritization,
- proactive customer outreach,
- customer health investigation.

---

### Pricing / Monetization

Pricing teams can use MRR movement as a signal for deeper pricing or packaging investigation.

Key questions:

- Which plans or segments experience unusually high contraction?
- Are customers frequently reducing seats?
- Are customers moving to lower plan tiers?
- Which plans have weaker expansion behavior?

MRR movement can identify where pricing or packaging deserves investigation, but it does **not** establish that pricing caused the behavior.

---

## 5. Analytical Requirements

The original business request is translated into four analytical questions.

### 1. What happened?

Create a consistent monthly view of recurring revenue for every customer.

### 2. What drove the change?

Classify customer MRR movement into:

- New MRR
- Expansion MRR
- Contraction MRR
- Churn MRR
- Reactivation MRR

### 3. Where is the change happening?

Analyze recurring revenue movement by:

- customer,
- customer segment,
- plan,
- and time period.

### 4. What should the business investigate?

Identify:

- segments with weakening retention,
- customers experiencing repeated contraction,
- strong expansion opportunities,
- and areas that may warrant deeper GTM, Customer Success, or Pricing analysis.

---

## 6. Core Business Definitions

### Monthly Recurring Revenue (MRR)

MRR represents the contractual recurring revenue associated with a customer at the end of a reporting month.

MRR is treated as a **point-in-time month-end metric**, not prorated recognized revenue.

Example:

A subscription changes from $1,000 MRR to $1,500 MRR on August 15.

**August month-end MRR = $1,500**

If a customer has multiple active subscriptions:

**Customer MRR = Sum of month-end MRR across all active subscriptions**

---

### New MRR

MRR generated in a customer's first-ever month with positive MRR.

Example:

| Month | MRR |
|---|---:|
| January | $0 |
| February | $0 |
| March | $1,000 |

**March New MRR = $1,000**

---

### Expansion MRR

Increase in recurring revenue from an existing active customer.

Example:

**$1,000 → $1,400**

Expansion MRR = **$400**

Expansion may result from additional seats, plan upgrades, add-ons, or pricing changes.

---

### Contraction MRR

Decrease in recurring revenue while the customer remains active.

Example:

**$1,000 → $700**

Contraction MRR = **$300**

---

### Churn MRR

MRR lost when a customer moves from positive MRR to zero.

Example:

**$1,000 → $0**

Churn MRR = **$1,000**

---

### Reactivation MRR

MRR generated when a previously churned customer becomes active again after at least one full month with zero MRR.

Example:

| Month | MRR |
|---|---:|
| January | $1,000 |
| February | $0 |
| March | $0 |
| April | $800 |

**April Reactivation MRR = $800**

---

## 7. MRR Movement Framework

Monthly recurring revenue should reconcile through the following bridge:

**Beginning MRR  
+ New MRR  
+ Expansion MRR  
+ Reactivation MRR  
- Contraction MRR  
- Churn MRR  
= Ending MRR**

This relationship serves both as:

1. a Finance reporting framework, and
2. a key data validation control.

---

## 8. Additional Revenue Metrics

### Gross Revenue Retention (GRR)

Measures how much recurring revenue from existing customers is retained before considering expansion.

Conceptually:

**GRR =  
(Beginning MRR - Contraction MRR - Churn MRR)  
/ Beginning MRR**

---

### Net Revenue Retention (NRR)

Measures recurring revenue retention after considering expansion and reactivation.

Conceptually:

**NRR =  
(Beginning MRR + Expansion MRR + Reactivation MRR - Contraction MRR - Churn MRR)  
/ Beginning MRR**

Additional metrics may include:

- logo churn rate,
- active customer count,
- new customer count,
- churned customer count,
- average MRR per customer.

---

## 9. Source Data

This project uses synthetic data representing a SaaS subscription environment.

### `dim_customer`

**Grain:** one row per customer

Example fields:

- `customer_id`
- `customer_name`
- `segment`
- `region`
- `industry`
- `signup_date`

For the first version of the project, customer segment is assumed to remain historically stable.

---

### `dim_plan`

**Grain:** one row per plan

Example fields:

- `plan_id`
- `plan_name`
- `plan_tier`

---

### `subscription_history`

**Grain:** one row per subscription state change

Example fields:

- `subscription_id`
- `customer_id`
- `plan_id`
- `mrr`
- `seat_count`
- `status`
- `effective_at`

One customer can have multiple subscriptions.

One subscription can have multiple state changes over time.

---

### `dim_month`

**Grain:** one row per reporting month

Example fields:

- `month`
- `month_start_date`
- `month_end_date`

---

## 10. Data Model

The model converts effective-dated subscription history into a reusable monthly customer revenue state.

```text
dim_customer        dim_plan        dim_month
      \                 |               /
       \                |              /
        ---- subscription_history ----
                     |
                     v
          stg_subscription_history
                     |
                     v
        int_customer_month_mrr
        grain: month × customer
                     |
                     v
       mart_customer_mrr_movement
       grain: month × customer
                     |
                     v
          mart_revenue_growth
          grain: month × segment
'''


## Key Findings

- MRR increased from $38.0K to $40.7K, but monthly growth was volatile.
- Mid-Market showed the greatest retention volatility.
- August–September recovery was driven primarily by reactivation rather
  than new acquisition or expansion.
- Enterprise remained the largest and most stable MRR base.

[View detailed findings and recommendations](Finding%20%26%20Recommendation.md)
