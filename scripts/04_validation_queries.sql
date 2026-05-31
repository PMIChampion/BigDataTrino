-- Исходные данные
SELECT 'postgresql -> default.mock_data (через Trino)' AS source, count() AS row_count
FROM dwh.fact_sales;

SELECT 'ClickHouse default.mock_data' AS source, count() AS row_count
FROM default.mock_data;

-- Размеры всех таблиц dwh
SELECT name, total_rows
FROM system.tables
WHERE database = 'dwh'
ORDER BY name;

-- ======== Проверка связей снежинки ========

-- dim_customer -> dim_pet (FK проверка)
SELECT c.first_name, c.last_name, c.country, p.pet_type, p.pet_breed
FROM dwh.dim_customer c
JOIN dwh.dim_pet p ON c.pet_key = p.pet_key
LIMIT 10;

-- dim_product -> dim_category (FK проверка)
SELECT p.name, p.brand, c.category_name, c.pet_category
FROM dwh.dim_product p
JOIN dwh.dim_category c ON p.category_key = c.category_key
LIMIT 10;

-- ======== Отчёт 1: Топ-10 продуктов по выручке ========
SELECT product_name, product_category, pet_category, total_revenue, total_quantity_sold
FROM dwh.report_sales_by_product
ORDER BY revenue_rank
LIMIT 10;

-- Выручка по категориям
SELECT product_category, SUM(total_revenue) AS category_revenue, SUM(total_quantity_sold) AS category_qty
FROM dwh.report_sales_by_product
GROUP BY product_category
ORDER BY category_revenue DESC;

-- ======== Отчёт 2: Топ-10 клиентов ========
SELECT customer_name, customer_country, pet_type, total_purchases, order_count, avg_check
FROM dwh.report_sales_by_customer
ORDER BY purchase_rank
LIMIT 10;

-- Клиенты по странам
SELECT customer_country, count() AS customer_count, SUM(total_purchases) AS country_revenue
FROM dwh.report_sales_by_customer
GROUP BY customer_country
ORDER BY country_revenue DESC
LIMIT 15;

-- ======== Отчёт 3: Тренды продаж ========
SELECT year, month, quarter, monthly_revenue, order_count, avg_order_size, cumulative_revenue_ytd
FROM dwh.report_sales_by_time
ORDER BY year, month;

-- Сравнение выручки по годам
SELECT year, SUM(monthly_revenue) AS annual_revenue, SUM(order_count) AS annual_orders
FROM dwh.report_sales_by_time
GROUP BY year
ORDER BY year;

-- ======== Отчёт 4: Топ-5 магазинов ========
SELECT store_name, store_city, store_country, total_revenue, avg_check
FROM dwh.report_sales_by_store
ORDER BY revenue_rank
LIMIT 5;

-- Продажи по странам
SELECT store_country, SUM(total_revenue) AS country_revenue, count() AS store_count
FROM dwh.report_sales_by_store
GROUP BY store_country
ORDER BY country_revenue DESC;

-- ======== Отчёт 5: Топ-5 поставщиков ========
SELECT supplier_name, supplier_country, main_category, total_revenue, avg_product_price, product_count
FROM dwh.report_sales_by_supplier
ORDER BY revenue_rank
LIMIT 5;

-- Поставщики по странам
SELECT supplier_country, count() AS supplier_count, SUM(total_revenue) AS country_revenue
FROM dwh.report_sales_by_supplier
GROUP BY supplier_country
ORDER BY country_revenue DESC;

-- ======== Отчёт 6: Лучшие по рейтингу ========
SELECT product_name, product_category, product_brand, product_rating, total_sales_volume, total_revenue
FROM dwh.report_product_quality
ORDER BY product_rating DESC
LIMIT 10;

-- Худшие по рейтингу
SELECT product_name, product_category, product_brand, product_rating, total_sales_volume
FROM dwh.report_product_quality
ORDER BY product_rating ASC
LIMIT 10;

-- Корреляция рейтинга и продаж
SELECT
    CASE
        WHEN product_rating >= 4.0 THEN 'Высокий (4-5)'
        WHEN product_rating >= 3.0 THEN 'Средний (3-4)'
        WHEN product_rating >= 2.0 THEN 'Низкий (2-3)'
        ELSE 'Очень низкий (<2)'
    END AS rating_group,
    count()                     AS product_count,
    SUM(total_revenue)          AS group_revenue,
    AVG(total_sales_volume)     AS avg_sales_volume
FROM dwh.report_product_quality
GROUP BY rating_group
ORDER BY rating_group;
