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


-- -----------------------------------------------------------------------------
-- 2) Datas vazias viraram NULL?
-- Esperado: NULL só em pedidos que não completaram o fluxo (cancelados,
-- indisponíveis, em andamento etc.).
--
-- 2.1) Quantidade de NULL em cada data de orders.
-- COUNT(*) conta todas as linhas e COUNT(coluna) só as não nulas, então a
-- diferença entre os dois é o número de NULL.
-- Resultado: 160 sem aprovação, 1.783 sem envio e 2.965 sem entrega. O número
-- cresce a cada etapa, o que faz sentido: sem aprovação não há envio, e sem
-- envio não há entrega.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) - COUNT(order_approved_at)             AS nulos_aprovacao,
    COUNT(*) - COUNT(order_delivered_carrier_date)  AS nulos_envio,
    COUNT(*) - COUNT(order_delivered_customer_date) AS nulos_entrega
FROM orders;


-- 2.2) Em quais status os NULL de entrega aparecem?
-- Resultado: dos 2.965 pedidos sem data de entrega,
--   * 1.850 estão em status que não chegaram à entrega (canceled 619,
--     unavailable 609, invoiced 314, processing 301, created 5, approved 2);
--   * 1.107 estão em shipped (enviados, sem entrega registrada);
--   * 8 estão em delivered, o que é uma inconsistência da fonte.
-- A soma fecha com o total de 2.965 e com os 99.441 pedidos da tabela.
-- Observação: 6 pedidos canceled têm data de entrega (625 no total, 619 sem
-- data). Não afeta a análise, que vai olhar só pedidos delivered.
-- -----------------------------------------------------------------------------
SELECT
    order_status,
    SUM(order_delivered_customer_date IS NULL) AS nulos_entrega,
    COUNT(*) AS qtd_status
FROM orders
GROUP BY order_status
ORDER BY qtd_status DESC;


-- 2.3) Os 8 pedidos delivered sem data de entrega.
-- Sem a data de entrega não dá para calcular atraso, então esses pedidos
-- ficam de fora da análise de atraso.
-- Resultado: as demais datas estão preenchidas, então parece falha só no registro da entrega
-- -----------------------------------------------------------------------------
SELECT *
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
