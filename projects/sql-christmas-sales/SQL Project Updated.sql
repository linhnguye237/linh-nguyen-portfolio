/* -- Capstone Project: Xmas Gift Sales Analysis
Student: Nguyen Khanh Linh
Data Source: FP20Analytics Challenge 12
-- */

USE fp20c12
GO

/* -----------------------------------------------------------------------------------------------------------------
Question 1: Retrieve sales information including revenue, quantity sold, cost, and profit for each Christmas season.
- Exclude data from the 2017–2018 Christmas season because it does not have all 3 months
- Round revenue, cost, and profit to millions of dollars (2 decimal places)
- Round quantity to thousands (1 decimal place)
*/

WITH xmas_sales AS (
    SELECT
        -- information on time
        CASE 
            WHEN MONTH([date]) = 1 THEN YEAR([date]) - 1 
            ELSE YEAR([date]) 
        END AS xmas_year,

        CASE 
            WHEN MONTH([date]) = 1 
                THEN CONCAT(YEAR([date]) - 1, '-', YEAR([date]))
            ELSE CONCAT(YEAR([date]), '-', YEAR([date]) + 1) 
        END AS xmas_season,

        YEAR([date]) AS [year],
        EOMONTH([date]) AS end_date_of_month,

        DATEPART(WEEKDAY, [date]) AS [weekday],

        CASE DATEPART(WEEKDAY, [date])
            WHEN 1 THEN 'Sunday'
            WHEN 2 THEN 'Monday'
            WHEN 3 THEN 'Tuesday'
            WHEN 4 THEN 'Wednesday'
            WHEN 5 THEN 'Thursday'
            WHEN 6 THEN 'Friday'
            WHEN 7 THEN 'Saturday'
        END AS weekday_name,

        DATEPART(HOUR, [time]) AS [hour],

        s.*
    FROM dbo.xmas_sales s
    WHERE EOMONTH([date]) <> '2018-01-31'
),

s AS (
    SELECT 
        xmas_year,
        xmas_season,
        SUM(total_sales) AS sales,
        SUM(quantity) AS quantity,
        SUM(cost) AS cost,
        SUM(profit) AS profit
    FROM xmas_sales
    GROUP BY xmas_year, xmas_season
)

SELECT 
    xmas_year,
    xmas_season,
    ROUND(sales / POWER(10, 6), 2) AS sales,
    ROUND(quantity * 1.0 / POWER(10, 3), 1) AS quantity,
    ROUND(cost / POWER(10, 6), 2) AS cost,
    ROUND(profit / POWER(10, 6), 2) AS profit
FROM s;

/* -----------------------------------------------------------------------------------------------------------------
Question 2: Calculate the percentage growth of revenue, quantity sold, and profit of the most recent Christmas season compared to the previous year
*/
-- Build view dbo.v_xmas_sales

GO
CREATE OR ALTER VIEW dbo.v_xmas_sales AS
SELECT
    CASE 
        WHEN MONTH([date]) = 1 THEN YEAR([date]) - 1 
        ELSE YEAR([date]) 
    END AS xmas_year,

    CASE 
        WHEN MONTH([date]) = 1 
            THEN CONCAT(YEAR([date]) - 1, '-', YEAR([date]))
        ELSE CONCAT(YEAR([date]), '-', YEAR([date]) + 1) 
    END AS xmas_season,

    YEAR([date]) AS [year],
    EOMONTH([date]) AS end_date_of_month,

    DATEPART(WEEKDAY, [date]) AS [weekday],

    CASE DATEPART(WEEKDAY, [date])
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END AS weekday_name,

    DATEPART(HOUR, [time]) AS [hour],

    s.*
FROM dbo.xmas_sales s
WHERE EOMONTH([date]) <> '2018-01-31';

GO

SELECT * 
FROM dbo.v_xmas_sales;

------

SELECT MAX(xmas_year) 
FROM dbo.v_xmas_sales; -- 2021

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
),
r AS (
    SELECT 
        s.xmas_year,
        s.xmas_season,

        s.sales,
        prev.sales AS sales_prev_season,
        (s.sales - prev.sales) / prev.sales AS sales_growth_percentage,

        s.quantity,
        prev.quantity AS quantity_prev_season,
        (s.quantity - prev.quantity) * 1.0 / prev.quantity AS quantity_growth_percentage,

        s.profit,
        prev.profit AS profit_prev_season,
        (s.profit - prev.profit) / prev.profit AS profit_growth_percentage

    FROM s s, s prev
    WHERE s.xmas_year = (SELECT MAX(xmas_year) FROM dbo.v_xmas_sales)
      AND prev.xmas_year = s.xmas_year - 1
)

