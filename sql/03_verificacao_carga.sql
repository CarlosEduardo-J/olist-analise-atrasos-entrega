-- =============================================================================
-- 03_verificacao_carga.sql
-- Antes de começar qualquer análise, confiro se a carga dos CSVs no MySQL
-- ficou correta. Cada bloco abaixo é uma verificação, com o que eu esperava
-- ver e o que encontrei.
-- =============================================================================

USE olist;


-- -----------------------------------------------------------------------------
-- 1) Contagem de linhas por tabela
-- Esperado: o mesmo número de registros de cada CSV.
-- Contei os CSVs de forma independente no PowerShell com
-- (Import-Csv arquivo.csv).Count, que conta registros e não linhas de texto
-- (importante nas avaliações, que têm quebras de linha dentro dos comentários).
-- Resultado: as 9 contagens bateram com os CSVs, sem linhas perdidas nem
-- duplicadas.
-- -----------------------------------------------------------------------------
SELECT 'customers' AS tabela, COUNT(*) AS linhas FROM customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;
