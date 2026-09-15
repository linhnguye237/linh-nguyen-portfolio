/* -- Capstone Project: Xmas Gift Sales Analysis
Student: Nguyen Khanh Linh
Data Source: FP20Analytics Challenge 12
-- */

USE fp20c12
GO

/* =====================================================================================================
CONVENTIONS USED THROUGHOUT THIS SCRIPT
- Every question is built on dbo.v_xmas_sales (defined once, below) so preparation logic is not repeated.
- "Baseline" = 2019-2020, "decline" = 2020-2021, "recovery" = 2021-2022. These three seasons are defined
  once in dbo.v_season_roles and re-used everywhere a query needs to compare specific periods, instead of
  each query independently picking "the most recent season".
- Percentages are stored as proportions, not already-multiplied percentages: 0.032 means 3.2%.
- Any ratio that can divide by zero is wrapped in NULLIF(denominator, 0), so an undefined ratio returns
  NULL (unavailable) rather than erroring out or silently reading as an actual zero.
- Weekday numbering/labeling is computed with DATEDIFF(DAY, 0, [date]) % 7, which does NOT depend on the
  session's DATEFIRST setting or language pack, so results are identical for every teammate. SET DATEFIRST
  is still pinned below as a defensive default for any other date logic.
- Row grain: confirmed via Section 0a (run 2026-09-15) - dbo.xmas_sales has no order/transaction id column,
  so there is no way to distinguish "one row per line item" from "one row per completed transaction".
  Measures that would normally be called "transaction count" are therefore labeled record_count and built
  from COUNT(*), which is the only count available. If an id column is added later, replace every COUNT(*)
  marked "-- GRAIN" below with COUNT(DISTINCT <order_id_column>) and rename record_count -> transaction_count.
- Verified end-to-end against fp20c12 on 2026-09-15: every statement in this file (Section 0's checks, both
  views, Q1-Q10, and Tasks 2/4/5/6) ran with zero errors and zero warnings, and the Task 6 reconciliation
  check returned a reconciliation_gap of 0.00 for baseline, decline, and recovery. Re-run that check after
  any further edits to this file.
===================================================================================================== */

SET DATEFIRST 7;
GO

/* =====================================================================================================
SECTION 0: DATA QUALITY & GRAIN CHECKS
Run this before trusting any measure below. Task 2's transaction-count logic and Task 6's reliability
checks both depend on these results.
===================================================================================================== */

-- 0a. Column inventory - confirm column names/types, and look for an order/transaction id column.
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'xmas_sales'
ORDER BY ORDINAL_POSITION;

-- 0b. Row grain probe. Ran 0a against fp20c12.dbo.xmas_sales on 2026-09-15: its 19 columns are
--     date, time, customer_age_range, product_type, product_category, product_name, purchase_type,
--     country, city, gender, xmas_budget, payment_method, quantity, unit_price, tax_amount, unit_cost,
--     cost, total_sales, profit - no order_id/transaction_id/invoice_id column of any kind.
--     There is therefore no way to tell whether a row is a full transaction or a line item within one;
--     COUNT(*) is the only count available, so every measure below is labeled record_count, not
--     transaction_count/order_count. If an id column is added to the table later, redo this probe:
--     SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_ids FROM dbo.xmas_sales;
--     total_rows = distinct_ids -> COUNT(*) is still correct. distinct_ids < total_rows -> switch every
--     COUNT(*) marked "-- GRAIN" to COUNT(DISTINCT order_id) and rename record_count -> transaction_count.

-- 0c. Missing values on fields every downstream query depends on.
SELECT
    SUM(CASE WHEN [date] IS NULL THEN 1 ELSE 0 END)          AS missing_date,
    SUM(CASE WHEN [time] IS NULL THEN 1 ELSE 0 END)          AS missing_time,
    SUM(CASE WHEN total_sales IS NULL THEN 1 ELSE 0 END)     AS missing_total_sales,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END)        AS missing_quantity,
    SUM(CASE WHEN cost IS NULL THEN 1 ELSE 0 END)            AS missing_cost,
    SUM(CASE WHEN profit IS NULL THEN 1 ELSE 0 END)          AS missing_profit,
    SUM(CASE WHEN purchase_type IS NULL THEN 1 ELSE 0 END)   AS missing_purchase_type,
    SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END)  AS missing_payment_method,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END)         AS missing_country,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END)            AS missing_city,
    SUM(CASE WHEN customer_age_range IS NULL THEN 1 ELSE 0 END) AS missing_age_range,
    SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END)          AS missing_gender,
    SUM(CASE WHEN product_category IS NULL THEN 1 ELSE 0 END) AS missing_product_category,
    SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END)    AS missing_product_name,
    SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END)      AS missing_unit_price
FROM dbo.xmas_sales;

-- 0d. Suspicious duplicate rows: identical on every business column.
;WITH dups AS (
    SELECT
        [date], [time], country, city, customer_age_range, gender, purchase_type,
        payment_method, product_category, product_name, unit_price, quantity,
        total_sales, cost, profit,
        COUNT(*) AS dup_count
    FROM dbo.xmas_sales
    GROUP BY [date], [time], country, city, customer_age_range, gender, purchase_type,
             payment_method, product_category, product_name, unit_price, quantity,
             total_sales, cost, profit
    HAVING COUNT(*) > 1
)
SELECT * FROM dups ORDER BY dup_count DESC;

-- 0e. Date coverage - which months of which years actually have data. Used to sanity-check the
--     complete-season filter built into dbo.v_xmas_sales below.
SELECT YEAR([date]) AS [year], MONTH([date]) AS [month], COUNT(*) AS row_count,
       MIN([date]) AS first_date, MAX([date]) AS last_date
FROM dbo.xmas_sales
GROUP BY YEAR([date]), MONTH([date])
ORDER BY [year], [month];

