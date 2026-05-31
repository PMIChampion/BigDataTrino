-- ======================== dim_date ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_date;

CREATE TABLE clickhouse.dwh.dim_date AS
SELECT DISTINCT
    CAST(date_format(d, '%Y%m%d') AS INTEGER) AS date_key,
    CAST(d AS DATE)                           AS full_date,
    CAST(year(d) AS INTEGER)                  AS year,
    CAST(month(d) AS INTEGER)                 AS month,
    CAST(day(d) AS INTEGER)                   AS day,
    CAST(quarter(d) AS INTEGER)               AS quarter,
    CAST(day_of_week(d) AS INTEGER)           AS day_of_week
FROM (
    SELECT date_parse(sale_date, '%m/%d/%Y') AS d
    FROM postgresql.public.mock_data
    UNION
    SELECT date_parse(sale_date, '%m/%d/%Y') AS d
    FROM clickhouse.default.mock_data
) dates;


-- ======================== dim_pet (2-й уровень снежинки) ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_pet;

CREATE TABLE clickhouse.dwh.dim_pet AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY pet_type, pet_breed, pet_name) AS INTEGER) AS pet_key,
    pet_type,
    pet_name,
    pet_breed
FROM (
    SELECT DISTINCT pet_type, pet_name, pet_breed
    FROM (
        SELECT
            COALESCE(customer_pet_type, '')  AS pet_type,
            COALESCE(customer_pet_name, '')  AS pet_name,
            COALESCE(customer_pet_breed, '') AS pet_breed
        FROM postgresql.public.mock_data
        UNION
        SELECT
            customer_pet_type,
            customer_pet_name,
            customer_pet_breed
        FROM clickhouse.default.mock_data
    ) raw
) deduped;


-- ======================== dim_category (2-й уровень снежинки) ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_category;

CREATE TABLE clickhouse.dwh.dim_category AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY category_name, pet_category) AS INTEGER) AS category_key,
    category_name,
    pet_category
FROM (
    SELECT DISTINCT category_name, pet_category
    FROM (
        SELECT
            COALESCE(product_category, '') AS category_name,
            COALESCE(pet_category, '')     AS pet_category
        FROM postgresql.public.mock_data
        UNION
        SELECT
            product_category,
            pet_category
        FROM clickhouse.default.mock_data
    ) raw
) deduped;


-- ======================== dim_customer (FK -> dim_pet) ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_customer;

CREATE TABLE clickhouse.dwh.dim_customer AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY t.email, t.first_name, t.last_name) AS INTEGER) AS customer_key,
    t.first_name,
    t.last_name,
    t.age,
    t.email,
    t.country,
    t.postal_code,
    dp.pet_key
FROM (
    SELECT
        first_name,
        last_name,
        email,
        MAX(age)         AS age,
        MAX(country)     AS country,
        MAX(postal_code) AS postal_code,
        MAX(pet_type)    AS pet_type,
        MAX(pet_name)    AS pet_name,
        MAX(pet_breed)   AS pet_breed
    FROM (
        SELECT
            customer_first_name                AS first_name,
            customer_last_name                 AS last_name,
            customer_email                     AS email,
            customer_age                       AS age,
            COALESCE(customer_country, '')      AS country,
            COALESCE(customer_postal_code, '')  AS postal_code,
            COALESCE(customer_pet_type, '')     AS pet_type,
            COALESCE(customer_pet_name, '')     AS pet_name,
            COALESCE(customer_pet_breed, '')    AS pet_breed
        FROM postgresql.public.mock_data
        UNION ALL
        SELECT
            customer_first_name,
            customer_last_name,
            customer_email,
            customer_age,
            customer_country,
            customer_postal_code,
            customer_pet_type,
            customer_pet_name,
            customer_pet_breed
        FROM clickhouse.default.mock_data
    ) raw
    GROUP BY first_name, last_name, email
) t
JOIN clickhouse.dwh.dim_pet dp
    ON t.pet_type = dp.pet_type
    AND t.pet_name = dp.pet_name
    AND t.pet_breed = dp.pet_breed;


