CREATE SCHEMA analytics;
SET search_path TO analytics;

CREATE EXTENSION postgis;

CREATE TABLE orders (
    order_id VARCHAR(255) PRIMARY KEY,
    product_id VARCHAR(255),
    customer_id VARCHAR(255),
    create_time TIMESTAMP
);