-- 0f. Does recorded profit agree with revenue minus cost?
SELECT COUNT(*) AS mismatched_rows
FROM dbo.xmas_sales
WHERE ABS(total_sales - (cost + profit)) > 0.01;

-- 0g. Negative-value inspection - decide whether these are data errors or legitimate returns/refunds.
SELECT 'total_sales' AS field, COUNT(*) AS negative_count FROM dbo.xmas_sales WHERE total_sales < 0
UNION ALL SELECT 'quantity',   COUNT(*) FROM dbo.xmas_sales WHERE quantity < 0
UNION ALL SELECT 'cost',       COUNT(*) FROM dbo.xmas_sales WHERE cost < 0
UNION ALL SELECT 'profit',     COUNT(*) FROM dbo.xmas_sales WHERE profit < 0
UNION ALL SELECT 'unit_price', COUNT(*) FROM dbo.xmas_sales WHERE unit_price < 0;

/* =====================================================================================================
SECTION 0.5: SHARED PREPARATION (Task 1)
dbo.v_xmas_sales - single source of truth for season tagging, restricted to Nov/Dec/Jan, and restricted
to seasons that actually have all three months present (so a season stays excluded automatically if new
data still leaves it incomplete - not just a hardcoded '2018-01-31' cutoff).
===================================================================================================== */

GO
CREATE OR ALTER VIEW dbo.v_xmas_sales AS
WITH tagged AS (
    SELECT
        -- January belongs to the Christmas season that started the previous November.
        CASE WHEN MONTH([date]) = 1 THEN YEAR([date]) - 1 ELSE YEAR([date]) END AS xmas_year,
        CASE
            WHEN MONTH([date]) = 1 THEN CONCAT(YEAR([date]) - 1, '-', YEAR([date]))
            ELSE CONCAT(YEAR([date]), '-', YEAR([date]) + 1)
        END AS xmas_season,

        YEAR([date])  AS [year],
        MONTH([date]) AS [month],
        EOMONTH([date]) AS end_date_of_month,

        -- DATEFIRST-independent weekday: day 0 (1900-01-01) was a Monday, so this formula is stable
        -- regardless of session/language settings.
        ((DATEDIFF(DAY, 0, [date]) % 7) + 7) % 7 AS weekday_num,
        CASE ((DATEDIFF(DAY, 0, [date]) % 7) + 7) % 7
            WHEN 0 THEN 'Monday'
            WHEN 1 THEN 'Tuesday'
            WHEN 2 THEN 'Wednesday'
            WHEN 3 THEN 'Thursday'
            WHEN 4 THEN 'Friday'
            WHEN 5 THEN 'Saturday'
            WHEN 6 THEN 'Sunday'
        END AS weekday_name,

        DATEPART(HOUR, [time]) AS [hour],

        s.*
    FROM dbo.xmas_sales s
    WHERE MONTH([date]) IN (11, 12, 1)   -- restrict analysis to Nov/Dec/Jan only
),
season_coverage AS (
    -- A season only counts as complete once it has data in all three of its months.
    SELECT xmas_season, COUNT(DISTINCT [month]) AS months_present
    FROM tagged
    GROUP BY xmas_season
)
SELECT t.*
FROM tagged t
JOIN season_coverage sc
    ON sc.xmas_season = t.xmas_season
   AND sc.months_present = 3;
GO

-- dbo.v_season_roles - the single definition of baseline / decline / recovery, used by every
-- period-comparison query below instead of each query picking MAX(xmas_year) independently.
CREATE OR ALTER VIEW dbo.v_season_roles AS
SELECT 2019 AS xmas_year, '2019-2020' AS xmas_season, 'baseline'  AS season_role, 1 AS season_order
UNION ALL
SELECT 2020, '2020-2021', 'decline',  2
UNION ALL
SELECT 2021, '2021-2022', 'recovery', 3;
GO

/* -----------------------------------------------------------------------------------------------------------------
Question 1: Retrieve sales information including revenue, quantity sold, cost, and profit for each Christmas season.
- Round revenue, cost, and profit to millions of dollars (2 decimal places)
- Round quantity to thousands (1 decimal place)
Now built directly on dbo.v_xmas_sales instead of repeating its preparation logic.
*/

WITH s AS (
    SELECT
        xmas_year,
        xmas_season,
        SUM(total_sales) AS sales,
        SUM(quantity) AS quantity,
        SUM(cost) AS cost,
        SUM(profit) AS profit
    FROM dbo.v_xmas_sales
    GROUP BY xmas_year, xmas_season
)

SELECT
    xmas_year,
    xmas_season,
    ROUND(sales / POWER(10, 6), 2) AS sales,
    ROUND(quantity * 1.0 / POWER(10, 3), 1) AS quantity,
    ROUND(cost / POWER(10, 6), 2) AS cost,
    ROUND(profit / POWER(10, 6), 2) AS profit
FROM s
ORDER BY xmas_year;

/* -----------------------------------------------------------------------------------------------------------------
Question 2: Growth of revenue, quantity, and profit across the three seasons under investigation.
Previously this compared "the most recent season" to the one before it, which silently moves as new data
arrives and can drift away from the 2020-2021 decline being investigated. It now always compares the fixed
baseline (2019-2020) -> decline (2020-2021) -> recovery (2021-2022) seasons via dbo.v_season_roles.
*/

WITH s AS (
    SELECT
        sr.season_role,
        sr.season_order,
        v.xmas_year,
        v.xmas_season,
        SUM(v.total_sales) AS sales,
        SUM(v.quantity) AS quantity,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.xmas_year, v.xmas_season
),
r AS (
    SELECT
        s.season_role, s.season_order, s.xmas_year, s.xmas_season,
        s.sales, prev.sales AS sales_prev_season,
        (s.sales - prev.sales) / NULLIF(prev.sales, 0) AS sales_growth_pct,

        s.quantity, prev.quantity AS quantity_prev_season,
        (s.quantity - prev.quantity) * 1.0 / NULLIF(prev.quantity, 0) AS quantity_growth_pct,

        s.profit, prev.profit AS profit_prev_season,
        (s.profit - prev.profit) / NULLIF(prev.profit, 0) AS profit_growth_pct
    FROM s
    LEFT JOIN s prev ON prev.season_order = s.season_order - 1
)