-- ======================== dim_seller ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_seller;

CREATE TABLE clickhouse.dwh.dim_seller AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY email, first_name, last_name) AS INTEGER) AS seller_key,
    first_name,
    last_name,
    email,
    country,
    postal_code
FROM (
    SELECT
        first_name,
        last_name,
        email,
        MAX(country)     AS country,
        MAX(postal_code) AS postal_code
    FROM (
        SELECT
            seller_first_name                AS first_name,
            seller_last_name                 AS last_name,
            seller_email                     AS email,
            COALESCE(seller_country, '')      AS country,
            COALESCE(seller_postal_code, '')  AS postal_code
        FROM postgresql.public.mock_data
        UNION ALL
        SELECT
            seller_first_name,
            seller_last_name,
            seller_email,
            seller_country,
            seller_postal_code
        FROM clickhouse.default.mock_data
    ) raw
    GROUP BY first_name, last_name, email
) deduped;


-- ======================== dim_product (FK -> dim_category) ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_product;

CREATE TABLE clickhouse.dwh.dim_product AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY t.name, t.brand) AS INTEGER) AS product_key,
    t.name,
    t.brand,
    t.price,
    t.weight,
    t.color,
    t.size,
    t.material,
    t.description,
    t.rating,
    t.reviews,
    t.release_date,
    t.expiry_date,
    dc.category_key
FROM (
    SELECT
        name,
        brand,
        MAX(category)     AS category,
        MAX(pet_cat)      AS pet_cat,
        MAX(price)        AS price,
        MAX(weight)       AS weight,
        MAX(color)        AS color,
        MAX(size)         AS size,
        MAX(material)     AS material,
        MAX(description)  AS description,
        MAX(rating)       AS rating,
        MAX(reviews)      AS reviews,
        MAX(release_date) AS release_date,
        MAX(expiry_date)  AS expiry_date
    FROM (
        SELECT
            COALESCE(product_name, '')        AS name,
            COALESCE(product_brand, '')       AS brand,
            COALESCE(product_category, '')    AS category,
            COALESCE(pet_category, '')        AS pet_cat,
            CAST(product_price AS DOUBLE)     AS price,
            CAST(product_weight AS DOUBLE)    AS weight,
            COALESCE(product_color, '')       AS color,
            COALESCE(product_size, '')        AS size,
            COALESCE(product_material, '')    AS material,
            COALESCE(product_description, '') AS description,
            CAST(product_rating AS DOUBLE)    AS rating,
            COALESCE(product_reviews, 0)      AS reviews,
            COALESCE(product_release_date, '') AS release_date,
            COALESCE(product_expiry_date, '')  AS expiry_date
        FROM postgresql.public.mock_data
        UNION ALL
        SELECT
            product_name,
            product_brand,
            product_category,
            pet_category,
            product_price,
            product_weight,
            product_color,
            product_size,
            product_material,
            product_description,
            product_rating,
            product_reviews,
            product_release_date,
            product_expiry_date
        FROM clickhouse.default.mock_data
    ) raw
    GROUP BY name, brand
) t
JOIN clickhouse.dwh.dim_category dc
    ON t.category = dc.category_name
    AND t.pet_cat = dc.pet_category;


-- ======================== dim_store ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_store;

CREATE TABLE clickhouse.dwh.dim_store AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY name, city, country) AS INTEGER) AS store_key,
    name,
    location,
    city,
    state,
    country,
    phone,
    email
FROM (
    SELECT
        name,
        city,
        country,
        MAX(location) AS location,
        MAX(state)    AS state,
        MAX(phone)    AS phone,
        MAX(email)    AS email
    FROM (
        SELECT
            COALESCE(store_name, '')     AS name,
            COALESCE(store_location, '') AS location,
            COALESCE(store_city, '')     AS city,
            COALESCE(store_state, '')    AS state,
            COALESCE(store_country, '')  AS country,
            COALESCE(store_phone, '')    AS phone,
            COALESCE(store_email, '')    AS email
        FROM postgresql.public.mock_data
        UNION ALL
        SELECT
            store_name,
            store_location,
            store_city,
            store_state,
            store_country,
            store_phone,
            store_email
        FROM clickhouse.default.mock_data
    ) raw
    GROUP BY name, city, country
) deduped;


