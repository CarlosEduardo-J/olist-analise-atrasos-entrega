-- =============================================================================
-- 05_views_metricas.sql
-- Views com as métricas de entrega. A ideia é calcular o atraso uma vez só,
-- aqui, e deixar o Python e o Power BI lerem o resultado pronto, sem cada um
-- reescrever a regra.
-- =============================================================================

USE olist;


-- -----------------------------------------------------------------------------
-- 1) vw_entregas: atraso de cada pedido entregue
--
-- Regras (decisão 012): só entram pedidos com order_status = 'delivered' e com
-- order_delivered_customer_date preenchida. Sem a data de entrega não dá para
-- calcular atraso.
--
-- dias_diferenca = DATEDIFF(entrega, estimada)
--   > 0  entregue depois da estimativa (atraso)
--   = 0  entregue no dia estimado
--   < 0  entregue antes da estimativa
--
-- Regra de atraso: atrasado = 1 só quando dias_diferenca > 0.
-- A data estimada vem sempre com hora 00:00:00, e o DATEDIFF ignora a hora e
-- compara dias de calendário. Uma entrega às 15h do dia estimado dá 0 e conta
-- como no prazo, porque o cliente foi prometido "até aquele dia". Se eu
-- comparasse os horários direto, essa entrega seria marcada como atrasada.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_entregas AS
SELECT
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS dias_diferenca,
    CASE
        WHEN DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) > 0 THEN 1
        ELSE 0
    END AS atrasado
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- -----------------------------------------------------------------------------
-- Conferência da vw_entregas
--
-- a) Total de linhas. Esperado: 96.470 (96.478 pedidos delivered menos os 8 sem
--    data de entrega).
-- Resultado: 96.470 linhas, igual ao esperado.
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS total_pedidos
FROM vw_entregas;


-- b) Quantos atrasaram e a proporção.
-- Resultado: 6.534 pedidos atrasados de 96.470, ou 6,77%. Ou seja, 93,23% das
-- entregas chegaram no prazo ou antes.
-- -----------------------------------------------------------------------------
SELECT
    SUM(atrasado) AS pedidos_atrasados,
    COUNT(*) AS total_pedidos,
    ROUND(100 * SUM(atrasado) / COUNT(*), 2) AS pct_atrasados
FROM vw_entregas;


-- c) Menor e maior diferença, para ver se há algum valor fora do normal.
-- Resultado: a maior antecipação foi de 147 dias e o maior atraso, de 188 dias.
-- São extremos, mas não são valores impossíveis. Ainda não investiguei se são
-- erros ou casos reais. Como podem distorcer médias, ao calcular o atraso médio
-- vou comparar com a mediana.
-- -----------------------------------------------------------------------------
SELECT
    MIN(dias_diferenca) AS maior_adiantamento,
    MAX(dias_diferenca) AS maior_atraso
FROM vw_entregas;