SELECT
    season_role, xmas_year, xmas_season,

    ROUND(sales / POWER(10, 6), 2) AS sales,
    ROUND(sales_prev_season / POWER(10, 6), 2) AS sales_prev_season,
    ROUND(sales_growth_pct, 4) AS sales_growth_pct,

    ROUND(quantity / POWER(10, 3), 1) AS quantity,
    ROUND(quantity_prev_season / POWER(10, 3), 1) AS quantity_prev_season,
    ROUND(quantity_growth_pct, 4) AS quantity_growth_pct,

    ROUND(profit / POWER(10, 6), 2) AS profit,
    ROUND(profit_prev_season / POWER(10, 6), 2) AS profit_prev_season,
    ROUND(profit_growth_pct, 4) AS profit_growth_pct

FROM r
ORDER BY season_order;

/* -----------------------------------------------------------------------------------------------------------------
Question 3: Percentage growth of revenue for every Christmas season present (full history, for context -
not restricted to baseline/decline/recovery, since this is the broad trend line rather than a period
comparison).
*/

WITH s AS (
    SELECT
        xmas_year,
        xmas_season,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY xmas_year, xmas_season
)

SELECT
    s.xmas_year,
    s.xmas_season,
    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(prev.sales / POWER(10, 6), 2) AS sales_prev_season,
    ROUND((s.sales - prev.sales) / NULLIF(prev.sales, 0), 4) AS growth_yoy
FROM s s
LEFT JOIN s prev
    ON s.xmas_year = prev.xmas_year + 1
ORDER BY s.xmas_year;

/* =====================================================================================================
TASK 2: WHAT EXPLAINS THE REVENUE AND PROFIT DECLINE?
record_count, avg_value_per_record, units_per_record, revenue_per_unit, profit_per_record and
profit_margin for baseline / decline / recovery, with period-over-period changes, so the report's
"customers spent less per purchase" style conclusions are directly reproducible from this query.
Identities this table lets you verify by eye:
  revenue = record_count x avg_value_per_record
  avg_value_per_record = units_per_record x revenue_per_unit
===================================================================================================== */

WITH season_metrics AS (
    SELECT
        sr.season_role,
        sr.season_order,
        v.xmas_year,
        v.xmas_season,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue,
        SUM(v.quantity) AS quantity,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.xmas_year, v.xmas_season
),
derived AS (
    SELECT
        *,
        revenue * 1.0 / NULLIF(record_count, 0) AS avg_value_per_record,
        quantity * 1.0 / NULLIF(record_count, 0) AS units_per_record,
        revenue * 1.0 / NULLIF(quantity, 0)      AS revenue_per_unit,
        profit  * 1.0 / NULLIF(record_count, 0)  AS profit_per_record,
        profit  * 1.0 / NULLIF(revenue, 0)       AS profit_margin
    FROM season_metrics
)

SELECT
    d.season_role, d.xmas_year, d.xmas_season,

    d.record_count,
    d.record_count - prev.record_count AS record_count_change,
    (d.record_count - prev.record_count) * 1.0 / NULLIF(prev.record_count, 0) AS record_count_pct_change,

    ROUND(d.avg_value_per_record, 2) AS avg_value_per_record,
    ROUND(d.avg_value_per_record - prev.avg_value_per_record, 2) AS avg_value_per_record_change,
    (d.avg_value_per_record - prev.avg_value_per_record) / NULLIF(prev.avg_value_per_record, 0) AS avg_value_per_record_pct_change,

    ROUND(d.units_per_record, 3) AS units_per_record,
    (d.units_per_record - prev.units_per_record) / NULLIF(prev.units_per_record, 0) AS units_per_record_pct_change,

    ROUND(d.revenue_per_unit, 2) AS revenue_per_unit,
    (d.revenue_per_unit - prev.revenue_per_unit) / NULLIF(prev.revenue_per_unit, 0) AS revenue_per_unit_pct_change,

    ROUND(d.profit_per_record, 2) AS profit_per_record,
    (d.profit_per_record - prev.profit_per_record) / NULLIF(prev.profit_per_record, 0) AS profit_per_record_pct_change,

    ROUND(d.profit_margin, 4) AS profit_margin,
    d.profit_margin - prev.profit_margin AS profit_margin_change_pts

FROM derived d
LEFT JOIN derived prev ON prev.season_order = d.season_order - 1
ORDER BY d.season_order;

/* =====================================================================================================
TASK 3: SEASONAL SEGMENT COMPARISONS (baseline -> decline -> recovery)
Reusable shape used from here on: aggregate by (segment, season_role), then FULL OUTER JOIN the three
season slices back together on the segment key (via COALESCE) so a segment that only exists in one or two
of the three seasons is still shown - its loss (or appearance) is not silently dropped by an inner join.
Segments are ranked by absolute revenue lost as well as by percentage decline, and growing segments are
kept in the same result set as declining ones.
===================================================================================================== */

-- ---------------------------------------------------------------------------------------------------
-- Question 4: Channels (purchase_type) - seasonal comparison
-- ---------------------------------------------------------------------------------------------------
WITH agg AS (
    SELECT
        sr.season_role, sr.season_order,
        v.purchase_type,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue,
        SUM(v.quantity) AS quantity,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.purchase_type
),
m AS (
    SELECT *,
        revenue * 1.0 / NULLIF(record_count, 0) AS avg_value_per_record,
        quantity * 1.0 / NULLIF(record_count, 0) AS units_per_record,
        profit  * 1.0 / NULLIF(revenue, 0)       AS profit_margin
    FROM agg
),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline'),
r AS (SELECT * FROM m WHERE season_role = 'recovery')