-- ======================== dim_supplier ========================
DROP TABLE IF EXISTS clickhouse.dwh.dim_supplier;

CREATE TABLE clickhouse.dwh.dim_supplier AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY name, email) AS INTEGER) AS supplier_key,
    name,
    contact,
    email,
    phone,
    address,
    city,
    country
FROM (
    SELECT
        name,
        email,
        MAX(contact) AS contact,
        MAX(phone)   AS phone,
        MAX(address) AS address,
        MAX(city)    AS city,
        MAX(country) AS country
    FROM (
        SELECT
            COALESCE(supplier_name, '')    AS name,
            COALESCE(supplier_contact, '') AS contact,
            COALESCE(supplier_email, '')   AS email,
            COALESCE(supplier_phone, '')   AS phone,
            COALESCE(supplier_address, '') AS address,
            COALESCE(supplier_city, '')    AS city,
            COALESCE(supplier_country, '') AS country
        FROM postgresql.public.mock_data
        UNION ALL
        SELECT
            supplier_name,
            supplier_contact,
            supplier_email,
            supplier_phone,
            supplier_address,
            supplier_city,
            supplier_country
        FROM clickhouse.default.mock_data
    ) raw
    GROUP BY name, email
) deduped;


-- ======================== fact_sales ========================
DROP TABLE IF EXISTS clickhouse.dwh.fact_sales;

CREATE TABLE clickhouse.dwh.fact_sales AS
SELECT
    CAST(ROW_NUMBER() OVER () AS INTEGER)   AS sale_key,
    dc.customer_key,
    ds.seller_key,
    dp.product_key,
    dst.store_key,
    dsu.supplier_key,
    dd.date_key,
    CAST(src.sale_quantity AS INTEGER)      AS quantity,
    CAST(src.sale_total_price AS DOUBLE)    AS total_price
FROM (
    SELECT
        customer_first_name,
        customer_last_name,
        customer_email,
        seller_first_name,
        seller_last_name,
        seller_email,
        COALESCE(product_name, '')     AS product_name,
        COALESCE(product_brand, '')    AS product_brand,
        COALESCE(store_name, '')       AS store_name,
        COALESCE(store_city, '')       AS store_city,
        COALESCE(store_country, '')    AS store_country,
        COALESCE(supplier_name, '')    AS supplier_name,
        COALESCE(supplier_email, '')   AS supplier_email,
        sale_date,
        sale_quantity,
        CAST(sale_total_price AS DOUBLE) AS sale_total_price
    FROM postgresql.public.mock_data
    UNION ALL
    SELECT
        customer_first_name,
        customer_last_name,
        customer_email,
        seller_first_name,
        seller_last_name,
        seller_email,
        product_name,
        product_brand,
        store_name,
        store_city,
        store_country,
        supplier_name,
        supplier_email,
        sale_date,
        sale_quantity,
        sale_total_price
    FROM clickhouse.default.mock_data
) src
JOIN clickhouse.dwh.dim_customer dc
    ON src.customer_first_name = dc.first_name
    AND src.customer_last_name  = dc.last_name
    AND src.customer_email      = dc.email
JOIN clickhouse.dwh.dim_seller ds
    ON src.seller_first_name = ds.first_name
    AND src.seller_last_name  = ds.last_name
    AND src.seller_email      = ds.email
JOIN clickhouse.dwh.dim_product dp
    ON src.product_name  = dp.name
    AND src.product_brand = dp.brand
JOIN clickhouse.dwh.dim_store dst
    ON src.store_name    = dst.name
    AND src.store_city   = dst.city
    AND src.store_country = dst.country
JOIN clickhouse.dwh.dim_supplier dsu
    ON src.supplier_name  = dsu.name
    AND src.supplier_email = dsu.email
JOIN clickhouse.dwh.dim_date dd
    ON CAST(date_parse(src.sale_date, '%m/%d/%Y') AS DATE) = dd.full_date;
