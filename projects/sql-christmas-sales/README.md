# Christmas Sales Analysis (SQL)

## Overview
This project investigates a revenue and profit decline across three Christmas seasons (2019–2020 baseline, 2020–2021 decline, 2021–2022 recovery) at a supermarket, identifying which customer segments, channels, and product categories drove the drop and recommending where to focus follow-up analysis.

## Dataset
- Multi-year retail sales data, restricted to Christmas seasons (Nov–Jan, 2018–2022)
- Revenue, quantity, cost, and profit per row, plus channel, geography, demographics, product, and payment method
- Filtered to complete seasons only (all three of Nov/Dec/Jan present) — an incomplete season is dropped automatically, not by a hardcoded date cutoff

## Skills Used
- SQL Server / T-SQL (CTEs, views, FULL OUTER JOIN segment comparisons across periods)
- Season-over-season decomposition of revenue (record count × average value, units × price)
- Data quality auditing (missing values, duplicates, revenue = cost + profit reconciliation, NULLIF handling to distinguish "no data" from "zero")
- Business diagnosis: isolating a demand-side driver from cost, pricing, and channel explanations

## Key Findings

### Revenue Trends
- Revenue fell 3.2% from baseline to decline ($7.18M → $6.95M), and recovered only partway in 2021–2022 ($7.09M, still -1.3% vs. baseline)
- Transaction volume was essentially flat (+1.0%) — the drop was not caused by fewer shopping visits
- Average spend per transaction fell 4.1%, driven mainly by fewer units per basket (-3.7%), not lower prices (revenue per unit -0.4%)

### Profitability
- Profit fell in near lockstep with revenue (-3.2%), and profit margin barely moved (76.9% → 76.9%, -0.04pt)
- Cost per unit was flat to slightly down — this points to a sales-volume/basket-size problem, not a cost or margin problem
- Clothing (-16.9% profit) and Wearable Tech (-26.3% profit) were the hardest-hit product categories

### Customer Behavior
- Adults (18+) alone lost $352,695 in revenue (-15.2%) — more than the entire company-wide decline — while the 1–11 age group actually grew (+4.8%)
- The adult pullback hit every purchase channel (in-store, Xmas Market, online), ruling out a single-channel cause
- Electronic payment methods (PayPal, debit, credit) all declined; cash was the only payment method that grew

### Channel Performance
- In-store dipped 4.3% then fully recovered past baseline by 2021–2022 (+8.3%)
- Xmas Market declined in both seasons in a row — a structural weakening, not a one-off dip
- Online grew during the decline season (+2.4%) then dropped sharply in recovery (-14.2%) — the one pattern that looks like an anomaly rather than a steady trend

## Recommendations
Each next step is scoped to end in a specific business decision, not just an observation:
- **Product-level basket audit** (extend the product/category queries to compare units and revenue per unit for adult-skewing categories, decline vs. baseline) — tells the company whether to respond with a promotion, an assortment change, or a lower-priced tier aimed at adult shoppers specifically.
- **Xmas Market channel review** (repeat the age-group/channel breakdown filtered to that channel alone) — decides whether Xmas Market needs its own standalone recovery plan or can be folded into the adult-basket fix above.
- **Online timing check** (cross-reference the season/month/hour breakdown against known delivery, pricing, or site changes between the decline and recovery seasons) — decides whether online needs a service/delivery fix or the spike-then-drop was a one-off, not a trend to act on.
- **Cost-field confirmation with the data owner** — required before recommending that any channel or category get more or less investment based on profit margin, since margin here may only reflect cost of goods sold.
- **Re-run the transaction-grain check if an order ID is ever added to the data** — settles whether the company's fix should target getting more shoppers in the door or getting existing shoppers to buy more, rather than assuming the latter from row counts alone.

## Data Quality
- 0 missing values, 0 duplicate rows, 0 revenue/cost/profit mismatches, 0 negative values — verified against the live dataset
- No order/transaction ID column exists in the source table, so every "count" measure is a row count (`record_count`), not a confirmed distinct-transaction count — documented as an open assumption directly in the script

## Files
- [View SQL Code (GitHub)](https://github.com/linhnguye237/linh-nguyen-portfolio/blob/main/projects/sql-christmas-sales/xmas.sql)
- [View Full Project Files (Google Drive)](https://drive.google.com/drive/folders/1bZH80KmytQOLrjyaxHRqpO0gJxp-ibDI)

## Status
Completed