SELECT
    COALESCE(b.purchase_type, d.purchase_type, r.purchase_type) AS purchase_type,

    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(r.revenue / POWER(10, 6), 3) AS recovery_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost_decline_vs_baseline,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change_decline_vs_baseline,
    ROUND(ISNULL(r.revenue, 0) - ISNULL(d.revenue, 0), 2) AS revenue_change_recovery_vs_decline,
    (ISNULL(r.revenue, 0) - d.revenue) / NULLIF(d.revenue, 0) AS revenue_pct_change_recovery_vs_decline,

    b.record_count AS baseline_record_count, d.record_count AS decline_record_count, r.record_count AS recovery_record_count,
    (ISNULL(d.record_count, 0) - b.record_count) * 1.0 / NULLIF(b.record_count, 0) AS record_count_pct_change_decline_vs_baseline,

    ROUND(b.avg_value_per_record, 2) AS baseline_avg_value_per_record,
    ROUND(d.avg_value_per_record, 2) AS decline_avg_value_per_record,
    ROUND(r.avg_value_per_record, 2) AS recovery_avg_value_per_record,
    (ISNULL(d.avg_value_per_record, 0) - b.avg_value_per_record) / NULLIF(b.avg_value_per_record, 0) AS avg_value_per_record_pct_change_decline_vs_baseline,

    ROUND(b.units_per_record, 3) AS baseline_units_per_record,
    ROUND(d.units_per_record, 3) AS decline_units_per_record,
    ROUND(r.units_per_record, 3) AS recovery_units_per_record,

    ROUND(b.profit, 2) AS baseline_profit, ROUND(d.profit, 2) AS decline_profit, ROUND(r.profit, 2) AS recovery_profit,
    ROUND(ISNULL(d.profit, 0) - ISNULL(b.profit, 0), 2) AS profit_lost_decline_vs_baseline,

    ROUND(b.profit_margin, 4) AS baseline_profit_margin,
    ROUND(d.profit_margin, 4) AS decline_profit_margin,
    ROUND(r.profit_margin, 4) AS recovery_profit_margin

FROM b
FULL OUTER JOIN d ON d.purchase_type = b.purchase_type
FULL OUTER JOIN r ON r.purchase_type = COALESCE(d.purchase_type, b.purchase_type)
ORDER BY revenue_lost_decline_vs_baseline ASC;   -- most revenue lost first; growing channels sort to the bottom

/* -----------------------------------------------------------------------------------------------------------------
Question 5: Revenue by country and city - overall, for context (full history, all seasons).
*/
SELECT
    country,
    ROUND(SUM(total_sales) / POWER(10, 6), 2) AS sales
FROM dbo.v_xmas_sales
GROUP BY country
ORDER BY sales DESC;

SELECT
    country,
    city,
    ROUND(SUM(total_sales) / POWER(10, 6), 2) AS sales
FROM dbo.v_xmas_sales
GROUP BY country, city
ORDER BY country, sales DESC;

/* -----------------------------------------------------------------------------------------------------------------
Question 6: Geography - decline (2020-2021 vs 2019-2020) ranked by revenue lost, recovery analyzed separately.
*/
-- 6a. Countries: decline vs baseline, ranked by absolute revenue lost (with pct change alongside).
WITH agg AS (
    SELECT sr.season_role, v.country, SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.country
),
b AS (SELECT * FROM agg WHERE season_role = 'baseline'),
d AS (SELECT * FROM agg WHERE season_role = 'decline')

