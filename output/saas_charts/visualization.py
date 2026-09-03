"""
Generate charts from the revenue models.

Data source
-----------
Reads from the DuckDB warehouse when it exists, so charts always reflect
the current dbt build. Falls back to the CSV extracts committed under
output/sample_results/ so charts can be regenerated from a fresh clone
without building the project first.

Each chart is written alongside the exact series behind it as CSV, so any
number on a chart can be checked against the data that produced it.
"""

from pathlib import Path

import matplotlib

# Render without a display, so this runs unchanged in CI
matplotlib.use("Agg")

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).parent.parent
DUCKDB_PATH = ROOT / "saas_revenue.duckdb"
CSV_PATH = ROOT / "output" / "sample_results"
CHART_PATH = ROOT / "output" / "charts"

CHART_PATH.mkdir(parents=True, exist_ok=True)

# Bar width in days. Matplotlib measures bar width in x-axis units, and
# the x-axis here is dates -- so the default of 0.8 renders as 0.8 days,
# roughly a hairline on a twelve-month axis.
BAR_WIDTH_DAYS = 20

COLORS = {
    "New": "#2E7D32",
    "Expansion": "#66BB6A",
    "Reactivation": "#9CCC65",
    "Contraction": "#EF9A9A",
    "Churn": "#C62828",
}

MOVEMENT_COLUMNS = [
    "new_mrr", "expansion_mrr", "reactivation_mrr",
    "contraction_mrr", "churn_mrr",
]


# ---------------------------------------------------------------
# Load
# ---------------------------------------------------------------

def load_from_duckdb():
    import duckdb

    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)

    segment = con.execute("select * from mart_revenue_growth").fetchdf()

    # mart_revenue_growth is segment-grain. The company view is that
    # rolled up, with the rate columns recomputed from the summed
    # components rather than averaged: averaging a ratio across segments
    # of different sizes gives the wrong answer.
    company = con.execute("""
        select
            month,
            sum(beginning_mrr)    as beginning_mrr,
            sum(ending_mrr)       as ending_mrr,
            sum(new_mrr)          as new_mrr,
            sum(expansion_mrr)    as expansion_mrr,
            sum(contraction_mrr)  as contraction_mrr,
            sum(churn_mrr)        as churn_mrr,
            sum(reactivation_mrr) as reactivation_mrr,
            (sum(beginning_mrr) - sum(contraction_mrr) - sum(churn_mrr))
                / nullif(sum(beginning_mrr), 0) as grr,
            (sum(beginning_mrr) + sum(expansion_mrr) + sum(reactivation_mrr)
                - sum(contraction_mrr) - sum(churn_mrr))
                / nullif(sum(beginning_mrr), 0) as nrr
        from mart_revenue_growth
        group by month
        order by month
    """).fetchdf()

    con.close()
    return company, segment, "DuckDB warehouse"


def load_from_csv():
    company = pd.read_csv(CSV_PATH / "01_company_revenue_growth.csv")
    segment = pd.read_csv(CSV_PATH / "02_segment_analysis.csv")
    return company, segment, "committed CSV extracts"


def load():
    if DUCKDB_PATH.exists():
        try:
            return load_from_duckdb()
        except Exception as exc:
            print(f"  Could not read warehouse ({exc}); using CSV extracts.")
    return load_from_csv()


# ---------------------------------------------------------------
# Prepare
# ---------------------------------------------------------------

def trim_to_active_period(company: pd.DataFrame) -> pd.DataFrame:
    """
    Drop trailing months with no movement at all.

    The month dimension runs past the last subscription change, so the
    final months carry a flat MRR and zero movement. Plotting them
    implies the business went quiet, when in fact the data simply ends.
    A chart should not assert something the data does not say.
    """
    has_movement = company[MOVEMENT_COLUMNS].abs().sum(axis=1) > 0
    if not has_movement.any():
        return company
    return company.loc[:company.index[has_movement].max()].copy()


