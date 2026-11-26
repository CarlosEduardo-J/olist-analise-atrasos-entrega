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


-- -----------------------------------------------------------------------------
-- 2) Nota média: pedidos atrasados vs. no prazo
-- Pergunta: pedidos atrasados recebem notas piores?
--
-- 2.1) Versão simples, juntando vw_entregas direto com order_reviews.
-- Problema: 547 pedidos têm mais de uma avaliação e aparecem repetidos no JOIN,
-- então pesam mais na média. Uso LEFT JOIN e COUNT(review_score), que conta só
-- linhas com nota (COUNT(*) contaria também os pedidos sem avaliação).
-- Resultado: nota média de 4,29 no prazo e 2,27 atrasados (rodei essa versão
-- antes de corrigir a contagem, então guardei só as médias).
-- -----------------------------------------------------------------------------
SELECT
    v.atrasado,
    ROUND(AVG(od.review_score), 2) AS nota_media,
    COUNT(od.review_score) AS qtd_avaliacoes
FROM vw_entregas v
LEFT JOIN order_reviews od
    ON v.order_id = od.order_id
GROUP BY v.atrasado;


-- 2.2) Versão tratada: uma nota por pedido (decisão 015).
-- A CTE reduz as avaliações a uma linha por pedido, com a média das notas dele,
-- e só depois calculo a média de cada grupo. Assim todo pedido pesa igual.
-- INNER JOIN porque só quero pedidos com avaliação. Não arredondo dentro da
-- CTE, só no resultado final.
-- Resultado: 89.443 pedidos no prazo com nota média de 4,29 e 6.381 atrasados
-- com 2,27. A soma (95.824) bate com a CTE.
-- Comparando com a versão simples, as médias não mudaram, então a duplicidade
-- de avaliações pesava pouco (547 pedidos, cerca de 0,55%).
-- Conclusão: pedidos atrasados têm nota média cerca de 2 pontos menor. Isso é
-- uma associação, não prova que o atraso causa a nota baixa.
-- Ficam de fora desta média 646 pedidos entregues sem avaliação (0,67%).
-- -----------------------------------------------------------------------------
WITH avaliacoes_por_id AS (
    SELECT
        o.order_id,
        v.atrasado,
        AVG(o.review_score) AS nota_media
    FROM vw_entregas v
    INNER JOIN order_reviews o
        ON v.order_id = o.order_id
    GROUP BY o.order_id, v.atrasado
)
SELECT
    atrasado,
    COUNT(*) AS qtd,
    ROUND(AVG(nota_media), 2) AS nota_media
FROM avaliacoes_por_id
GROUP BY atrasado;


-- -----------------------------------------------------------------------------
-- 3) Atraso por estado do cliente
-- Pergunta: em quais estados os pedidos mais atrasam?
-- Junto vw_entregas com customers pelo customer_id (INNER JOIN, porque não há
-- pedidos sem cliente) e agrupo por estado. Mostro o total de pedidos ao lado
-- do percentual, porque estado com poucos pedidos tem percentual instável.
--
-- Conferência: a soma dos totais dá 96.470 e a dos atrasados dá 6.534, os
-- mesmos números da vw_entregas.
--
-- Resultado (taxa geral: 6,77%):
--  * Maiores taxas: AL 21,41%, MA 17,43%, SE 15,22%, PI 13,87% e CE 13,76%.
--    Todos do Nordeste, com amostras de centenas de pedidos (335 a 1.279).
--  * RJ chama atenção: 12,11% em 12.350 pedidos, uma amostra grande. Não é do
--    Nordeste e tem taxa parecida com a da BA (12,16%).
--  * Menores taxas: AM 2,76%, RO 2,88%, AP 2,99%, AC 3,75%, PR 4,04% e SP 4,49%.
--  * Em número absoluto, SP (1.820) e RJ (1.495) concentram mais da metade dos
--    atrasos, por causa do volume de pedidos. Taxa e quantidade contam histórias
--    diferentes.
--  * Cuidado com estados pequenos: RR tem 41 pedidos (5 atrasados), AP 67, AC 80
--    e AM 145. Um ou dois atrasos a mais mudam muito o percentual.
--
-- Observação vs. hipótese:
--  * Observação: o atraso é maior no Nordeste e no RJ e menor em SP e no Sul.
--  * Hipótese 1: a distância até os vendedores explica parte do Nordeste. Ainda
--    não testei, vou testar no Python.
--  * Hipótese 2: os estados do Norte (AM, RO, AP, AC) são distantes e mesmo
--    assim têm taxa baixa, o que sugere que a distância sozinha não explica. Pode
--    ser que o prazo estimado seja mais folgado nessas regiões. Vale comparar o
--    prazo prometido por estado.
-- -----------------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(*) AS total_pedidos,
    SUM(v.atrasado) AS qtd_pedidos_atrasados,
    ROUND(100 * SUM(v.atrasado) / COUNT(*), 2) AS pct_atrasados
FROM vw_entregas v
INNER JOIN customers c
    ON v.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY pct_atrasados DESC;