SELECT
    COALESCE(b.country, d.country) AS country,
    ROUND(ISNULL(b.revenue, 0) / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(ISNULL(d.revenue, 0) / POWER(10, 6), 3) AS decline_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change
FROM b
FULL OUTER JOIN d ON d.country = b.country
ORDER BY revenue_lost ASC;

-- 6b. Cities: decline vs baseline, ranked by absolute revenue lost.
WITH agg AS (
    SELECT sr.season_role, v.country, v.city, SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.country, v.city
),
b AS (SELECT * FROM agg WHERE season_role = 'baseline'),
d AS (SELECT * FROM agg WHERE season_role = 'decline')

SELECT
    COALESCE(b.country, d.country) AS country,
    COALESCE(b.city, d.city) AS city,
    ROUND(ISNULL(b.revenue, 0) / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(ISNULL(d.revenue, 0) / POWER(10, 6), 3) AS decline_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change
FROM b
FULL OUTER JOIN d ON d.country = b.country AND d.city = b.city
ORDER BY revenue_lost ASC;

-- 6c. Recovery analyzed separately: countries, 2021-2022 vs 2020-2021.
WITH agg AS (
    SELECT sr.season_role, v.country, SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('decline', 'recovery')
    GROUP BY sr.season_role, v.country
),
d AS (SELECT * FROM agg WHERE season_role = 'decline'),
r AS (SELECT * FROM agg WHERE season_role = 'recovery')

SELECT
    COALESCE(d.country, r.country) AS country,
    ROUND(ISNULL(d.revenue, 0) / POWER(10, 6), 3) AS decline_revenue,
    ROUND(ISNULL(r.revenue, 0) / POWER(10, 6), 3) AS recovery_revenue,
    ROUND(ISNULL(r.revenue, 0) - ISNULL(d.revenue, 0), 2) AS revenue_recovered,
    (ISNULL(r.revenue, 0) - d.revenue) / NULLIF(d.revenue, 0) AS revenue_pct_change
FROM d
FULL OUTER JOIN r ON r.country = d.country
ORDER BY revenue_recovered DESC;

/* -----------------------------------------------------------------------------------------------------------------
Question 7: Customers and payments - age group, gender, payment method, compared across baseline/decline/recovery
using revenue, record_count, and avg_value_per_record.
*/
-- 7a. Age group
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.customer_age_range,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.customer_age_range
),
m AS (SELECT *, revenue * 1.0 / NULLIF(record_count, 0) AS avg_value_per_record FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline'),
r AS (SELECT * FROM m WHERE season_role = 'recovery')

SELECT
    COALESCE(b.customer_age_range, d.customer_age_range, r.customer_age_range) AS customer_age_range,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(r.revenue / POWER(10, 6), 3) AS recovery_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost_decline_vs_baseline,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change_decline_vs_baseline,
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count, r.record_count AS recovery_record_count,
    ROUND(b.avg_value_per_record, 2) AS baseline_avg_value_per_record,
    ROUND(d.avg_value_per_record, 2) AS decline_avg_value_per_record,
    ROUND(r.avg_value_per_record, 2) AS recovery_avg_value_per_record,
    (ISNULL(d.avg_value_per_record, 0) - b.avg_value_per_record) / NULLIF(b.avg_value_per_record, 0) AS avg_value_per_record_pct_change_decline_vs_baseline
FROM b
FULL OUTER JOIN d ON d.customer_age_range = b.customer_age_range
FULL OUTER JOIN r ON r.customer_age_range = COALESCE(d.customer_age_range, b.customer_age_range)
ORDER BY revenue_lost_decline_vs_baseline ASC;

-- 7b. Gender
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.gender,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.gender
),
m AS (SELECT *, revenue * 1.0 / NULLIF(record_count, 0) AS avg_value_per_record FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline'),
r AS (SELECT * FROM m WHERE season_role = 'recovery')

SELECT
    COALESCE(b.gender, d.gender, r.gender) AS gender,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(r.revenue / POWER(10, 6), 3) AS recovery_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost_decline_vs_baseline,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change_decline_vs_baseline,
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count, r.record_count AS recovery_record_count,
    ROUND(b.avg_value_per_record, 2) AS baseline_avg_value_per_record,
    ROUND(d.avg_value_per_record, 2) AS decline_avg_value_per_record,
    ROUND(r.avg_value_per_record, 2) AS recovery_avg_value_per_record,
    (ISNULL(d.avg_value_per_record, 0) - b.avg_value_per_record) / NULLIF(b.avg_value_per_record, 0) AS avg_value_per_record_pct_change_decline_vs_baseline
FROM b
FULL OUTER JOIN d ON d.gender = b.gender
FULL OUTER JOIN r ON r.gender = COALESCE(d.gender, b.gender)
ORDER BY gender;

-- 7c. Payment method
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.payment_method,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.payment_method
),
m AS (SELECT *, revenue * 1.0 / NULLIF(record_count, 0) AS avg_value_per_record FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline'),
r AS (SELECT * FROM m WHERE season_role = 'recovery')

SELECT
    COALESCE(b.payment_method, d.payment_method, r.payment_method) AS payment_method,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(r.revenue / POWER(10, 6), 3) AS recovery_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost_decline_vs_baseline,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change_decline_vs_baseline,
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count, r.record_count AS recovery_record_count,
    ROUND(b.avg_value_per_record, 2) AS baseline_avg_value_per_record,
    ROUND(d.avg_value_per_record, 2) AS decline_avg_value_per_record,
    ROUND(r.avg_value_per_record, 2) AS recovery_avg_value_per_record,
    (ISNULL(d.avg_value_per_record, 0) - b.avg_value_per_record) / NULLIF(b.avg_value_per_record, 0) AS avg_value_per_record_pct_change_decline_vs_baseline
FROM b
FULL OUTER JOIN d ON d.payment_method = b.payment_method
FULL OUTER JOIN r ON r.payment_method = COALESCE(d.payment_method, b.payment_method)
ORDER BY revenue_lost_decline_vs_baseline ASC;

/* -----------------------------------------------------------------------------------------------------------------
Question 8: Revenue share by purchase type / payment method within each age group, calculated separately
for each season (baseline/decline/recovery) instead of pooling all history together.
*/
-- 8a. Purchase type within age group, per season
WITH t AS (
    SELECT sr.season_role, sr.season_order, v.customer_age_range, SUM(v.total_sales) AS sales
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.customer_age_range
),
s AS (
    SELECT sr.season_role, sr.season_order, v.customer_age_range, v.purchase_type, SUM(v.total_sales) AS sales
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.customer_age_range, v.purchase_type
)

SELECT
    s.season_role,
    s.customer_age_range,
    s.purchase_type,
    ROUND(s.sales / POWER(10, 6), 3) AS sales,
    ROUND(t.sales / POWER(10, 6), 3) AS total_sales,
    ROUND(s.sales / NULLIF(t.sales, 0), 3) AS sales_proportion
FROM s
JOIN t ON t.season_role = s.season_role AND t.customer_age_range = s.customer_age_range
ORDER BY s.season_order, s.customer_age_range, s.purchase_type;

-- 8b. Payment method within age group, per season
WITH t AS (
    SELECT sr.season_role, sr.season_order, v.customer_age_range, SUM(v.total_sales) AS sales
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.customer_age_range
),
s AS (
    SELECT sr.season_role, sr.season_order, v.customer_age_range, v.payment_method, SUM(v.total_sales) AS sales
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.customer_age_range, v.payment_method
)

SELECT
    s.season_role,
    s.customer_age_range,
    s.payment_method,
    ROUND(s.sales / POWER(10, 6), 3) AS sales,
    ROUND(t.sales / POWER(10, 6), 3) AS total_sales,
    ROUND(s.sales / NULLIF(t.sales, 0), 3) AS sales_proportion
FROM s
JOIN t ON t.season_role = s.season_role AND t.customer_age_range = s.customer_age_range
ORDER BY s.season_order, s.customer_age_range, s.payment_method;

/* -----------------------------------------------------------------------------------------------------------------
Question 9: Products - category and product level, compared across baseline/decline/recovery.
revenue_per_unit (= total revenue / total quantity, what the business actually earned per item sold) is
reported alongside AVG(unit_price) (the average listed/recorded price per row) - they answer different
questions: mix-and-volume-weighted realized revenue vs. a simple average of recorded prices.
*/
-- 9a. Product category
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.product_category,
        SUM(v.total_sales) AS revenue,
        SUM(v.quantity) AS quantity,
        AVG(v.unit_price) AS avg_unit_price,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.product_category
),
m AS (
    SELECT *,
        revenue * 1.0 / NULLIF(quantity, 0) AS revenue_per_unit,
        profit  * 1.0 / NULLIF(revenue, 0)  AS profit_margin
    FROM agg
),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline'),
r AS (SELECT * FROM m WHERE season_role = 'recovery')

SELECT
    COALESCE(b.product_category, d.product_category, r.product_category) AS product_category,

    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(r.revenue / POWER(10, 6), 3) AS recovery_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost_decline_vs_baseline,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change_decline_vs_baseline,

    b.quantity AS baseline_quantity, d.quantity AS decline_quantity, r.quantity AS recovery_quantity,
    (ISNULL(d.quantity, 0) - b.quantity) * 1.0 / NULLIF(b.quantity, 0) AS quantity_pct_change_decline_vs_baseline,

    ROUND(b.revenue_per_unit, 2) AS baseline_revenue_per_unit,
    ROUND(d.revenue_per_unit, 2) AS decline_revenue_per_unit,
    ROUND(r.revenue_per_unit, 2) AS recovery_revenue_per_unit,

    ROUND(b.avg_unit_price, 2) AS baseline_avg_unit_price,
    ROUND(d.avg_unit_price, 2) AS decline_avg_unit_price,
    ROUND(r.avg_unit_price, 2) AS recovery_avg_unit_price,

    ROUND(b.profit, 2) AS baseline_profit, ROUND(d.profit, 2) AS decline_profit, ROUND(r.profit, 2) AS recovery_profit,
    ROUND(b.profit_margin, 4) AS baseline_profit_margin,
    ROUND(d.profit_margin, 4) AS decline_profit_margin,
    ROUND(r.profit_margin, 4) AS recovery_profit_margin

FROM b
FULL OUTER JOIN d ON d.product_category = b.product_category
FULL OUTER JOIN r ON r.product_category = COALESCE(d.product_category, b.product_category)
ORDER BY revenue_lost_decline_vs_baseline ASC;

-- 9b. Individual product
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.product_category, v.product_name,
        SUM(v.total_sales) AS revenue,
        SUM(v.quantity) AS quantity,
        AVG(v.unit_price) AS avg_unit_price,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.product_category, v.product_name
),
m AS (
    SELECT *,
        revenue * 1.0 / NULLIF(quantity, 0) AS revenue_per_unit,
        profit  * 1.0 / NULLIF(revenue, 0)  AS profit_margin
    FROM agg
),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline'),
r AS (SELECT * FROM m WHERE season_role = 'recovery')