SELECT 
    xmas_year,
    xmas_season,

    ROUND(sales / POWER(10, 6), 2) AS sales,
    ROUND(sales_prev_season / POWER(10, 6), 2) AS sales_prev_season,
    ROUND(sales_growth_percentage, 3) AS sales_growth_percentage,

    ROUND(quantity / POWER(10, 3), 1) AS quantity,
    ROUND(quantity_prev_season / POWER(10, 3), 1) AS quantity_prev_season,
    ROUND(quantity_growth_percentage, 3) AS quantity_growth_percentage,

    ROUND(profit / POWER(10, 6), 2) AS profit,
    ROUND(profit_prev_season / POWER(10, 6), 2) AS profit_prev_season,
    ROUND(profit_growth_percentage, 3) AS profit_growth_percentage

FROM r;

/* ----------------------------------------------------------------------------------------------------------------- 
Question 3: Calculate the percentage growth of revenue for each Christmas season
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
    ROUND((s.sales - prev.sales) / prev.sales, 3) AS growth_yoy
FROM s s
JOIN s prev 
    ON s.xmas_year = prev.xmas_year + 1;

/* -----------------------------------------------------------------------------------------------------------------
Question 4: Revenue and percentage contribution of each purchase channel (purchase_type) for each Christmas season
*/

WITH xmas_season_sales AS (
    SELECT 
        xmas_year,
        xmas_season,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY xmas_year, xmas_season
),
s AS (
    SELECT 
        xmas_year,
        purchase_type,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY xmas_year, purchase_type
)

SELECT 
    x.xmas_year,
    x.xmas_season,
    s.purchase_type,

    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(x.sales / POWER(10, 6), 2) AS total_sales,
    ROUND(s.sales / x.sales, 3) AS sales_ratio

FROM s
JOIN xmas_season_sales x 
    ON s.xmas_year = x.xmas_year

ORDER BY x.xmas_year, s.purchase_type;


/* -----------------------------------------------------------------------------------------------------------------
Question 5: Analyze revenue by country (and city). Sort in descending order of revenue.
*/
-- revenue by country
;SELECT 
    country,
    ROUND(SUM(total_sales) / POWER(10, 6), 2) AS sales
FROM dbo.v_xmas_sales
GROUP BY country
ORDER BY sales DESC;

-- revenue by city
SELECT 
    country,
    city,
    ROUND(SUM(total_sales) / POWER(10, 6), 2) AS sales
FROM dbo.v_xmas_sales
GROUP BY country, city
ORDER BY country, sales DESC;

/* -----------------------------------------------------------------------------------------------------------------
Question 6: Rank countries based on highest revenue (or highest revenue growth rate) in the most recent Christmas season
*/
;WITH s AS (
    SELECT 
        xmas_year,
        xmas_season,
        country,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY xmas_year, xmas_season, country
)

SELECT 
    s.xmas_year,
    s.xmas_season,
    s.country,

    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(prev.sales / POWER(10, 6), 2) AS prev_sales,
    (s.sales - prev.sales) / prev.sales AS sales_growth_percentage

FROM s s
LEFT JOIN s prev 
    ON s.xmas_year = prev.xmas_year + 1 
   AND s.country = prev.country

WHERE s.xmas_year = (
    SELECT MAX(xmas_year) 
    FROM dbo.v_xmas_sales
)

ORDER BY xmas_year, sales DESC;

/* -----------------------------------------------------------------------------------------------------------------
Question 7: 
Calculate revenue share by age group
Calculate revenue share by gender
Calculate revenue share by purchase type
*/
-- by age group
DECLARE @total_sales DECIMAL(18, 0) = (
    SELECT SUM(total_sales) 
    FROM dbo.v_xmas_sales
);

SELECT 
    customer_age_range,
    SUM(total_sales) AS sales,
    SUM(total_sales) * 1.0 / @total_sales AS sales_proportion
FROM dbo.v_xmas_sales
GROUP BY customer_age_range;

GO

-- by gender
DECLARE @total_sales DECIMAL(18, 0) = (
    SELECT SUM(total_sales) 
    FROM dbo.v_xmas_sales
);

SELECT 
    gender,
    SUM(total_sales) AS sales,
    SUM(total_sales) * 1.0 / @total_sales AS sales_proportion
FROM dbo.v_xmas_sales
GROUP BY gender
ORDER BY gender;

GO

