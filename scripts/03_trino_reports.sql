-- ======== 1. Витрина продаж по продуктам ========
DROP TABLE IF EXISTS clickhouse.dwh.report_sales_by_product;

CREATE TABLE clickhouse.dwh.report_sales_by_product AS
SELECT
    dp.name                                                  AS product_name,
    dc.category_name                                         AS product_category,
    dc.pet_category,
    dp.brand                                                 AS product_brand,
    CAST(SUM(fs.total_price) AS DOUBLE)                      AS total_revenue,
    CAST(SUM(fs.quantity) AS BIGINT)                         AS total_quantity_sold,
    CAST(dp.rating AS DOUBLE)                                AS avg_rating,
    CAST(dp.reviews AS INTEGER)                              AS total_reviews,
    CAST(ROW_NUMBER() OVER (ORDER BY SUM(fs.total_price) DESC) AS INTEGER) AS revenue_rank
FROM clickhouse.dwh.fact_sales fs
JOIN clickhouse.dwh.dim_product  dp ON fs.product_key  = dp.product_key
JOIN clickhouse.dwh.dim_category dc ON dp.category_key = dc.category_key
GROUP BY dp.name, dc.category_name, dc.pet_category, dp.brand, dp.rating, dp.reviews;


-- ======== 2. Витрина продаж по клиентам ========
DROP TABLE IF EXISTS clickhouse.dwh.report_sales_by_customer;

CREATE TABLE clickhouse.dwh.report_sales_by_customer AS
SELECT
    CONCAT(c.first_name, ' ', c.last_name)                    AS customer_name,
    c.email                                                    AS customer_email,
    c.country                                                  AS customer_country,
    p.pet_type,
    CAST(SUM(fs.total_price) AS DOUBLE)                        AS total_purchases,
    CAST(COUNT(*) AS BIGINT)                                   AS order_count,
    CAST(SUM(fs.total_price) / COUNT(*) AS DOUBLE)             AS avg_check,
    CAST(ROW_NUMBER() OVER (ORDER BY SUM(fs.total_price) DESC) AS INTEGER) AS purchase_rank
FROM clickhouse.dwh.fact_sales fs
JOIN clickhouse.dwh.dim_customer c  ON fs.customer_key = c.customer_key
JOIN clickhouse.dwh.dim_pet      p  ON c.pet_key       = p.pet_key
GROUP BY c.first_name, c.last_name, c.email, c.country, p.pet_type;


-- ======== 3. Витрина продаж по времени ========
DROP TABLE IF EXISTS clickhouse.dwh.report_sales_by_time;

CREATE TABLE clickhouse.dwh.report_sales_by_time AS
SELECT
    dd.year,
    dd.month,
    dd.quarter,
    CAST(SUM(fs.total_price) AS DOUBLE)                       AS monthly_revenue,
    CAST(COUNT(*) AS BIGINT)                                  AS order_count,
    CAST(SUM(fs.total_price) / COUNT(*) AS DOUBLE)            AS avg_order_size,
    CAST(SUM(SUM(fs.total_price)) OVER (
        PARTITION BY dd.year ORDER BY dd.month
    ) AS DOUBLE)                                              AS cumulative_revenue_ytd
FROM clickhouse.dwh.fact_sales fs
JOIN clickhouse.dwh.dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.year, dd.month, dd.quarter;


-- ======== 4. Витрина продаж по магазинам ========
DROP TABLE IF EXISTS clickhouse.dwh.report_sales_by_store;

CREATE TABLE clickhouse.dwh.report_sales_by_store AS
SELECT
    s.name                                                      AS store_name,
    s.city                                                      AS store_city,
    s.state                                                     AS store_state,
    s.country                                                   AS store_country,
    CAST(SUM(fs.total_price) AS DOUBLE)                         AS total_revenue,
    CAST(COUNT(*) AS BIGINT)                                    AS order_count,
    CAST(SUM(fs.total_price) / COUNT(*) AS DOUBLE)              AS avg_check,
    CAST(ROW_NUMBER() OVER (ORDER BY SUM(fs.total_price) DESC) AS INTEGER) AS revenue_rank
FROM clickhouse.dwh.fact_sales fs
JOIN clickhouse.dwh.dim_store s ON fs.store_key = s.store_key
GROUP BY s.name, s.city, s.state, s.country;


-- ======== 5. Витрина продаж по поставщикам ========
DROP TABLE IF EXISTS clickhouse.dwh.report_sales_by_supplier;

CREATE TABLE clickhouse.dwh.report_sales_by_supplier AS
SELECT
    su.name                                                     AS supplier_name,
    su.country                                                  AS supplier_country,
    dc.category_name                                            AS main_category,
    CAST(SUM(fs.total_price) AS DOUBLE)                         AS total_revenue,
    CAST(AVG(dp.price) AS DOUBLE)                               AS avg_product_price,
    CAST(COUNT(DISTINCT dp.product_key) AS BIGINT)              AS product_count,
    CAST(ROW_NUMBER() OVER (ORDER BY SUM(fs.total_price) DESC) AS INTEGER) AS revenue_rank
FROM clickhouse.dwh.fact_sales fs
JOIN clickhouse.dwh.dim_supplier su ON fs.supplier_key = su.supplier_key
JOIN clickhouse.dwh.dim_product  dp ON fs.product_key  = dp.product_key
JOIN clickhouse.dwh.dim_category dc ON dp.category_key = dc.category_key
GROUP BY su.name, su.country, dc.category_name;


-- ======== 6. Витрина качества продукции ========
DROP TABLE IF EXISTS clickhouse.dwh.report_product_quality;

CREATE TABLE clickhouse.dwh.report_product_quality AS
SELECT
    dp.name                                                     AS product_name,
    dc.category_name                                            AS product_category,
    dp.brand                                                    AS product_brand,
    CAST(dp.rating AS DOUBLE)                                   AS product_rating,
    CAST(dp.reviews AS INTEGER)                                 AS product_reviews,
    CAST(SUM(fs.quantity) AS BIGINT)                            AS total_sales_volume,
    CAST(SUM(fs.total_price) AS DOUBLE)                         AS total_revenue,
    CAST(ROW_NUMBER() OVER (
        ORDER BY dp.rating DESC, SUM(fs.total_price) DESC
    ) AS INTEGER)                                               AS quality_rank
FROM clickhouse.dwh.fact_sales fs
JOIN clickhouse.dwh.dim_product  dp ON fs.product_key  = dp.product_key
JOIN clickhouse.dwh.dim_category dc ON dp.category_key = dc.category_key
GROUP BY dp.name, dc.category_name, dp.brand, dp.rating, dp.reviews;