SELECT
    COALESCE(b.product_category, d.product_category, r.product_category) AS product_category,
    COALESCE(b.product_name, d.product_name, r.product_name) AS product_name,

    ROUND(b.revenue / POWER(10, 6), 4) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 4) AS decline_revenue,
    ROUND(r.revenue / POWER(10, 6), 4) AS recovery_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost_decline_vs_baseline,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change_decline_vs_baseline,

    b.quantity AS baseline_quantity, d.quantity AS decline_quantity, r.quantity AS recovery_quantity,
    (ISNULL(d.quantity, 0) - b.quantity) * 1.0 / NULLIF(b.quantity, 0) AS quantity_pct_change_decline_vs_baseline,

    ROUND(b.revenue_per_unit, 2) AS baseline_revenue_per_unit,
    ROUND(d.revenue_per_unit, 2) AS decline_revenue_per_unit,
    ROUND(r.revenue_per_unit, 2) AS recovery_revenue_per_unit,

    ROUND(b.avg_unit_price, 2) AS baseline_avg_unit_price,
    ROUND(d.avg_unit_price, 2) AS decline_avg_unit_price,
    ROUND(r.avg_unit_price, 2) AS recovery_avg_unit_price,

    ROUND(b.profit_margin, 4) AS baseline_profit_margin,
    ROUND(d.profit_margin, 4) AS decline_profit_margin,
    ROUND(r.profit_margin, 4) AS recovery_profit_margin

FROM b
FULL OUTER JOIN d ON d.product_category = b.product_category AND d.product_name = b.product_name
FULL OUTER JOIN r ON r.product_category = COALESCE(d.product_category, b.product_category)
                  AND r.product_name = COALESCE(d.product_name, b.product_name)
ORDER BY revenue_lost_decline_vs_baseline ASC;

/* -----------------------------------------------------------------------------------------------------------------
Question 10: Shopping times - season+month first, then weekday/hour comparisons for baseline vs decline.
*/
-- 10a. Revenue, record_count, avg_value_per_record by season and month
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.[month],
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order, v.[month]
)
SELECT
    season_role,
    CASE [month] WHEN 11 THEN 'November' WHEN 12 THEN 'December' WHEN 1 THEN 'January' END AS month_name,
    record_count,
    ROUND(revenue / POWER(10, 6), 3) AS revenue,
    ROUND(revenue * 1.0 / NULLIF(record_count, 0), 2) AS avg_value_per_record
FROM agg
ORDER BY season_order, CASE [month] WHEN 11 THEN 1 WHEN 12 THEN 2 WHEN 1 THEN 3 END;

-- 10b. Weekday comparison, baseline vs decline (gender preserved, since the original breakdown tracked it)
WITH agg AS (
    SELECT sr.season_role, v.gender, v.weekday_num, v.weekday_name,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.gender, v.weekday_num, v.weekday_name
),
b AS (SELECT * FROM agg WHERE season_role = 'baseline'),
d AS (SELECT * FROM agg WHERE season_role = 'decline')

