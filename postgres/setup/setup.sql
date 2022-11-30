CREATE SCHEMA ecommerce;
SET search_path TO ecommerce;

CREATE EXTENSION postgis;
CREATE EXTENSION pg_cron;

-- # Create and populate products data table
CREATE TABLE products (
	product_id VARCHAR(255) PRIMARY KEY,
    size VARCHAR(255),
    product VARCHAR(255),
    department VARCHAR(255),
    price VARCHAR(255)
);

COPY products(product_id, size, product, department, price)
FROM '/data/products.csv'
DELIMITER ','
CSV HEADER;

-- # Create and populate customers data table
CREATE TABLE customers (
    id VARCHAR(255) PRIMARY KEY, 
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255)
);

COPY customers(id, first_name, last_name, email, phone)
FROM '/data/customers.csv'
DELIMITER ','
CSV HEADER;

-- # Create and populate the demographic data table
CREATE TABLE demographics (
    id VARCHAR(255) PRIMARY KEY,
    street_address VARCHAR(255),
    state VARCHAR(255),
    zip_code VARCHAR(255),
    country VARCHAR(255),
    country_code VARCHAR(255)
);

COPY demographics(id, street_address, state, zip_code, country, country_code)
FROM '/data/demographics.csv'
DELIMITER ','
CSV HEADER;

-- # Create orders table which data will be generated to over time
CREATE TABLE orders (
    order_id VARCHAR(255) PRIMARY KEY,
    product_id VARCHAR(255),
    customer_id VARCHAR(255),
    create_time TIMESTAMP
);

-- #

CREATE PROCEDURE generate_orders() AS $$
BEGIN
    FOR frac IN 0..2*PI() BY PI()/2 LOOP
        BEGIN 
            FOR num_messages IN 0..ROUND(10*SIN(frac)+20) BY 1 LOOP
                DECLARE 
                    product ecommerce.products%ROWTYPE;
                    customer ecommerce.customers%ROWTYPE;
                    uuid VARCHAR;
                BEGIN
                    SELECT * INTO product FROM ecommerce.products ORDER BY random() LIMIT 1; 
                    SELECT * INTO customer FROM ecommerce.customers ORDER BY random() LIMIT 1;
                    SELECT uuid_in(md5(random()::text || clock_timestamp()::text)::cstring) INTO uuid;
                    INSERT INTO ecommerce.orders (order_id, product_id, customer_id, create_time) VALUES (uuid, product.product_id, customer.id, NOW());
                    COMMIT;
                END;
            END LOOP;
            PERFORM pg_sleep(1);
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- #

CREATE OR REPLACE PROCEDURE change_prices() AS $$
BEGIN
    DECLARE 
        id VARCHAR;
        old_price DOUBLE PRECISION;
        price_delta DOUBLE PRECISION;
        new_price DOUBLE PRECISION;
    BEGIN
        SELECT product_id INTO id FROM ecommerce.products ORDER BY random() LIMIT 1;
        SELECT CAST(TRIM(leading '$' FROM price) AS DOUBLE PRECISION) INTO old_price FROM ecommerce.products WHERE product_id = id;

        SELECT random()*(5) INTO price_delta; 
        IF random() >= 0.5 THEN
            price_delta := price_delta * -1;
        END IF;

        IF old_price <= 10.0 THEN
            new_price := old_price + random()*(5);
        ELSE
            new_price := old_price + price_delta;
        END IF;

        UPDATE ecommerce.products SET price = CONCAT('$', CAST(new_price AS VARCHAR)) WHERE product_id = id;
        COMMIT;
    END;
END;
$$ LANGUAGE plpgsql;

-- #

CREATE OR REPLACE PROCEDURE shuffle_customers() AS $$
BEGIN
    DECLARE
        customer_id VARCHAR;
        new_phone VARCHAR;
    BEGIN
        SELECT id INTO customer_id FROM ecommerce.customers ORDER BY random() LIMIT 1;
        SELECT CONCAT(CAST(FLOOR(RANDOM()*899+100) AS VARCHAR), '-', CAST(FLOOR(RANDOM()*899+100) AS VARCHAR), '-', CAST(FLOOR(RANDOM()*8999+1000) AS VARCHAR)) INTO new_phone;
        UPDATE ecommerce.customers SET phone = new_phone WHERE id = customer_id;
        COMMIT;
    END;
END;
$$ LANGUAGE plpgsql;

-- #

CREATE OR REPLACE PROCEDURE shuffle_demographics() AS $$
BEGIN 
    DECLARE
        customer_id VARCHAR;
        address_number VARCHAR;
        address_type VARCHAR;
        address_name VARCHAR;
        new_address VARCHAR;
    BEGIN
        SELECT id INTO customer_id FROM ecommerce.demographics ORDER BY random() LIMIT 1;
        SELECT SPLIT_PART(street_address, ' ', 1) INTO address_number FROM ecommerce.demographics ORDER BY RANDOM() LIMIT 1;
        SELECT SPLIT_PART(street_address, ' ', -1) INTO address_number FROM ecommerce.demographics ORDER BY RANDOM() LIMIT 1;
        SELECT SUBSTRING(street_address FROM (CHAR_LENGTH(SPLIT_PART(street_address, ' ', 1))+2) FOR (CHAR_LENGTH(street_address)-CHAR_LENGTH(SPLIT_PART(street_address, ' ', -1))-CHAR_LENGTH(SPLIT_PART(street_address, ' ', 1))-2)) INTO address_name FROM ecommerce.demographics ORDER BY RANDOM() LIMIT 1;
        SELECT address_number || ' ' || address_name || ' ' || address_type INTO new_address;
        UPDATE ecommerce.demographics SET street_address = new_address WHERE id = customer_id;
        COMMIT;
    END;
END;
$$ LANGUAGE plpgsql;

-- #

SELECT cron.schedule('mrclean', '0 */6 * * *', $$DELETE FROM ecommerce.orders WHERE create_time < now() - interval '6 hours'$$);
SELECT cron.schedule('new_order_creation', '*/1 * * * *', $$CALL ecommerce.generate_orders()$$);
SELECT cron.schedule('product_price_changing', '*/1 * * * *', $$CALL ecommerce.change_prices()$$);
SELECT cron.schedule('customer_data_shuffling', '*/1 * * * *', $$CALL ecommerce.shuffle_customers()$$);
SELECT cron.schedule('demographic_data_shuffling', '*/1 * * * *', $$CALL ecommerce.shuffle_demographics()$$);