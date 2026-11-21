-- =============================================================================
-- 02_carga_dados.sql
-- Carrega os 9 CSVs de data/raw/ nas tabelas criadas no 01.
--
-- Antes de rodar:
--  * Troquei o caminho real por C:/CAMINHO/PROJETO. Ajuste para o caminho do
--    projeto no seu computador, usando barras normais "/".
--  * No meu caso o caminho original tinha acento (Usuário) e o MySQL não achava
--    o arquivo. Copiei os CSVs para uma pasta sem acento e usei ela na carga.
--  * É preciso permitir carga local: local_infile = 1 no servidor e
--    OPT_LOCAL_INFILE=1 na conexão do Workbench (Advanced > Others).
--
-- Padrão das cargas:
--  * Campos separados por vírgula, com aspas só em alguns campos.
--  * IGNORE 1 LINES pula o cabeçalho.
--  * Colunas que podem vir vazias são lidas em uma variável (@nome) e depois
--    convertidas com NULLIF(@nome, ''), para o vazio virar NULL.
--
-- Conferência: depois de cada carga olhei Records, Skipped e Warnings no
-- Workbench e comparei a contagem com a do CSV.
-- =============================================================================

USE olist;


-- 1) Tradução das categorias
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/product_category_name_translation.csv'
INTO TABLE product_category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_category_name, product_category_name_english);


-- 2) Clientes
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, customer_unique_id, customer_zip_code_prefix,
 customer_city, customer_state);


-- 3) Vendedores
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(seller_id, seller_zip_code_prefix, seller_city, seller_state);


-- 4) Geolocalização (~1 milhão de linhas, é a mais demorada)
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_geolocation_dataset.csv'
INTO TABLE geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
 geolocation_city, geolocation_state);


-- 5) Produtos (categoria e medidas podem vir vazias)
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @categoria, @nome_len, @desc_len, @fotos,
 @peso, @comprimento, @altura, @largura)
SET product_category_name      = NULLIF(@categoria, ''),
    product_name_length        = NULLIF(@nome_len, ''),
    product_description_length = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@fotos, ''),
    product_weight_g           = NULLIF(@peso, ''),
    product_length_cm          = NULLIF(@comprimento, ''),
    product_height_cm          = NULLIF(@altura, ''),
    product_width_cm           = NULLIF(@largura, '');


-- 6) Pedidos (datas de aprovação, envio e entrega podem vir vazias)
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, @compra, @aprovado,
 @envio, @entrega, @estimada)
SET order_purchase_timestamp      = NULLIF(@compra, ''),
    order_approved_at             = NULLIF(@aprovado, ''),
    order_delivered_carrier_date  = NULLIF(@envio, ''),
    order_delivered_customer_date = NULLIF(@entrega, ''),
    order_estimated_delivery_date = NULLIF(@estimada, '');


-- 7) Itens dos pedidos
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id,
 shipping_limit_date, price, freight_value);


-- 8) Pagamentos
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_sequential, payment_type,
 payment_installments, payment_value);


-- 9) Avaliações
-- Esse CSV termina as linhas com \r\n (os outros usam só \n). Com '\n' o \r
-- ficava grudado em review_answer_timestamp e gerava avisos de data, então
-- aqui o terminador é '\r\n'.
-- A coluna id não está no CSV: fica fora da lista e o AUTO_INCREMENT preenche.
-- Título e comentário costumam vir vazios, por isso o NULLIF.
LOAD DATA LOCAL INFILE 'C:/CAMINHO/PROJETO/data/raw/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @titulo, @mensagem, @criacao, @resposta)
SET review_comment_title    = NULLIF(@titulo, ''),
    review_comment_message  = NULLIF(@mensagem, ''),
    review_creation_date    = NULLIF(@criacao, ''),
    review_answer_timestamp = NULLIF(@resposta, '');
