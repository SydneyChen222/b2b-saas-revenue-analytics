import os

import pandas as pd
import matplotlib.pyplot as plt


# ============================================================
# Configuration
# ============================================================

OUTPUT_DATA_PATH = "output/sample_results"
CHART_PATH = "output/charts"

os.makedirs(CHART_PATH, exist_ok=True)


# ============================================================
# Load Data
# ============================================================

company = pd.read_csv(
    f"{OUTPUT_DATA_PATH}/01_company_revenue_growth.csv"
)

segment = pd.read_csv(
    f"{OUTPUT_DATA_PATH}/02_segment_analysis.csv"
)

customer = pd.read_csv(
    f"{OUTPUT_DATA_PATH}/03_customer_movement_analysis.csv"
)


# Convert month to datetime
company["month"] = pd.to_datetime(company["month"])

segment["month"] = pd.to_datetime(segment["month"])


# ============================================================
# Chart 1: Monthly MRR Trend
# ============================================================

fig, ax = plt.subplots(figsize=(10, 5))

ax.plot(
    company["month"],
    company["ending_mrr"],
    marker="o",
    linewidth=2
)

ax.set_title(
    "Monthly Recurring Revenue Trend",
    fontsize=14,
    fontweight="bold"
)

ax.set_xlabel("Month")
ax.set_ylabel("Ending MRR ($)")

ax.grid(
    axis="y",
    alpha=0.3
)

# Add value labels
for x, y in zip(
    company["month"],
    company["ending_mrr"]
):
    ax.annotate(
        f"${y:,.0f}",
        (x, y),
        textcoords="offset points",
        xytext=(0, 8),
        ha="center",
        fontsize=8
    )

plt.xticks(rotation=45)

plt.tight_layout()

plt.savefig(
    f"{CHART_PATH}/01_mrr_trend.png",
    dpi=200,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# Chart 2: Monthly MRR Movement
# ============================================================

movement = company.copy()

# Losses should appear below zero
movement["contraction_mrr_negative"] = (
    -movement["contraction_mrr"]
)

movement["churn_mrr_negative"] = (
    -movement["churn_mrr"]
)


fig, ax = plt.subplots(figsize=(11, 6))


# ------------------------------------------------------------
# Positive MRR movement
# ------------------------------------------------------------

positive_bottom = pd.Series(
    0,
    index=movement.index,
    dtype=float
)

for column, label in [
    ("new_mrr", "New"),
    ("expansion_mrr", "Expansion"),
    ("reactivation_mrr", "Reactivation")
]:

    ax.bar(
        movement["month"],
        movement[column],
        bottom=positive_bottom,
        label=label
    )

    positive_bottom += movement[column]


# ------------------------------------------------------------
# Negative MRR movement
# ------------------------------------------------------------

negative_bottom = pd.Series(
    0,
    index=movement.index,
    dtype=float
)

for column, label in [
    ("contraction_mrr_negative", "Contraction"),
    ("churn_mrr_negative", "Churn")
]:

    ax.bar(
        movement["month"],
        movement[column],
        bottom=negative_bottom,
        label=label
    )

    negative_bottom += movement[column]


ax.axhline(
    0,
    linewidth=1
)

ax.set_title(
    "Monthly MRR Movement",
    fontsize=14,
    fontweight="bold"
)

ax.set_xlabel("Month")
ax.set_ylabel("MRR Movement ($)")

ax.legend()

ax.grid(
    axis="y",
    alpha=0.3
)

plt.xticks(rotation=45)

plt.tight_layout()

plt.savefig(
    f"{CHART_PATH}/02_mrr_movement.png",
    dpi=200,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# Chart 3: Net Revenue Retention by Segment
# ============================================================

segment["nrr_pct"] = (
    segment["nrr"] * 100
)

nrr = segment.pivot(
    index="month",
    columns="segment",
    values="nrr_pct"
)


fig, ax = plt.subplots(figsize=(10, 5))

for column in nrr.columns:

    ax.plot(
        nrr.index,
        nrr[column],
        marker="o",
        linewidth=2,
        label=column
    )


# 100% NRR reference line
ax.axhline(
    100,
    linestyle="--",
    linewidth=1
)

ax.set_title(
    "Net Revenue Retention by Customer Segment",
    fontsize=14,
    fontweight="bold"
)

ax.set_xlabel("Month")
ax.set_ylabel("NRR (%)")

ax.legend(
    title="Segment"
)

ax.grid(
    axis="y",
    alpha=0.3
)

plt.xticks(rotation=45)

plt.tight_layout()

plt.savefig(
    f"{CHART_PATH}/03_nrr_by_segment.png",
    dpi=200,
    bbox_inches="tight"
)

plt.close()


print("Charts created successfully:")
print("output/charts/01_mrr_trend.png")
print("output/charts/02_mrr_movement.png")
print("output/charts/03_nrr_by_segment.png")