SELECT
    COALESCE(b.gender, d.gender) AS gender,
    COALESCE(b.weekday_num, d.weekday_num) AS weekday_num,
    COALESCE(b.weekday_name, d.weekday_name) AS weekday_name,
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change
FROM b
FULL OUTER JOIN d ON d.gender = b.gender AND d.weekday_num = b.weekday_num
ORDER BY gender, weekday_num;

-- 10c. Hour-of-day comparison, baseline vs decline
WITH agg AS (
    SELECT sr.season_role, v.[hour],
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.[hour]
),
b AS (SELECT * FROM agg WHERE season_role = 'baseline'),
d AS (SELECT * FROM agg WHERE season_role = 'decline')

SELECT
    COALESCE(b.[hour], d.[hour]) AS [hour],
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change
FROM b
FULL OUTER JOIN d ON d.[hour] = b.[hour]
ORDER BY [hour];

/* =====================================================================================================
TASK 4: WHAT IS ASSOCIATED WITH SMALLER PURCHASES?
Combine dimensions so a single purchase isn't double-counted as separate findings in the age, product,
channel, and payment analyses above. revenue_per_unit is included alongside AVG(unit_price) throughout,
since they answer different questions (realized revenue per item actually sold vs. average recorded
price per row).
===================================================================================================== */