def prepare(company: pd.DataFrame, segment: pd.DataFrame):
    company = company.copy()
    segment = segment.copy()

    company["month"] = pd.to_datetime(company["month"])
    segment["month"] = pd.to_datetime(segment["month"])

    company = company.sort_values("month").reset_index(drop=True)
    company = trim_to_active_period(company)

    segment = segment[segment["month"].isin(company["month"])]
    return company, segment


# ---------------------------------------------------------------
# Charts
# ---------------------------------------------------------------

def save(fig, name: str, data: pd.DataFrame) -> None:
    """Write the figure and the series behind it side by side."""
    fig.savefig(CHART_PATH / f"{name}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)
    data.to_csv(CHART_PATH / f"{name}.csv", index=False)
    print(f"  {name}.png  +  {name}.csv")


def chart_mrr_trend(company: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(10, 5))

    ax.plot(company["month"], company["ending_mrr"],
            marker="o", linewidth=2, color="#1F3A5F")

    for x, y in zip(company["month"], company["ending_mrr"]):
        ax.annotate(f"${y:,.0f}", (x, y), textcoords="offset points",
                    xytext=(0, 9), ha="center", fontsize=8)

    ax.set_title("Monthly Recurring Revenue", fontsize=14, fontweight="bold")
    ax.set_xlabel("Month")
    ax.set_ylabel("Ending MRR ($)")
    ax.grid(axis="y", alpha=0.3)
    ax.margins(y=0.15)
    fig.autofmt_xdate(rotation=45)
    fig.tight_layout()

    save(fig, "01_mrr_trend", company[["month", "ending_mrr"]])


def chart_mrr_movement(company: pd.DataFrame) -> None:
    """
    The MRR bridge: gains stacked above zero, losses below.

    Reading a single month top to bottom shows what drove the change,
    which is exactly what a total MRR line cannot tell you.

    The first month of the dataset is excluded. Its opening balance is
    zero, so every customer is classified as new and the bar is the size
    of the entire book -- an opening balance, not new business. Leaving
    it in compresses every subsequent month into an unreadable strip.
    """
    company = company[company["beginning_mrr"] > 0].reset_index(drop=True)

    fig, ax = plt.subplots(figsize=(11, 6))

    bottom = pd.Series(0.0, index=company.index)
    for column, label in [("new_mrr", "New"),
                          ("expansion_mrr", "Expansion"),
                          ("reactivation_mrr", "Reactivation")]:
        ax.bar(company["month"], company[column], bottom=bottom,
               label=label, width=BAR_WIDTH_DAYS, color=COLORS[label])
        bottom = bottom + company[column]

    bottom = pd.Series(0.0, index=company.index)
    for column, label in [("contraction_mrr", "Contraction"),
                          ("churn_mrr", "Churn")]:
        values = -company[column]
        ax.bar(company["month"], values, bottom=bottom,
               label=label, width=BAR_WIDTH_DAYS, color=COLORS[label])
        bottom = bottom + values

    # Net change line, so bars and trend can be read together
    net = company["ending_mrr"] - company["beginning_mrr"]
    ax.plot(company["month"], net, color="#1F3A5F", linewidth=1.8,
            marker="o", markersize=4, label="Net change")

    ax.axhline(0, linewidth=1, color="#333333")
    ax.set_title("Monthly MRR Movement", fontsize=14, fontweight="bold")
    ax.set_xlabel("Month")
    ax.set_ylabel("MRR Movement ($)")
    ax.legend(ncol=3, fontsize=9)
    ax.grid(axis="y", alpha=0.3)
    fig.autofmt_xdate(rotation=45)
    fig.tight_layout()

    out = company[["month"] + MOVEMENT_COLUMNS].copy()
    out["net_change"] = net
    save(fig, "02_mrr_movement", out)


def chart_retention_by_segment(segment: pd.DataFrame) -> None:
    """
    NRR by segment.

    Months where a segment had no opening MRR are excluded. NRR is a
    ratio to the opening base, so with an opening base of zero it is
    undefined, not zero. Plotting it as zero reads as a total retention
    collapse when the segment simply had no customers yet.
    """
    usable = segment[segment["beginning_mrr"] > 0].copy()
    usable["nrr_pct"] = usable["nrr"] * 100

    excluded = len(segment) - len(usable)
    if excluded:
        print(f"  ({excluded} segment-months excluded: no opening MRR, "
              f"so NRR is undefined)")

    fig, ax = plt.subplots(figsize=(10, 5))

    for name, group in usable.groupby("segment"):
        group = group.sort_values("month")
        ax.plot(group["month"], group["nrr_pct"],
                marker="o", linewidth=2, label=name)

    ax.axhline(100, linestyle="--", linewidth=1, color="#666666")

    # Flag months resting on a single customer. The ratio is correct but
    # not meaningful: one churn or one reactivation swings it to 0% or
    # past 150%, and reporting that as a segment trend invites a
    # conclusion the sample cannot support.
    if "beginning_customers" in usable.columns:
        thin = usable[usable["beginning_customers"] <= 1]
        if not thin.empty:
            ax.scatter(thin["month"], thin["nrr_pct"], s=140,
                       facecolors="none", edgecolors="#C62828",
                       linewidths=1.5, zorder=5,
                       label="based on 1 customer")
            print(f"  ({len(thin)} segment-months rest on a single "
                  f"customer and are ringed on the chart)")

    ax.set_title("Net Revenue Retention by Segment",
                 fontsize=14, fontweight="bold")
    ax.set_xlabel("Month")
    ax.set_ylabel("NRR (%)   —   100% means revenue held flat")
    ax.legend(title="Segment")
    ax.grid(axis="y", alpha=0.3)
    fig.autofmt_xdate(rotation=45)
    fig.tight_layout()

    save(fig, "03_nrr_by_segment",
         usable[["month", "segment", "beginning_mrr", "ending_mrr",
                 "beginning_customers", "nrr"]]
         if "beginning_customers" in usable.columns
         else usable[["month", "segment", "beginning_mrr", "ending_mrr", "nrr"]])


def chart_grr_vs_nrr(company: pd.DataFrame) -> None:
    """
    GRR and NRR at company level.

    The shaded gap between them is the contribution of expansion and
    reactivation. GRR cannot exceed 100% by construction; NRR above 100%
    means the existing base grew without any new customers at all.
    """
    usable = company[company["beginning_mrr"] > 0]

    fig, ax = plt.subplots(figsize=(10, 5))

    ax.plot(usable["month"], usable["grr"] * 100, marker="o",
            linewidth=2, label="GRR", color="#C62828")
    ax.plot(usable["month"], usable["nrr"] * 100, marker="o",
            linewidth=2, label="NRR", color="#2E7D32")
    ax.fill_between(usable["month"], usable["grr"] * 100,
                    usable["nrr"] * 100, alpha=0.15, color="#66BB6A")

    ax.axhline(100, linestyle="--", linewidth=1, color="#666666")
    ax.set_title("Gross vs Net Revenue Retention",
                 fontsize=14, fontweight="bold")
    ax.set_xlabel("Month")
    ax.set_ylabel("Retention (%)")
    ax.legend()
    ax.grid(axis="y", alpha=0.3)
    fig.autofmt_xdate(rotation=45)
    fig.tight_layout()

    save(fig, "04_grr_vs_nrr", usable[["month", "grr", "nrr"]])


# ---------------------------------------------------------------

def main() -> None:
    company, segment, source = load()
    company, segment = prepare(company, segment)

    print(f"Source: {source}")
    print(f"Window: {company['month'].min():%Y-%m} to "
          f"{company['month'].max():%Y-%m} "
          f"({len(company)} months with activity)")
    print()

    chart_mrr_trend(company)
    chart_mrr_movement(company)
    chart_retention_by_segment(segment)
    chart_grr_vs_nrr(company)

    print()
    print("Charts written to output/charts/")


if __name__ == "__main__":
    main()
