-- =============================================================================
-- 01_criar_banco_e_tabelas.sql
-- Cria o banco e as 9 tabelas do dataset Olist (só a estrutura, sem dados).
-- A carga dos CSVs fica no 02_carga_dados.sql.
--
-- Escolhas que fiz na modelagem:
--  * CEP como CHAR(5), para não perder o zero à esquerda (01037 virando 1037).
--  * Valores em dinheiro como DECIMAL(10,2), para evitar erro de arredondamento.
--  * Sem FOREIGN KEY por enquanto: prefiro carregar tudo primeiro e checar
--    registros órfãos na etapa de qualidade (04). Deixei índices nas colunas
--    usadas nos JOINs.
--  * Corrigi o erro de digitação "lenght" da fonte para "length" em products.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS olist
    DEFAULT CHARACTER SET utf8mb4;

USE olist;

-- Permite rodar o script de novo durante o desenvolvimento (apaga os dados!)
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_category_translation;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS geolocation;


-- customer_id é gerado por pedido, então a mesma pessoa pode aparecer com
-- vários customer_id. Para contar clientes de verdade, usar customer_unique_id.
CREATE TABLE customers (
    customer_id              CHAR(32)     NOT NULL,
    customer_unique_id       CHAR(32)     NOT NULL,
    customer_zip_code_prefix CHAR(5)      NOT NULL,
    customer_city            VARCHAR(100) NOT NULL,
    customer_state           CHAR(2)      NOT NULL,
    PRIMARY KEY (customer_id),
    INDEX idx_customers_unique_id (customer_unique_id),
    INDEX idx_customers_zip       (customer_zip_code_prefix),
    INDEX idx_customers_state     (customer_state)
);


CREATE TABLE sellers (
    seller_id              CHAR(32)     NOT NULL,
    seller_zip_code_prefix CHAR(5)      NOT NULL,
    seller_city            VARCHAR(100) NOT NULL,
    seller_state           CHAR(2)      NOT NULL,
    PRIMARY KEY (seller_id),
    INDEX idx_sellers_zip   (seller_zip_code_prefix),
    INDEX idx_sellers_state (seller_state)
);


-- Há várias linhas por CEP, então não existe chave primária natural.
CREATE TABLE geolocation (
    geolocation_zip_code_prefix CHAR(5)      NOT NULL,
    geolocation_lat             DOUBLE       NOT NULL,
    geolocation_lng             DOUBLE       NOT NULL,
    geolocation_city            VARCHAR(100) NOT NULL,
    geolocation_state           CHAR(2)      NOT NULL,
    INDEX idx_geolocation_zip (geolocation_zip_code_prefix)
);


CREATE TABLE product_category_translation (
    product_category_name         VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_category_name)
);


-- Categoria e medidas aceitam NULL, pois alguns produtos vêm sem esses dados.
CREATE TABLE products (
    product_id                 CHAR(32)     NOT NULL,
    product_category_name      VARCHAR(100) NULL,
    product_name_length        INT          NULL,
    product_description_length INT          NULL,
    product_photos_qty         INT          NULL,
    product_weight_g           INT          NULL,
    product_length_cm          INT          NULL,
    product_height_cm          INT          NULL,
    product_width_cm           INT          NULL,
    PRIMARY KEY (product_id),
    INDEX idx_products_category (product_category_name)
);


-- As datas de aprovação, envio e entrega aceitam NULL: pedidos cancelados ou
-- ainda em andamento não têm todas elas preenchidas.
CREATE TABLE orders (
    order_id                      CHAR(32)    NOT NULL,
    customer_id                   CHAR(32)    NOT NULL,
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      DATETIME    NULL,
    order_approved_at             DATETIME    NULL,
    order_delivered_carrier_date  DATETIME    NULL,
    order_delivered_customer_date DATETIME    NULL,
    order_estimated_delivery_date DATETIME    NULL,
    PRIMARY KEY (order_id),
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_status   (order_status),
    INDEX idx_orders_purchase (order_purchase_timestamp)
);


CREATE TABLE order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)      NOT NULL,
    seller_id           CHAR(32)      NOT NULL,
    shipping_limit_date DATETIME      NULL,
    price               DECIMAL(10,2) NOT NULL,
    freight_value       DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_items_product (product_id),
    INDEX idx_items_seller  (seller_id)
);


CREATE TABLE order_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         VARCHAR(20)   NOT NULL,
    payment_installments INT           NOT NULL,
    payment_value        DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);


-- Usei uma chave artificial (id) porque não tenho certeza de que review_id é
-- único; vou conferir isso na etapa de qualidade (04).
CREATE TABLE order_reviews (
    id                      INT          NOT NULL AUTO_INCREMENT,
    review_id               CHAR(32)     NOT NULL,
    order_id                CHAR(32)     NOT NULL,
    review_score            TINYINT      NOT NULL,
    review_comment_title    VARCHAR(255) NULL,
    review_comment_message  TEXT         NULL,
    review_creation_date    DATETIME     NULL,
    review_answer_timestamp DATETIME     NULL,
    PRIMARY KEY (id),
    INDEX idx_reviews_order (order_id),
    INDEX idx_reviews_id    (review_id)
);