-- 4a. Channel x age group: did spending weaken mainly in-store or online, and for which age groups?
WITH agg AS (
    SELECT sr.season_role, sr.season_order, v.purchase_type, v.customer_age_range,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, sr.season_order, v.purchase_type, v.customer_age_range
),
m AS (SELECT *, revenue * 1.0 / NULLIF(record_count, 0) AS avg_value_per_record FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline')

SELECT
    COALESCE(b.purchase_type, d.purchase_type) AS purchase_type,
    COALESCE(b.customer_age_range, d.customer_age_range) AS customer_age_range,
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change,
    ROUND(b.avg_value_per_record, 2) AS baseline_avg_value_per_record,
    ROUND(d.avg_value_per_record, 2) AS decline_avg_value_per_record,
    (ISNULL(d.avg_value_per_record, 0) - b.avg_value_per_record) / NULLIF(b.avg_value_per_record, 0) AS avg_value_per_record_pct_change
FROM b
FULL OUTER JOIN d ON d.purchase_type = b.purchase_type AND d.customer_age_range = b.customer_age_range
ORDER BY revenue_lost ASC;

-- 4b. Channel x product category: which categories explain weaker baskets within each channel?
WITH agg AS (
    SELECT sr.season_role, v.purchase_type, v.product_category,
        SUM(v.total_sales) AS revenue,
        SUM(v.quantity) AS quantity,
        AVG(v.unit_price) AS avg_unit_price
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.purchase_type, v.product_category
),
m AS (SELECT *, revenue * 1.0 / NULLIF(quantity, 0) AS revenue_per_unit FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline')

SELECT
    COALESCE(b.purchase_type, d.purchase_type) AS purchase_type,
    COALESCE(b.product_category, d.product_category) AS product_category,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change,
    b.quantity AS baseline_quantity, d.quantity AS decline_quantity,
    ROUND(b.revenue_per_unit, 2) AS baseline_revenue_per_unit,
    ROUND(d.revenue_per_unit, 2) AS decline_revenue_per_unit,
    ROUND(b.avg_unit_price, 2) AS baseline_avg_unit_price,
    ROUND(d.avg_unit_price, 2) AS decline_avg_unit_price
FROM b
FULL OUTER JOIN d ON d.purchase_type = b.purchase_type AND d.product_category = b.product_category
ORDER BY revenue_lost ASC;

-- 4c. Product x season: fewer units of the same products, or a shift toward cheaper products?
WITH agg AS (
    SELECT sr.season_role, v.product_category, v.product_name,
        SUM(v.total_sales) AS revenue,
        SUM(v.quantity) AS quantity,
        AVG(v.unit_price) AS avg_unit_price
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.product_category, v.product_name
),
m AS (SELECT *, revenue * 1.0 / NULLIF(quantity, 0) AS revenue_per_unit FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline')

SELECT
    COALESCE(b.product_category, d.product_category) AS product_category,
    COALESCE(b.product_name, d.product_name) AS product_name,
    b.quantity AS baseline_quantity, d.quantity AS decline_quantity,
    (ISNULL(d.quantity, 0) - b.quantity) * 1.0 / NULLIF(b.quantity, 0) AS quantity_pct_change,
    ROUND(b.avg_unit_price, 2) AS baseline_avg_unit_price,
    ROUND(d.avg_unit_price, 2) AS decline_avg_unit_price,
    (ISNULL(d.avg_unit_price, 0) - b.avg_unit_price) / NULLIF(b.avg_unit_price, 0) AS avg_unit_price_pct_change,
    ROUND(b.revenue_per_unit, 2) AS baseline_revenue_per_unit,
    ROUND(d.revenue_per_unit, 2) AS decline_revenue_per_unit,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost
FROM b
FULL OUTER JOIN d ON d.product_category = b.product_category AND d.product_name = b.product_name
ORDER BY revenue_lost ASC;

-- 4d. Channel x payment method: does the payment pattern hold within the same channel?
WITH agg AS (
    SELECT sr.season_role, v.purchase_type, v.payment_method,
        COUNT(*) AS record_count,                          -- GRAIN: see Section 0
        SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.purchase_type, v.payment_method
),
b AS (SELECT * FROM agg WHERE season_role = 'baseline'),
d AS (SELECT * FROM agg WHERE season_role = 'decline')

SELECT
    COALESCE(b.purchase_type, d.purchase_type) AS purchase_type,
    COALESCE(b.payment_method, d.payment_method) AS payment_method,
    b.record_count AS baseline_record_count, d.record_count AS decline_record_count,
    ROUND(b.revenue / POWER(10, 6), 3) AS baseline_revenue,
    ROUND(d.revenue / POWER(10, 6), 3) AS decline_revenue,
    ROUND(ISNULL(d.revenue, 0) - ISNULL(b.revenue, 0), 2) AS revenue_lost,
    (ISNULL(d.revenue, 0) - b.revenue) / NULLIF(b.revenue, 0) AS revenue_pct_change
FROM b
FULL OUTER JOIN d ON d.purchase_type = b.purchase_type AND d.payment_method = b.payment_method
ORDER BY revenue_lost ASC;

/* =====================================================================================================
TASK 5: PROFITABILITY - lower sales, higher relative cost, or a different product mix?
Margins are always SUM(profit)/SUM(total_sales) computed on the aggregate, never an average of
per-row margins, so they are correctly revenue-weighted.

CAVEAT: confirm with the data dictionary what the "cost" column actually includes. If it is limited to
cost of goods sold and excludes staffing, delivery, rent, or marketing, profit_margin below measures gross
margin, not full channel/category profitability - it should not be used on its own to declare one channel
or category "more profitable" in a P&L sense.
===================================================================================================== */

-- 5a. Overall profit, profit margin, cost per unit across the three seasons
WITH agg AS (
    SELECT sr.season_role, sr.season_order,
        SUM(v.total_sales) AS revenue,
        SUM(v.cost) AS cost,
        SUM(v.profit) AS profit,
        SUM(v.quantity) AS quantity
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role, sr.season_order
),
m AS (
    SELECT *,
        profit * 1.0 / NULLIF(revenue, 0) AS profit_margin,
        cost   * 1.0 / NULLIF(quantity, 0) AS cost_per_unit
    FROM agg
)
SELECT
    m.season_role,
    ROUND(m.revenue / POWER(10, 6), 3) AS revenue,
    ROUND(m.cost / POWER(10, 6), 3) AS cost,
    ROUND(m.profit / POWER(10, 6), 3) AS profit,
    ROUND(ISNULL(m.profit, 0) - ISNULL(prev.profit, 0), 2) AS profit_change,
    (m.profit - prev.profit) / NULLIF(prev.profit, 0) AS profit_pct_change,
    ROUND(m.profit_margin, 4) AS profit_margin,
    m.profit_margin - prev.profit_margin AS profit_margin_change_pts,
    ROUND(m.cost_per_unit, 2) AS cost_per_unit,
    ROUND(prev.cost_per_unit, 2) AS cost_per_unit_prev_season
FROM m
LEFT JOIN m prev ON prev.season_order = m.season_order - 1
ORDER BY m.season_order;

-- 5b. Categories with the largest profit losses, decline vs baseline
WITH agg AS (
    SELECT sr.season_role, v.product_category,
        SUM(v.total_sales) AS revenue,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.product_category
),
m AS (SELECT *, profit * 1.0 / NULLIF(revenue, 0) AS profit_margin FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline')

SELECT
    COALESCE(b.product_category, d.product_category) AS product_category,
    ROUND(b.profit / POWER(10, 6), 3) AS baseline_profit,
    ROUND(d.profit / POWER(10, 6), 3) AS decline_profit,
    ROUND(ISNULL(d.profit, 0) - ISNULL(b.profit, 0), 2) AS profit_lost,
    (ISNULL(d.profit, 0) - b.profit) / NULLIF(b.profit, 0) AS profit_pct_change,
    ROUND(b.profit_margin, 4) AS baseline_profit_margin,
    ROUND(d.profit_margin, 4) AS decline_profit_margin
FROM b
FULL OUTER JOIN d ON d.product_category = b.product_category
ORDER BY profit_lost ASC;

-- 5c. Channels with the largest profit losses, decline vs baseline
WITH agg AS (
    SELECT sr.season_role, v.purchase_type,
        SUM(v.total_sales) AS revenue,
        SUM(v.profit) AS profit
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    WHERE sr.season_role IN ('baseline', 'decline')
    GROUP BY sr.season_role, v.purchase_type
),
m AS (SELECT *, profit * 1.0 / NULLIF(revenue, 0) AS profit_margin FROM agg),
b AS (SELECT * FROM m WHERE season_role = 'baseline'),
d AS (SELECT * FROM m WHERE season_role = 'decline')

SELECT
    COALESCE(b.purchase_type, d.purchase_type) AS purchase_type,
    ROUND(b.profit / POWER(10, 6), 3) AS baseline_profit,
    ROUND(d.profit / POWER(10, 6), 3) AS decline_profit,
    ROUND(ISNULL(d.profit, 0) - ISNULL(b.profit, 0), 2) AS profit_lost,
    (ISNULL(d.profit, 0) - b.profit) / NULLIF(b.profit, 0) AS profit_pct_change,
    ROUND(b.profit_margin, 4) AS baseline_profit_margin,
    ROUND(d.profit_margin, 4) AS decline_profit_margin
FROM b
FULL OUTER JOIN d ON d.purchase_type = b.purchase_type
ORDER BY profit_lost ASC;

/* =====================================================================================================
TASK 6: RELIABILITY CHECK - segment totals reconcile with the overall total
Sums purchase_type revenue back up per season and compares it against the season-level total computed
directly from dbo.v_xmas_sales. Any nonzero difference means a segment query above is dropping rows
(e.g. NULLs in purchase_type) that the overall total still counts.
===================================================================================================== */
WITH overall AS (
    SELECT sr.season_role, SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role
),
by_channel AS (
    SELECT sr.season_role, SUM(v.total_sales) AS revenue
    FROM dbo.v_xmas_sales v
    JOIN dbo.v_season_roles sr ON sr.xmas_year = v.xmas_year
    GROUP BY sr.season_role
)
SELECT
    o.season_role,
    o.revenue AS overall_revenue,
    c.revenue AS sum_of_channel_revenue,
    o.revenue - c.revenue AS reconciliation_gap
FROM overall o
JOIN by_channel c ON c.season_role = o.season_role
ORDER BY o.season_role;