-- by purchase type
DECLARE @total_sales DECIMAL(18, 0) = (
    SELECT SUM(total_sales) 
    FROM dbo.v_xmas_sales
);

SELECT 
    purchase_type,
    SUM(total_sales) AS sales,
    ROUND(SUM(total_sales) * 1.0 / @total_sales, 3) AS sales_proportion
FROM dbo.v_xmas_sales
GROUP BY purchase_type
ORDER BY purchase_type;

GO

/* -----------------------------------------------------------------------------------------------------------------
Question 8: 
Calculate revenue share by purchase type within each age group
Calculate revenue share by payment method within each age group
*/
-- revenue share by purchase type within each age group
;WITH t AS (
    SELECT 
        customer_age_range,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY customer_age_range
),
s AS (
    SELECT 
        customer_age_range,
        purchase_type,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY customer_age_range, purchase_type
)

SELECT 
    s.customer_age_range,
    s.purchase_type,

    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(t.sales / POWER(10, 6), 2) AS total_sales,
    ROUND(s.sales / t.sales, 3) AS sales_proportion

FROM s
LEFT JOIN t 
    ON s.customer_age_range = t.customer_age_range

ORDER BY customer_age_range, purchase_type;

-- revenue share by payment method within each age group
WITH t AS (
    SELECT 
        customer_age_range,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY customer_age_range
),
s AS (
    SELECT 
        customer_age_range,
        payment_method,
        SUM(total_sales) AS sales
    FROM dbo.v_xmas_sales
    GROUP BY customer_age_range, payment_method
)

SELECT 
    s.customer_age_range,
    s.payment_method,

    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(t.sales / POWER(10, 6), 2) AS total_sales,
    ROUND(s.sales / t.sales, 3) AS sales_proportion

FROM s
LEFT JOIN t 
    ON s.customer_age_range = t.customer_age_range

ORDER BY customer_age_range, payment_method;

/* -----------------------------------------------------------------------------------------------------------------
Question 9: Analyze sales performance by product category (and product)
*/
-- analysis by product category
DECLARE @total_sales DECIMAL(18, 0) = (
    SELECT SUM(total_sales) 
    FROM dbo.v_xmas_sales
);

-- SELECT @total_sales
;WITH s AS (
    SELECT 
        product_category,
        SUM(total_sales) AS sales,
        AVG(unit_price) AS avg_unit_price,
        SUM(profit) AS profit,
        SUM(profit) / SUM(total_sales) AS profit_ratio
    FROM dbo.v_xmas_sales
    GROUP BY product_category
)

SELECT 
    product_category,
    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(sales / @total_sales, 3) AS sales_proportion,
    ROUND(avg_unit_price, 2) AS avg_unit_price,
    ROUND(profit_ratio, 4) AS profit_ratio
FROM s
ORDER BY product_category;

GO

-- analysis by product
DECLARE @total_sales DECIMAL(18, 0) = (
    SELECT SUM(total_sales) 
    FROM dbo.v_xmas_sales
);

WITH s AS (
    SELECT 
        product_category,
        product_name,
        SUM(total_sales) AS sales,
        SUM(quantity) AS quantity,
        MIN(unit_price) AS min_unit_price,
        MAX(unit_price) AS max_unit_price,
        AVG(unit_price) AS avg_unit_price,
        SUM(profit) AS profit,
        SUM(profit) / SUM(total_sales) AS profit_ratio
    FROM dbo.v_xmas_sales
    GROUP BY product_category, product_name
)

SELECT 
    product_category,
    product_name,

    ROUND(s.sales / POWER(10, 6), 2) AS sales,
    ROUND(sales / @total_sales, 3) AS sales_proportion,
    quantity,

    ROUND(min_unit_price, 2) AS min_unit_price,
    ROUND(max_unit_price, 2) AS max_unit_price,
    ROUND(avg_unit_price, 2) AS avg_unit_price,

    ROUND(profit_ratio, 4) AS profit_ratio

FROM s
ORDER BY product_category, product_name;


/* ----------------------------------------------------------------------------------------------------------------- 
Question 10: 
Which day of the week do male/female customers tend to shop?
What time of day do customers usually shop?
*/
SELECT 
    gender,
    weekday,
    weekday_name,
    COUNT(*) AS nb_orders
FROM dbo.v_xmas_sales
GROUP BY gender, weekday, weekday_name
ORDER BY gender, weekday;


SELECT 
    [hour],
    COUNT(*) AS nb_orders
FROM dbo.v_xmas_sales
GROUP BY [hour]
ORDER BY [hour];